import { createDecipheriv } from 'node:crypto';
import { join } from 'path';
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, IsNull } from 'typeorm';
import type { WebSocket } from 'ws';
import { Conversation } from '../entities/conversation.entity.js';
import { ConversationEncryptionKey } from '../entities/conversation-encryption-key.entity.js';
import { ConversationMember } from '../entities/conversation-member.entity.js';
import { MessageBlindIndex } from '../entities/message-blind-index.entity.js';
import { Message } from '../entities/message.entity.js';
import { MessageBookmark } from '../entities/message-bookmark.entity.js';
import {
  MessageReminder,
  MessageReminderScope,
} from '../entities/message-reminder.entity.js';
import { MessageReaction } from '../entities/message-reaction.entity.js';
import { PinnedMessage } from '../entities/pinned-message.entity.js';
import { User } from '../../auth/entities/user.entity.js';
import { RedisPubSubService } from './redis-pubsub.service.js';
import {
  NotificationJobService,
  type GroupMembershipNotificationContext,
} from './notification-job.service.js';
import { ConnectionManager } from './connection-manager.service.js';
import { ReminderJobService } from './reminder-job.service.js';
import {
  type FileMessageMetadata,
  GetGlobalBookmarksQueryDto,
  GlobalBookmarksResponseDto,
  MessageSeenByResponseDto,
  MessageType,
} from '../dto/chat.dto.js';

export interface ReactionGroup {
  emoji: string;
  count: number;
  users: Array<{ id: string; name: string }>;
}

interface EncryptedContentEnvelope {
  version: number;
  alg: string;
  key_id: string;
  nonce: string;
  ciphertext: string;
}

interface GlobalBookmarkQueryRow {
  message_id: string;
  conv_id: string;
  conv_type: string;
  conv_name: string;
  conv_avatar_url: string | null;
  sender_id: string;
  sender_name: string;
  message_type: string;
  message_content: string | null;
  message_created_at: Date | string;
  marked_at: Date | string;
}

interface MessageSeenByRow {
  user_id: string;
  name: string | null;
  avatar_url: string | null;
  seen_at: Date | string | null;
}

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);
  private static readonly MESSAGE_SEARCH_SIMILARITY_THRESHOLD = 0.2;
  private static readonly ENCRYPTION_ALGORITHM = 'AES-256-GCM';
  private static readonly ENCRYPTION_VERSION = 1;
  private static readonly ENCRYPTED_CONTENT_METADATA_KEY = 'encrypted_content';
  private static readonly BLIND_INDEX_VERSION = 1;
  private static readonly BLIND_INDEX_ALGORITHM = 'hmac-sha256';

  constructor(
    @InjectRepository(Conversation)
    private readonly convRepo: Repository<Conversation>,
    @InjectRepository(ConversationEncryptionKey)
    private readonly encryptionKeyRepo: Repository<ConversationEncryptionKey>,
    @InjectRepository(ConversationMember)
    private readonly memberRepo: Repository<ConversationMember>,
    @InjectRepository(Message)
    private readonly messageRepo: Repository<Message>,
    @InjectRepository(MessageBlindIndex)
    private readonly messageBlindIndexRepo: Repository<MessageBlindIndex>,
    @InjectRepository(MessageBookmark)
    private readonly messageBookmarkRepo: Repository<MessageBookmark>,
    @InjectRepository(MessageReminder)
    private readonly messageReminderRepo: Repository<MessageReminder>,
    @InjectRepository(MessageReaction)
    private readonly reactionRepo: Repository<MessageReaction>,
    @InjectRepository(PinnedMessage)
    private readonly pinnedMessageRepo: Repository<PinnedMessage>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly redisPubSub: RedisPubSubService,
    private readonly notificationJob: NotificationJobService,
    private readonly reminderJobService: ReminderJobService,
    private readonly connectionManager: ConnectionManager,
  ) {}

  // --- Send message ---

  async sendMessage(
    senderId: string,
    data: Record<string, unknown>,
    senderSocket?: WebSocket,
    bypassMembershipCheck: boolean = false,
  ): Promise<Message> {
    const convId = data.conv_id as string;
    const messageId = data.id as string;

    // Validate membership (can be bypassed for bots)
    if (!bypassMembershipCheck) {
      const membership = await this.memberRepo.findOne({
        where: { conv_id: convId, user_id: senderId },
      });
      if (!membership) {
        const err = new Error('Not a member of this conversation');
        (err as any).code = 'FORBIDDEN';
        throw err;
      }
    }

    // Idempotent insert using ON CONFLICT
    const now = new Date();
    const msgType = (data.type as string) || 'text';
    const normalizedMetadata = this.normalizeMessageMetadata(
      msgType,
      data.metadata,
    );
    const pushPreview = this.normalizePushPreview(msgType, data.content);
    const encryptedContent = this.normalizeEncryptedContent(
      msgType,
      data.encrypted_content,
    );
    const content = this.normalizeMessageContent(
      msgType,
      data.content,
      normalizedMetadata,
      encryptedContent,
    );
    const replyToId = (data.reply_to_id as string) || null;
    const storedMetadata = this.buildStoredMessageMetadata(
      normalizedMetadata,
      encryptedContent,
    );
    const metadata = storedMetadata ? JSON.stringify(storedMetadata) : null;
    const forwardedFromId = (data.forwarded_from_id as string) || null;
    const forwardedFromSender = (data.forwarded_from_sender as string) || null;
    const blindIndexTokens = this.normalizeBlindIndexTokens(
      data.blind_index_v1,
    );
    if (blindIndexTokens && !encryptedContent) {
      throw Object.assign(
        new Error(
          'blind_index_v1 is only supported for encrypted text messages',
        ),
        {
          code: 'INVALID_FORMAT',
        },
      );
    }

    const result = await this.messageRepo.query(
      `INSERT INTO messages (id, conv_id, sender_id, type, content, reply_to_id, metadata, forwarded_from_id, forwarded_from_sender, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9, $10)
       ON CONFLICT (id, created_at) DO NOTHING
       RETURNING *`,
      [
        messageId,
        convId,
        senderId,
        msgType,
        content,
        replyToId,
        metadata,
        forwardedFromId,
        forwardedFromSender,
        now,
      ],
    );

    let saved: Message;
    if (result.length > 0) {
      saved = result[0];
    } else {
      // Conflict — return existing message
      const existing = await this.messageRepo.findOne({
        where: { id: messageId },
      });
      if (existing) return existing;
      throw new Error('Failed to insert or find message');
    }

    // Update conversation last_message_at
    await this.convRepo.update(convId, { last_message_at: saved.created_at });

    if (blindIndexTokens) {
      await this.replaceBlindIndexTokens(messageId, convId, blindIndexTokens);
    }

    // Publish to Redis for fan-out (include reply_to snapshot if applicable)
    const publishData: Record<string, unknown> = this.serializeMessageForClient(
      {
        ...saved,
        _senderSocketId: senderSocket
          ? this.connectionManager.getSocketId(senderSocket)
          : undefined,
      },
    );
    if (replyToId) {
      publishData.reply_to = await this.getReplyToSnapshot(replyToId);
    }
    await this.redisPubSub.publish(convId, publishData);

    // Enqueue push notifications for all recipients except the sender.
    await this.enqueuePushNotifications(convId, senderId, saved, pushPreview);

    return saved;
  }

  private normalizeMessageMetadata(
    messageType: string,
    metadata: unknown,
  ): Record<string, unknown> | null {
    if (messageType !== MessageType.FILE) {
      if (
        !metadata ||
        typeof metadata !== 'object' ||
        Array.isArray(metadata)
      ) {
        return null;
      }
      return metadata as Record<string, unknown>;
    }

    if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
      throw Object.assign(
        new Error('File messages require attachment metadata'),
        {
          code: 'INVALID_FORMAT',
        },
      );
    }

    const raw = metadata as Record<string, unknown>;
    const url = typeof raw.url === 'string' ? raw.url.trim() : '';
    const originalName =
      typeof raw.originalName === 'string' ? raw.originalName.trim() : '';
    const mimeType =
      typeof raw.mimeType === 'string' ? raw.mimeType.trim() : '';
    const rawSize = raw.size;
    const size =
      typeof rawSize === 'number'
        ? rawSize
        : typeof rawSize === 'string'
          ? Number(rawSize)
          : NaN;

    if (
      !url ||
      !originalName ||
      !mimeType ||
      !Number.isFinite(size) ||
      size <= 0
    ) {
      throw Object.assign(
        new Error(
          'File messages require metadata.url, metadata.originalName, metadata.mimeType, and a positive metadata.size',
        ),
        { code: 'INVALID_FORMAT' },
      );
    }

    const normalized: FileMessageMetadata = {
      url,
      originalName,
      mimeType,
      size,
    };

    return { ...normalized };
  }

  private normalizeMessageContent(
    messageType: string,
    content: unknown,
    metadata: Record<string, unknown> | null,
    encryptedContent: EncryptedContentEnvelope | null,
  ): string | null {
    const normalizedContent =
      typeof content === 'string' && content.trim().length > 0 ? content : null;

    if (messageType === MessageType.TEXT) {
      if (encryptedContent) {
        return null;
      }

      if (!normalizedContent) {
        throw Object.assign(
          new Error(
            'Text messages require either plaintext content or encrypted_content',
          ),
          { code: 'INVALID_FORMAT' },
        );
      }

      return normalizedContent;
    }

    if (normalizedContent) {
      return normalizedContent;
    }

    if (messageType === MessageType.FILE && metadata) {
      return metadata.originalName as string;
    }

    return null;
  }

  private normalizePushPreview(
    messageType: string,
    content: unknown,
  ): string | null {
    if (messageType !== MessageType.TEXT) {
      return null;
    }

    return typeof content === 'string' && content.trim().length > 0
      ? content.trim()
      : null;
  }

  private normalizeEncryptedContent(
    messageType: string,
    encryptedContent: unknown,
  ): EncryptedContentEnvelope | null {
    if (encryptedContent == null) {
      return null;
    }

    if (messageType !== MessageType.TEXT) {
      throw Object.assign(
        new Error('encrypted_content is only supported for text messages'),
        { code: 'INVALID_FORMAT' },
      );
    }

    if (
      typeof encryptedContent !== 'object' ||
      encryptedContent === null ||
      Array.isArray(encryptedContent)
    ) {
      throw Object.assign(new Error('encrypted_content must be an object'), {
        code: 'INVALID_FORMAT',
      });
    }

    const raw = encryptedContent as Record<string, unknown>;
    const version = raw.version;
    const alg = typeof raw.alg === 'string' ? raw.alg.trim() : '';
    const keyId = typeof raw.key_id === 'string' ? raw.key_id.trim() : '';
    const nonce = typeof raw.nonce === 'string' ? raw.nonce.trim() : '';
    const ciphertext =
      typeof raw.ciphertext === 'string' ? raw.ciphertext.trim() : '';

    if (
      version !== ChatService.ENCRYPTION_VERSION ||
      alg !== ChatService.ENCRYPTION_ALGORITHM ||
      !keyId ||
      !this.isBase64Value(nonce) ||
      !this.isBase64Value(ciphertext)
    ) {
      throw Object.assign(
        new Error(
          'encrypted_content must include valid version, alg, key_id, nonce, and ciphertext fields',
        ),
        { code: 'INVALID_FORMAT' },
      );
    }

    return {
      version,
      alg,
      key_id: keyId,
      nonce,
      ciphertext,
    };
  }

  private buildStoredMessageMetadata(
    metadata: Record<string, unknown> | null,
    encryptedContent: EncryptedContentEnvelope | null,
  ): Record<string, unknown> | null {
    const nextMetadata = metadata ? { ...metadata } : null;

    if (!encryptedContent) {
      if (nextMetadata) {
        delete nextMetadata[ChatService.ENCRYPTED_CONTENT_METADATA_KEY];
      }
      return nextMetadata;
    }

    return {
      ...(nextMetadata ?? {}),
      [ChatService.ENCRYPTED_CONTENT_METADATA_KEY]: encryptedContent,
    };
  }

  private isBase64Value(value: string): boolean {
    if (!value || !/^[A-Za-z0-9+/]+={0,2}$/.test(value)) {
      return false;
    }

    try {
      return Buffer.from(value, 'base64').length > 0;
    } catch {
      return false;
    }
  }

  private normalizeBlindIndexTokens(
    blindIndexPayload: unknown,
  ): string[] | null {
    if (blindIndexPayload == null) {
      return null;
    }

    if (
      typeof blindIndexPayload !== 'object' ||
      Array.isArray(blindIndexPayload)
    ) {
      throw Object.assign(new Error('blind_index_v1 must be an object'), {
        code: 'INVALID_FORMAT',
      });
    }

    const raw = blindIndexPayload as Record<string, unknown>;
    if (raw.version !== ChatService.BLIND_INDEX_VERSION) {
      throw Object.assign(new Error('blind_index_v1.version must equal 1'), {
        code: 'INVALID_FORMAT',
      });
    }

    if (raw.algo !== ChatService.BLIND_INDEX_ALGORITHM) {
      throw Object.assign(
        new Error('blind_index_v1.algo must equal hmac-sha256'),
        {
          code: 'INVALID_FORMAT',
        },
      );
    }

    if (!Array.isArray(raw.tokens) || raw.tokens.length === 0) {
      throw Object.assign(
        new Error('blind_index_v1.tokens must be a non-empty array'),
        {
          code: 'INVALID_FORMAT',
        },
      );
    }

    const deduped = new Set<string>();
    for (const token of raw.tokens) {
      if (typeof token !== 'string' || !/^[0-9a-f]{64}$/.test(token)) {
        throw Object.assign(
          new Error(
            'blind_index_v1.tokens must contain lowercase hex SHA-256 hashes',
          ),
          { code: 'INVALID_FORMAT' },
        );
      }
      deduped.add(token);
    }

    return [...deduped];
  }

  private normalizeSearchQueryHashes(queryHashes?: string[]): string[] | null {
    if (!Array.isArray(queryHashes) || queryHashes.length === 0) {
      return null;
    }

    const deduped = new Set<string>();
    for (const token of queryHashes) {
      if (typeof token !== 'string' || !/^[0-9a-f]{64}$/.test(token)) {
        throw Object.assign(
          new Error('q_hashes must contain lowercase hex hashes'),
          {
            code: 'INVALID_FORMAT',
          },
        );
      }
      deduped.add(token);
    }

    return [...deduped];
  }

  private async replaceBlindIndexTokens(
    messageId: string,
    convId: string,
    tokenHashes: string[],
  ): Promise<void> {
    await this.messageBlindIndexRepo.delete({ message_id: messageId });

    if (tokenHashes.length === 0) {
      return;
    }

    await this.messageBlindIndexRepo.query(
      `INSERT INTO message_blind_indexes (message_id, conv_id, token_hash)
       SELECT $1, $2, UNNEST($3::varchar[])`,
      [messageId, convId, tokenHashes],
    );
  }

  private buildPrefixTsQuery(query: string): string | null {
    const tokens = query
      .trim()
      .split(/\s+/)
      .map((token) => token.replace(/[^\p{L}\p{N}_-]+/gu, ''))
      .filter(Boolean);

    if (tokens.length === 0) {
      return null;
    }

    return tokens.map((token) => `${token}:*`).join(' & ');
  }

  // --- Push notifications ---

  private async enqueuePushNotifications(
    convId: string,
    senderId: string,
    message: Message,
    pushPreview: string | null = null,
  ): Promise<void> {
    const resolvedPushPreview =
      pushPreview ??
      (message.type === MessageType.TEXT
        ? await this.resolveEncryptedPushPreview(message)
        : null);

    const conversation = await this.convRepo.findOne({
      where: { id: convId },
      select: ['id', 'type', 'name'],
    });
    const conversationContext = {
      id: conversation?.id ?? convId,
      type: conversation?.type ?? 'DIRECT',
      name:
        conversation?.type === 'GROUP'
          ? this.resolveConversationPushName(conversation?.name ?? null)
          : null,
    };

    const members = await this.memberRepo.find({
      where: { conv_id: convId },
      select: ['user_id', 'is_muted'],
    });

    // Extract mentioned user IDs from metadata
    const mentionedUserIds = new Set<string>();
    let isMentionAll = false;
    try {
      const meta =
        typeof message.metadata === 'string'
          ? JSON.parse(message.metadata)
          : message.metadata;
      const mentions = meta?.mentions as Array<{ user_id: string }> | undefined;
      if (Array.isArray(mentions)) {
        for (const m of mentions) {
          if (m.user_id === 'all') {
            isMentionAll = true;
          } else {
            mentionedUserIds.add(m.user_id);
          }
        }
      }
    } catch {
      // Malformed metadata — ignore
    }

    for (const member of members) {
      if (member.user_id === senderId) continue;

      const isMentioned = isMentionAll || mentionedUserIds.has(member.user_id);
      if (member.is_muted && !isMentioned) continue;

      await this.notificationJob.enqueuePush(
        member.user_id,
        { ...message, content: resolvedPushPreview ?? message.content },
        isMentioned,
        isMentionAll,
        conversationContext,
      );
    }
  }

  private resolveConversationPushName(name: string | null): string {
    const trimmed = name?.trim();
    return trimmed ? trimmed : 'Group chat';
  }

  private async resolveEncryptedPushPreview(
    message: Pick<Message, 'conv_id' | 'metadata'>,
  ): Promise<string | null> {
    const metadata = this.parseMessageMetadata(message.metadata);
    const encryptedContent = this.extractEncryptedContentFromMetadata(metadata);
    if (!encryptedContent) {
      return null;
    }

    const key = await this.encryptionKeyRepo.findOne({
      where: {
        conv_id: message.conv_id,
        key_id: encryptedContent.key_id,
      },
    });
    if (!key?.material) {
      return null;
    }

    try {
      const nonce = Buffer.from(encryptedContent.nonce, 'base64');
      const payload = Buffer.from(encryptedContent.ciphertext, 'base64');
      if (payload.length <= 16) {
        return null;
      }

      const authTag = payload.subarray(payload.length - 16);
      const ciphertext = payload.subarray(0, payload.length - 16);
      const decipher = createDecipheriv('aes-256-gcm', key.material, nonce);
      decipher.setAuthTag(authTag);

      const plaintext = Buffer.concat([
        decipher.update(ciphertext),
        decipher.final(),
      ]).toString('utf8');

      const normalized = plaintext.trim();
      return normalized.length > 0 ? normalized : null;
    } catch (error) {
      this.logger.warn(
        `Failed to decrypt push preview for conversation ${message.conv_id}: ${String(error)}`,
      );
      return null;
    }
  }

  private buildGroupMembershipConversationContext(params: {
    id: string;
    type: string;
    name: string | null;
  }): GroupMembershipNotificationContext {
    return {
      id: params.id,
      type: params.type || 'GROUP',
      name: this.resolveConversationPushName(params.name ?? null),
    };
  }

  private async notifyGroupMembershipAdded(params: {
    recipientUserId: string;
    actorId: string;
    actorName: string;
    conversation: {
      id: string;
      type: string;
      name: string | null;
      avatar_url?: string | null;
      created_by?: string;
    };
    lastMessageAt: Date | null;
  }): Promise<void> {
    const { recipientUserId, actorId, actorName, conversation, lastMessageAt } =
      params;
    const conversationContext =
      this.buildGroupMembershipConversationContext(conversation);

    await this.notificationJob.enqueueGroupMembershipAdded(
      recipientUserId,
      actorId,
      actorName,
      conversationContext,
    );

    await this.redisPubSub.publishUserEvent(recipientUserId, {
      _event: 'conversation_added',
      type: 'group_membership_added',
      conv_id: conversationContext.id,
      conv_type: conversationContext.type,
      conv_name: conversationContext.name,
      conv_avatar_url: conversation.avatar_url ?? null,
      created_by: conversation.created_by ?? actorId,
      last_message_at: lastMessageAt,
      actor_id: actorId,
      actor_name: actorName,
    });
  }

  // --- Forward messages ---

  async forwardMessages(
    senderId: string,
    data: Record<string, unknown>,
  ): Promise<{ forwarded_count: number }> {
    const messageIds = data.message_ids as string[];
    const convIds = data.conv_ids as string[];
    const hideSender = (data.hide_sender as boolean) ?? false;

    if (!Array.isArray(messageIds) || messageIds.length === 0) {
      throw Object.assign(new Error('message_ids required'), {
        code: 'INVALID_FORMAT',
      });
    }
    if (!Array.isArray(convIds) || convIds.length === 0) {
      throw Object.assign(new Error('conv_ids required'), {
        code: 'INVALID_FORMAT',
      });
    }

    // Look up original messages, filter out deleted
    const originals = await this.messageRepo
      .createQueryBuilder('m')
      .where('m.id IN (:...ids)', { ids: messageIds })
      .andWhere('m.deleted_at IS NULL')
      .orderBy('m.created_at', 'ASC')
      .getMany();

    if (originals.length === 0) {
      throw Object.assign(new Error('No valid messages to forward'), {
        code: 'NOT_FOUND',
      });
    }

    // Validate all messages belong to the same conversation
    const sourceConvId = originals[0].conv_id;
    const allSameConv = originals.every((m) => m.conv_id === sourceConvId);
    if (!allSameConv) {
      throw Object.assign(
        new Error('All messages must belong to the same conversation'),
        { code: 'INVALID_FORMAT' },
      );
    }

    // Validate sender membership in source conversation
    const sourceMembership = await this.memberRepo.findOne({
      where: { conv_id: sourceConvId, user_id: senderId },
    });
    if (!sourceMembership) {
      throw Object.assign(new Error('Not a member of source conversation'), {
        code: 'FORBIDDEN',
      });
    }

    // Validate sender membership in all target conversations
    for (const convId of convIds) {
      const membership = await this.memberRepo.findOne({
        where: { conv_id: convId, user_id: senderId },
      });
      if (!membership) {
        throw Object.assign(
          new Error(`Not a member of target conversation ${convId}`),
          { code: 'FORBIDDEN' },
        );
      }
    }

    // Look up original sender names for attribution
    const senderIds = [...new Set(originals.map((m) => m.sender_id))];
    const senders = await this.userRepo.find({
      where: { id: In(senderIds) },
      select: ['id', 'name'],
    });
    const senderNameMap = new Map(senders.map((u) => [u.id, u.name]));

    let forwardedCount = 0;

    for (const convId of convIds) {
      const baseTime = Date.now();
      for (let i = 0; i < originals.length; i++) {
        const orig = originals[i];
        const newId = crypto.randomUUID();
        const createdAt = new Date(baseTime + i);
        const forwardedFromSender = hideSender
          ? null
          : (senderNameMap.get(orig.sender_id) ?? null);
        const metadataStr = orig.metadata
          ? typeof orig.metadata === 'string'
            ? orig.metadata
            : JSON.stringify(orig.metadata)
          : null;

        const result = await this.messageRepo.query(
          `INSERT INTO messages (id, conv_id, sender_id, type, content, metadata, forwarded_from_id, forwarded_from_sender, created_at)
           VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8, $9)
           RETURNING *`,
          [
            newId,
            convId,
            senderId,
            orig.type,
            orig.content,
            metadataStr,
            orig.id,
            forwardedFromSender,
            createdAt,
          ],
        );

        const saved = result[0] as Message;

        // Update conversation last_message_at
        await this.convRepo.update(convId, {
          last_message_at: saved.created_at,
        });

        // Publish to Redis for fan-out
        await this.redisPubSub.publish(
          convId,
          this.serializeMessageForClient({ ...saved }),
        );

        // Enqueue push notifications for all recipients except the sender.
        await this.enqueuePushNotifications(convId, senderId, saved);

        forwardedCount++;
      }
    }

    return { forwarded_count: forwardedCount };
  }

  // --- Conversation management ---

  async createDirectConversation(
    userId: string,
    memberId: string,
  ): Promise<Conversation> {
    if (userId === memberId) {
      throw new Error('Cannot create conversation with yourself');
    }

    // Check if direct conversation already exists between these two users
    const existing = await this.convRepo
      .createQueryBuilder('c')
      .innerJoin('c.members', 'm1', 'm1.user_id = :userId', { userId })
      .innerJoin('c.members', 'm2', 'm2.user_id = :memberId', { memberId })
      .where('c.type = :type', { type: 'DIRECT' })
      .getOne();

    if (existing) return existing;

    const conv = this.convRepo.create({
      type: 'DIRECT',
      created_by: userId,
    });
    const saved = await this.convRepo.save(conv);

    // Add both members
    await this.memberRepo.save([
      this.memberRepo.create({
        conv_id: saved.id,
        user_id: userId,
        role: 'admin',
      }),
      this.memberRepo.create({
        conv_id: saved.id,
        user_id: memberId,
        role: 'member',
      }),
    ]);

    // Subscribe both users if online
    if (this.connectionManager.isOnline(userId)) {
      await this.redisPubSub.subscribeConversation(saved.id);
    }
    if (this.connectionManager.isOnline(memberId)) {
      await this.redisPubSub.subscribeConversation(saved.id);
    }

    return saved;
  }

  async getConversations(userId: string, cursor?: string, limit = 100) {
    const qb = this.convRepo
      .createQueryBuilder('c')
      .innerJoin('c.members', 'cm', 'cm.user_id = :userId', { userId })
      .leftJoin('c.members', 'allMembers')
      .leftJoin('allMembers.user', 'memberUser')
      .addSelect([
        'allMembers.user_id',
        'allMembers.role',
        'memberUser.id',
        'memberUser.name',
        'memberUser.avatar_url',
      ])
      .orderBy('c.last_message_at', 'DESC', 'NULLS LAST')
      .take(limit + 1);

    if (cursor) {
      qb.andWhere('c.last_message_at < :cursor', { cursor: new Date(cursor) });
    }

    const conversations = await qb.getMany();
    const hasMore = conversations.length > limit;
    if (hasMore) conversations.pop();

    // Get last message and unread count for each conversation
    const result = await Promise.all(
      conversations.map(async (conv) => {
        const lastMessageEntity = await this.messageRepo.findOne({
          where: { conv_id: conv.id },
          order: { created_at: 'DESC' },
          relations: {
            sender: true,
          },
          select: {
            id: true,
            // content: true,
            metadata: true,
            type: true,
            created_at: true,
            deleted_at: true,
            sender: {
              name: true,
              // avatar_url: true,
            },
          },
        });

        const lastMessage = lastMessageEntity
          ? {
              id: lastMessageEntity.id,
              content: lastMessageEntity.content,
              metadata: lastMessageEntity.metadata,
              type: lastMessageEntity.type,
              created_at: lastMessageEntity.created_at,
              deleted_at: lastMessageEntity.deleted_at,
              sender_name: lastMessageEntity.sender?.name ?? null,
              sender_avatar_url: lastMessageEntity.sender?.avatar_url ?? null,
            }
          : null;

        if (lastMessage?.deleted_at) {
          lastMessage.content = 'Tin nhắn đã được thu hồi';
        }

        const membership = await this.memberRepo.findOne({
          where: { conv_id: conv.id, user_id: userId },
        });

        let unreadCount = 0;
        let unreadMentionCount = 0;
        if (membership?.last_read_at) {
          unreadCount = await this.messageRepo
            .createQueryBuilder('m')
            .where('m.conv_id = :convId', { convId: conv.id })
            .andWhere('m.created_at > :lastRead', {
              lastRead: membership.last_read_at,
            })
            .andWhere('m.sender_id != :userId', { userId })
            .andWhere('m.deleted_at IS NULL')
            .getCount();

          // Count unread messages that mention this user or @all
          const mentionRows: Array<{ cnt: string }> =
            await this.messageRepo.query(
              `SELECT COUNT(*) AS cnt FROM messages
               WHERE conv_id = $1
                 AND created_at > $2
                 AND sender_id != $3
                 AND deleted_at IS NULL
                 AND (
                   metadata->'mentions' @> $4::jsonb
                   OR metadata->'mentions' @> '[{"user_id":"all"}]'::jsonb
                 )`,
              [
                conv.id,
                membership.last_read_at,
                userId,
                JSON.stringify([{ user_id: userId }]),
              ],
            );
          unreadMentionCount = parseInt(mentionRows[0]?.cnt ?? '0', 10);
        } else {
          unreadCount = await this.messageRepo
            .createQueryBuilder('m')
            .where('m.conv_id = :convId', { convId: conv.id })
            .andWhere('m.sender_id != :userId', { userId })
            .andWhere('m.deleted_at IS NULL')
            .getCount();
        }

        return { ...conv, lastMessage, unreadCount, unreadMentionCount };
      }),
    );

    return {
      conversations: result,
      nextCursor: hasMore
        ? conversations[conversations.length - 1].last_message_at?.toISOString()
        : null,
      hasMore,
    };
  }

  async getConversationById(convId: string, userId: string) {
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership) {
      const err = new Error('Not a member of this conversation');
      (err as any).code = 'FORBIDDEN';
      throw err;
    }

    const conv = await this.convRepo.findOne({
      where: { id: convId },
      relations: ['members', 'members.user'],
    });
    console.log(`conv by id ${convId} ::`, conv);
    return conv;
  }

  async getMessages(
    convId: string,
    userId: string,
    cursor?: string,
    limit = 30,
    dir: 'before' | 'after' = 'before',
  ) {
    // Verify membership
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership) {
      const err = new Error('Not a member of this conversation');
      (err as any).code = 'FORBIDDEN';
      throw err;
    }

    // Note: We include deleted (recalled) messages so mobile can show placeholder
    const qb = this.messageRepo
      .createQueryBuilder('m')
      .where('m.conv_id = :convId', { convId })
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(cursor);
      if (dir === 'before') {
        qb.andWhere('m.created_at < :cursor', { cursor: cursorDate });
        qb.orderBy('m.created_at', 'DESC');
      } else {
        qb.andWhere('m.created_at > :cursor', { cursor: cursorDate });
        qb.orderBy('m.created_at', 'ASC');
      }
    } else {
      qb.orderBy('m.created_at', 'DESC');
    }

    const messages = await qb.getMany();
    const hasMore = messages.length > limit;
    if (hasMore) messages.pop();

    const ordered = dir === 'after' ? messages : messages.reverse();

    // Convert entities to plain objects so dynamically added `reactions` serializes correctly
    const plainMessages = ordered.map((m) => ({ ...m }));
    await this.attachReactionsToMessages(plainMessages);
    await this.attachReplyToData(plainMessages);

    return {
      messages: plainMessages.map((message) =>
        this.serializeMessageForClient(message),
      ),
      nextCursor: hasMore ? ordered[0]?.created_at?.toISOString() : null,
      hasMore,
    };
  }

  async getMessageSeenBy(
    userId: string,
    convId: string,
    messageId: string,
  ): Promise<MessageSeenByResponseDto> {
    await this.assertConversationMembership(userId, convId);
    const message = await this.assertMessageBelongsToConversation(
      convId,
      messageId,
    );

    if (message.deleted_at) {
      throw Object.assign(
        new Error('Cannot inspect seen-by state for recalled messages'),
        {
          code: 'INVALID_MESSAGE_STATE',
        },
      );
    }

    const rows = await this.memberRepo.query(
      `SELECT cm.user_id,
              u.name,
              u.avatar_url,
              cm.last_read_at AS seen_at
       FROM conversation_members cm
       LEFT JOIN users u
         ON u.id = cm.user_id
       LEFT JOIN messages last_read_msg
         ON last_read_msg.id = cm.last_read_message_id
        AND last_read_msg.conv_id = cm.conv_id
       WHERE cm.conv_id = $1
         AND cm.user_id <> $2
         AND cm.last_read_message_id IS NOT NULL
         AND (
           cm.last_read_message_id = $3
           OR last_read_msg.created_at > $4
         )
       ORDER BY cm.last_read_at DESC NULLS LAST, cm.joined_at ASC`,
      [convId, userId, messageId, message.created_at],
    );

    return {
      conv_id: convId,
      message_id: messageId,
      seen_by: (rows as MessageSeenByRow[]).map((row) => ({
        user_id: row.user_id,
        name: row.name?.trim() || 'Unknown',
        avatar_url: row.avatar_url,
        seen_at: row.seen_at ? new Date(row.seen_at).toISOString() : null,
      })),
    };
  }

  // --- Read receipts ---

  async markRead(userId: string, data: Record<string, unknown>): Promise<void> {
    const convId = data.conv_id as string;
    const messageId = data.message_id as string;
    const membership = await this.assertConversationMembership(userId, convId);
    const message = await this.assertMessageBelongsToConversation(
      convId,
      messageId,
    );

    if (membership.last_read_message_id === messageId) {
      return;
    }

    if (membership.last_read_message_id) {
      const previousMessage = await this.messageRepo.findOne({
        where: { id: membership.last_read_message_id, conv_id: convId },
        select: ['id', 'created_at'],
      });
      if (
        previousMessage &&
        previousMessage.created_at.getTime() >= message.created_at.getTime()
      ) {
        return;
      }
    }

    const seenAt = new Date();

    await this.memberRepo.update(
      { conv_id: convId, user_id: userId },
      { last_read_message_id: messageId, last_read_at: seenAt },
    );

    // Send message_read event to other members
    const members = await this.memberRepo.find({
      where: { conv_id: convId },
      select: ['user_id'],
    });

    const readEvent = JSON.stringify({
      event: 'message_read',
      data: {
        conv_id: convId,
        message_id: messageId,
        reader_id: userId,
        user_id: userId,
        seen_at: seenAt.toISOString(),
      },
    });

    for (const member of members) {
      if (member.user_id === userId) continue;
      const sockets = this.connectionManager.getConnections(member.user_id);
      if (!sockets) continue;
      for (const socket of sockets) {
        if (socket.readyState === 1) socket.send(readEvent);
      }
    }
  }

  async markDelivered(
    userId: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    const convId = data.conv_id as string;
    const messageId = data.message_id as string;
    const senderId = data.sender_id as string;

    if (!senderId) return;

    const statusEvent = JSON.stringify({
      event: 'message_status',
      data: {
        conv_id: convId,
        message_id: messageId,
        status: 'delivered',
        user_id: userId,
      },
    });

    const sockets = this.connectionManager.getConnections(senderId);
    if (!sockets) return;
    for (const socket of sockets) {
      if (socket.readyState === 1) socket.send(statusEvent);
    }
  }

  // --- Sync ---

  async syncMessages(
    userId: string,
    lastSyncedAt: string,
  ): Promise<Record<string, unknown>[]> {
    const memberships = await this.memberRepo.find({
      where: { user_id: userId },
      select: ['conv_id'],
    });

    if (memberships.length === 0) return [];

    const convIds = memberships.map((m) => m.conv_id);
    const since = new Date(lastSyncedAt);

    const messages = await this.messageRepo
      .createQueryBuilder('m')
      .where('m.conv_id IN (:...convIds)', { convIds })
      .andWhere('m.created_at > :since', { since })
      .andWhere('m.deleted_at IS NULL')
      .orderBy('m.created_at', 'ASC')
      .take(100)
      .getMany();

    // Convert entities to plain objects so dynamically added `reactions` serializes correctly
    const plainMessages = messages.map((m) => ({ ...m }));
    await this.attachReactionsToMessages(plainMessages);
    await this.attachReplyToData(plainMessages);

    return plainMessages.map((message) =>
      this.serializeMessageForClient(message),
    );
  }

  async getConversationEncryptionKey(userId: string, convId: string) {
    await this.assertConversationMembership(userId, convId);

    let activeKey = await this.encryptionKeyRepo.findOne({
      where: { conv_id: convId, is_active: true },
      order: { created_at: 'DESC' },
    });

    if (!activeKey) {
      activeKey = await this.createConversationEncryptionKey(convId);
    }

    return {
      conv_id: activeKey.conv_id,
      key_id: activeKey.key_id,
      alg: activeKey.alg,
      version: activeKey.version,
      material: activeKey.material.toString('base64'),
    };
  }

  // --- Membership check ---

  async isMember(convId: string, userId: string): Promise<boolean> {
    const count = await this.memberRepo.count({
      where: { conv_id: convId, user_id: userId },
    });
    return count > 0;
  }

  // --- System messages ---

  async createBusinessSystemMessage(
    convId: string,
    actorId: string,
    contentKey: string,
    metadata: Record<string, unknown>,
  ): Promise<Message> {
    return this.insertSystemMessage(convId, actorId, contentKey, metadata);
  }

  async updateBusinessSystemMessage(
    messageId: string,
    contentKey: string,
    metadata: Record<string, unknown>,
  ): Promise<Message> {
    const message = await this.messageRepo.findOne({
      where: { id: messageId },
    });
    if (!message || message.deleted_at) {
      throw Object.assign(new Error('System message not found'), {
        code: 'NOT_FOUND',
      });
    }
    if (message.type !== 'system') {
      throw Object.assign(new Error('Only system messages can be updated'), {
        code: 'INVALID_MESSAGE_TYPE',
      });
    }
    const now = new Date();
    message.content = contentKey;
    message.metadata = { action: contentKey, ...metadata };
    message.edited_at = now;
    await this.messageRepo.query(
      `UPDATE messages SET content = $1, metadata = $2::jsonb, edited_at = $3 WHERE id = $4`,
      [contentKey, JSON.stringify(message.metadata), now, messageId],
    );
    await this.redisPubSub.publish(message.conv_id, {
      _event: 'message_updated',
      ...this.serializeMessageForClient({ ...message }),
      edited_at: now.toISOString(),
    });
    return message;
  }

  private async insertSystemMessage(
    convId: string,
    actorId: string,
    contentKey: string,
    metadata: Record<string, unknown>,
  ): Promise<Message> {
    const now = new Date();
    const id = crypto.randomUUID();
    const metaJson = JSON.stringify({ action: contentKey, ...metadata });

    const result = await this.messageRepo.query(
      `INSERT INTO messages (id, conv_id, sender_id, type, content, metadata, created_at)
       VALUES ($1, $2, $3, 'system', $4, $5::jsonb, $6)
       RETURNING *`,
      [id, convId, actorId, contentKey, metaJson, now],
    );

    const saved = result[0] as Message;
    await this.convRepo.update(convId, { last_message_at: now });
    await this.redisPubSub.publish(
      convId,
      this.serializeMessageForClient({ ...saved }),
    );
    return saved;
  }

  // --- Group conversation management ---

  async createGroupConversation(
    userId: string,
    name: string,
    memberIds: string[],
  ): Promise<Conversation> {
    // Deduplicate and remove creator from member list
    const uniqueIds = [...new Set(memberIds.filter((id) => id !== userId))];
    if (uniqueIds.length < 2) {
      throw new Error('At least 2 members required');
    }

    // Validate all members are active users
    const users = await this.userRepo.find({
      where: { id: In(uniqueIds), is_active: true },
      select: ['id', 'name'],
    });
    if (users.length !== uniqueIds.length) {
      throw new Error('Some member IDs are invalid or inactive');
    }

    // Create conversation
    const conv = this.convRepo.create({
      type: 'GROUP',
      name,
      created_by: userId,
    });
    const saved = await this.convRepo.save(conv);

    // Add creator
    await this.memberRepo.save(
      this.memberRepo.create({
        conv_id: saved.id,
        user_id: userId,
        role: 'creator',
      }),
    );

    // Add members
    const memberEntries = uniqueIds.map((id) =>
      this.memberRepo.create({
        conv_id: saved.id,
        user_id: id,
        role: 'member',
      }),
    );
    await this.memberRepo.save(memberEntries);

    // Subscribe the creator immediately if they already have an active socket
    if (this.connectionManager.isOnline(userId)) {
      await this.redisPubSub.subscribeConversation(saved.id);
    }

    // System message
    const actor = await this.userRepo.findOne({
      where: { id: userId },
      select: ['name'],
    });
    const actorName = actor?.name ?? 'Unknown';
    const systemMessage = await this.insertSystemMessage(
      saved.id,
      userId,
      'created_group',
      {
        actor_name: actorName,
        group_name: name,
      },
    );

    for (const member of users) {
      await this.notifyGroupMembershipAdded({
        recipientUserId: member.id,
        actorId: userId,
        actorName,
        conversation: saved,
        lastMessageAt: systemMessage.created_at,
      });
    }

    // Return with members
    return this.convRepo.findOne({
      where: { id: saved.id },
      relations: ['members', 'members.user'],
    }) as Promise<Conversation>;
  }

  async updateConversation(
    convId: string,
    userId: string,
    updates: { name?: string; avatar_url?: string | null },
  ): Promise<Conversation> {
    const conv = await this.convRepo.findOne({ where: { id: convId } });
    if (!conv) throw new Error('Conversation not found');
    if (conv.type !== 'GROUP')
      throw new Error('Cannot update DIRECT conversations');

    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership)
      throw Object.assign(new Error('Not a member'), { code: 'FORBIDDEN' });
    if (membership.role !== 'creator' && membership.role !== 'admin') {
      throw Object.assign(new Error('Only admin or creator can update group'), {
        code: 'FORBIDDEN',
      });
    }

    const actor = await this.userRepo.findOne({
      where: { id: userId },
      select: ['name'],
    });
    const actorName = actor?.name ?? 'Unknown';

    if (updates.name && updates.name !== conv.name) {
      const oldName = conv.name;
      await this.convRepo.update(convId, { name: updates.name });
      await this.insertSystemMessage(convId, userId, 'renamed_group', {
        actor_name: actorName,
        old_name: oldName,
        new_name: updates.name,
      });
    }

    if (
      updates.avatar_url !== undefined &&
      updates.avatar_url !== conv.avatar_url
    ) {
      await this.convRepo.update(convId, { avatar_url: updates.avatar_url });
      await this.insertSystemMessage(convId, userId, 'changed_avatar', {
        actor_name: actorName,
      });
    }

    return this.convRepo.findOne({
      where: { id: convId },
      relations: ['members', 'members.user'],
    }) as Promise<Conversation>;
  }

  async addMembers(
    convId: string,
    userId: string,
    memberIds: string[],
  ): Promise<{ added: number }> {
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership)
      throw Object.assign(new Error('Not a member'), { code: 'FORBIDDEN' });

    const conv = await this.convRepo.findOne({ where: { id: convId } });
    if (!conv || conv.type !== 'GROUP')
      throw new Error('Not a group conversation');

    // Validate and filter
    const uniqueIds = [...new Set(memberIds)];
    const validUsers = await this.userRepo.find({
      where: { id: In(uniqueIds), is_active: true },
      select: ['id', 'name'],
    });
    const existingMembers = await this.memberRepo.find({
      where: { conv_id: convId },
      select: ['user_id'],
    });
    const existingIds = new Set(existingMembers.map((m) => m.user_id));

    const actor = await this.userRepo.findOne({
      where: { id: userId },
      select: ['name'],
    });
    const actorName = actor?.name ?? 'Unknown';

    let added = 0;
    for (const user of validUsers) {
      if (existingIds.has(user.id)) continue;
      await this.memberRepo.save(
        this.memberRepo.create({
          conv_id: convId,
          user_id: user.id,
          role: 'member',
        }),
      );
      existingIds.add(user.id);
      const systemMessage = await this.insertSystemMessage(
        convId,
        userId,
        'added_member',
        {
          actor_name: actorName,
          member_name: user.name,
          member_id: user.id,
        },
      );
      await this.notifyGroupMembershipAdded({
        recipientUserId: user.id,
        actorId: userId,
        actorName,
        conversation: conv,
        lastMessageAt: systemMessage.created_at,
      });
      added++;
    }

    return { added };
  }

  async removeMember(
    convId: string,
    actorId: string,
    targetUserId: string,
  ): Promise<void> {
    const conv = await this.convRepo.findOne({ where: { id: convId } });
    if (!conv || conv.type !== 'GROUP')
      throw new Error('Not a group conversation');

    const targetMembership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: targetUserId },
    });
    if (!targetMembership) throw new Error('User is not a member');

    const isSelfRemoval = actorId === targetUserId;
    if (targetMembership.role === 'creator' && !isSelfRemoval) {
      throw Object.assign(new Error('Cannot remove the group creator'), {
        code: 'FORBIDDEN',
      });
    }

    if (!isSelfRemoval) {
      const actorMembership = await this.memberRepo.findOne({
        where: { conv_id: convId, user_id: actorId },
      });
      if (!actorMembership || actorMembership.role !== 'creator') {
        throw Object.assign(
          new Error('Only the group creator can remove members'),
          {
            code: 'FORBIDDEN',
          },
        );
      }
    }

    await this.memberRepo.delete({ conv_id: convId, user_id: targetUserId });

    const actor = await this.userRepo.findOne({
      where: { id: actorId },
      select: ['name'],
    });
    const target = await this.userRepo.findOne({
      where: { id: targetUserId },
      select: ['name'],
    });

    if (isSelfRemoval) {
      await this.insertSystemMessage(convId, actorId, 'left_group', {
        actor_name: actor?.name ?? 'Unknown',
      });
    } else {
      await this.insertSystemMessage(convId, actorId, 'removed_member', {
        actor_name: actor?.name ?? 'Unknown',
        member_name: target?.name ?? 'Unknown',
        member_id: targetUserId,
      });
    }
  }

  async updateMemberRole(
    convId: string,
    actorId: string,
    targetUserId: string,
    role: 'admin' | 'member',
  ): Promise<void> {
    const actorMembership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: actorId },
    });
    if (!actorMembership || actorMembership.role !== 'creator') {
      throw Object.assign(
        new Error('Only the group creator can change roles'),
        { code: 'FORBIDDEN' },
      );
    }

    if (actorId === targetUserId) {
      throw new Error('Cannot change your own role');
    }

    const targetMembership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: targetUserId },
    });
    if (!targetMembership) throw new Error('User is not a member');

    await this.memberRepo.update(
      { conv_id: convId, user_id: targetUserId },
      { role },
    );
  }

  // --- Reactions ---

  async toggleReaction(
    userId: string,
    messageId: string,
    convId: string,
    emoji: string,
  ): Promise<{ action: 'added' | 'removed'; reactions: ReactionGroup[] }> {
    // Validate membership
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership) {
      throw Object.assign(new Error('Not a member of this conversation'), {
        code: 'FORBIDDEN',
      });
    }

    // Check if reaction already exists
    const existing = await this.reactionRepo.findOne({
      where: { message_id: messageId, user_id: userId, emoji },
    });

    let action: 'added' | 'removed';

    if (existing) {
      // Remove
      await this.reactionRepo.delete({
        message_id: messageId,
        user_id: userId,
        emoji,
      });
      action = 'removed';
    } else {
      // Check limit: max 3 distinct emoji per user per message
      const count = await this.reactionRepo.count({
        where: { message_id: messageId, user_id: userId },
      });
      if (count >= 3) {
        throw Object.assign(new Error('Maximum 3 reactions per message'), {
          code: 'REACTION_LIMIT',
        });
      }
      // Insert
      await this.reactionRepo.save(
        this.reactionRepo.create({
          message_id: messageId,
          user_id: userId,
          emoji,
        }),
      );
      action = 'added';
    }

    const reactions = await this.getReactionsForMessage(messageId);
    return { action, reactions };
  }

  async getReactionsForMessage(messageId: string): Promise<ReactionGroup[]> {
    const rows: Array<{
      emoji: string;
      user_id: string;
      user_name: string;
    }> = await this.reactionRepo.query(
      `SELECT r.emoji, r.user_id, u.name AS user_name
       FROM message_reactions r
       JOIN users u ON u.id = r.user_id
       WHERE r.message_id = $1
       ORDER BY r.emoji, r.created_at`,
      [messageId],
    );

    const groups = new Map<
      string,
      {
        emoji: string;
        count: number;
        users: Array<{ id: string; name: string }>;
      }
    >();
    for (const row of rows) {
      let group = groups.get(row.emoji);
      if (!group) {
        group = { emoji: row.emoji, count: 0, users: [] };
        groups.set(row.emoji, group);
      }
      group.count++;
      group.users.push({ id: row.user_id, name: row.user_name });
    }
    return Array.from(groups.values());
  }

  async attachReactionsToMessages(
    messages: Array<Record<string, unknown>>,
  ): Promise<void> {
    if (messages.length === 0) return;
    const ids = messages.map((m) => m.id as string);

    const rows: Array<{
      message_id: string;
      emoji: string;
      user_id: string;
      user_name: string;
    }> = await this.reactionRepo.query(
      `SELECT r.message_id, r.emoji, r.user_id, u.name AS user_name
       FROM message_reactions r
       JOIN users u ON u.id = r.user_id
       WHERE r.message_id = ANY($1)
       ORDER BY r.message_id, r.emoji, r.created_at`,
      [ids],
    );

    // Group by message_id → emoji
    const byMessage = new Map<string, ReactionGroup[]>();
    for (const row of rows) {
      let groups = byMessage.get(row.message_id);
      if (!groups) {
        groups = [];
        byMessage.set(row.message_id, groups);
      }
      let group = groups.find((g) => g.emoji === row.emoji);
      if (!group) {
        group = { emoji: row.emoji, count: 0, users: [] };
        groups.push(group);
      }
      group.count++;
      group.users.push({ id: row.user_id, name: row.user_name });
    }

    for (const msg of messages) {
      (msg as any).reactions = byMessage.get(msg.id as string) ?? [];
    }
  }

  // --- Reply data ---

  private async attachReplyToData(
    messages: Array<Record<string, unknown>>,
  ): Promise<void> {
    if (messages.length === 0) return;
    const replyToIds = new Set<string>();
    for (const m of messages) {
      const rid = m.reply_to_id as string | null;
      if (rid) replyToIds.add(rid);
    }
    if (replyToIds.size === 0) return;

    const rows: Array<{
      id: string;
      sender_id: string;
      sender_name: string;
      content: string | null;
      type: string;
      metadata: Record<string, unknown> | string | null;
      deleted_at: Date | null;
    }> = await this.messageRepo.query(
      `SELECT m.id, m.sender_id, m.content, m.type, m.metadata, m.deleted_at, u.name AS sender_name
       FROM messages m
       LEFT JOIN users u ON u.id = m.sender_id
       WHERE m.id = ANY($1)`,
      [Array.from(replyToIds)],
    );

    const lookup = new Map<string, Record<string, unknown>>();
    for (const row of rows) {
      const serialized = this.serializeMessageForClient({
        id: row.id,
        sender_id: row.sender_id,
        sender_name: row.sender_name,
        content: row.deleted_at != null ? 'Tin nhắn đã thu hồi' : row.content,
        type: row.type,
        metadata: row.deleted_at != null ? null : row.metadata,
      });
      if (row.deleted_at != null) {
        delete serialized.encrypted_content;
      }
      lookup.set(row.id, serialized);
    }

    for (const msg of messages) {
      const rid = msg.reply_to_id as string | null;
      if (rid) {
        (msg as any).reply_to = lookup.get(rid) ?? null;
      }
    }
  }

  private async getReplyToSnapshot(
    messageId: string,
  ): Promise<Record<string, unknown> | null> {
    const rows: Array<{
      id: string;
      sender_id: string;
      sender_name: string;
      content: string | null;
      type: string;
      metadata: Record<string, unknown> | string | null;
    }> = await this.messageRepo.query(
      `SELECT m.id, m.sender_id, m.content, m.type, m.metadata, u.name AS sender_name
       FROM messages m
       LEFT JOIN users u ON u.id = m.sender_id
       WHERE m.id = $1`,
      [messageId],
    );
    if (rows.length === 0) return null;
    const row = rows[0];
    return this.serializeMessageForClient({
      id: row.id,
      sender_id: row.sender_id,
      sender_name: row.sender_name,
      content: row.content,
      type: row.type,
      metadata: row.metadata,
    });
  }

  // --- Search ---

  async searchMessages(
    userId: string,
    query?: string,
    convId?: string,
    cursor?: string,
    limit = 20,
    queryHashes?: string[],
  ) {
    // Get user's conversation IDs for membership check
    const memberships = await this.memberRepo.find({
      where: { user_id: userId },
      select: ['conv_id'],
    });
    if (memberships.length === 0) {
      console.log(`User ${userId} has no conversations for search`);
      return { results: [], next_cursor: null, has_more: false };
    }
    const memberConvIds = memberships.map((m) => m.conv_id);

    // If conv_id specified, verify membership
    if (convId && !memberConvIds.includes(convId)) {
      return { results: [], next_cursor: null, has_more: false };
    }

    const normalizedHashes = this.normalizeSearchQueryHashes(queryHashes);
    if (normalizedHashes) {
      if (!convId) {
        throw Object.assign(new Error('Blind-index search requires conv_id'), {
          code: 'INVALID_FORMAT',
        });
      }
      return this.searchMessagesByBlindIndex(
        convId,
        cursor,
        limit,
        normalizedHashes,
      );
    }

    const normalizedQuery = query?.trim();
    if (!normalizedQuery || normalizedQuery.length < 2) {
      throw Object.assign(new Error('Query must be at least 2 characters'), {
        code: 'INVALID_FORMAT',
      });
    }

    const prefixTsQuery = this.buildPrefixTsQuery(normalizedQuery);
    const likePattern = `%${normalizedQuery}%`;
    const params: unknown[] = [
      normalizedQuery,
      prefixTsQuery,
      likePattern,
      ChatService.MESSAGE_SEARCH_SIMILARITY_THRESHOLD,
      userId,
    ];
    let paramIdx = 6;

    let sql = `
      SELECT m.id, m.conv_id, m.sender_id, m.type, m.content, m.created_at,
             ts_headline('simple', COALESCE(m.content, ''), plainto_tsquery('simple', $1),
                         'MaxWords=30, MinWords=15, StartSel=<mark>, StopSel=</mark>') as snippet,
             c.name as conv_name, c.type as conv_type, c.avatar_url as conv_avatar_url,
             u.name as sender_name,
             GREATEST(
               CASE
                 WHEN m.search_vector @@ plainto_tsquery('simple', $1) THEN 1
                 ELSE 0
               END,
               CASE
                 WHEN $2::text IS NOT NULL
                   AND m.search_vector @@ to_tsquery('simple', $2)
                 THEN 0.95
                 ELSE 0
               END,
               CASE
                 WHEN COALESCE(m.content, '') ILIKE $3 THEN 0.85
                 ELSE 0
               END,
               similarity(COALESCE(m.content, ''), $1)
             ) as relevance
      FROM messages m
      INNER JOIN conversation_members cm ON cm.conv_id = m.conv_id AND cm.user_id = $5
      INNER JOIN conversations c ON c.id = m.conv_id
      INNER JOIN users u ON u.id = m.sender_id
      WHERE (
          m.search_vector @@ plainto_tsquery('simple', $1)
          OR ($2::text IS NOT NULL AND m.search_vector @@ to_tsquery('simple', $2))
          OR COALESCE(m.content, '') ILIKE $3
          OR similarity(COALESCE(m.content, ''), $1) >= $4
        )
        AND m.deleted_at IS NULL
    `;

    if (convId) {
      sql += ` AND m.conv_id = $${paramIdx}`;
      params.push(convId);
      paramIdx++;
    }

    if (cursor) {
      // cursor format: isoDate_uuid
      const sepIdx = cursor.lastIndexOf('_');
      if (sepIdx > 0) {
        const cursorDate = cursor.substring(0, sepIdx);
        const cursorId = cursor.substring(sepIdx + 1);
        sql += ` AND (m.created_at, m.id) < ($${paramIdx}, $${paramIdx + 1})`;
        params.push(cursorDate, cursorId);
        paramIdx += 2;
      }
    }

    sql += ` ORDER BY relevance DESC, m.created_at DESC, m.id DESC LIMIT $${paramIdx}`;
    params.push(limit + 1);

    // Set statement timeout for safety
    await this.messageRepo.query(`SET LOCAL statement_timeout = '5000'`);
    const rows = await this.messageRepo.query(sql, params);

    const hasMore = rows.length > limit;
    if (hasMore) rows.pop();

    const lastRow = rows[rows.length - 1];
    const nextCursor =
      hasMore && lastRow
        ? `${(lastRow.created_at as Date).toISOString()}_${lastRow.id}`
        : null;

    return {
      results: rows,
      next_cursor: nextCursor,
      has_more: hasMore,
    };
  }

  private async searchMessagesByBlindIndex(
    convId: string,
    cursor: string | undefined,
    limit: number,
    queryHashes: string[],
  ) {
    const safeLimit = Math.max(1, Math.min(limit, 50));
    const params: unknown[] = [convId, queryHashes, queryHashes.length];
    let paramIdx = 4;

    let sql = `
      SELECT m.id, m.conv_id, m.sender_id, m.type,
             CASE
               WHEN m.metadata ? '${ChatService.ENCRYPTED_CONTENT_METADATA_KEY}' THEN NULL
               ELSE m.content
             END as content,
             m.created_at,
             '' AS snippet,
             c.name as conv_name, c.type as conv_type, c.avatar_url as conv_avatar_url,
             u.name as sender_name
      FROM messages m
      INNER JOIN message_blind_indexes bi
        ON bi.message_id = m.id AND bi.conv_id = m.conv_id
      INNER JOIN conversations c ON c.id = m.conv_id
      INNER JOIN users u ON u.id = m.sender_id
      WHERE m.conv_id = $1
        AND bi.token_hash = ANY($2::varchar[])
        AND m.deleted_at IS NULL
    `;

    if (cursor) {
      const sepIdx = cursor.lastIndexOf('_');
      if (sepIdx > 0) {
        const cursorDate = cursor.substring(0, sepIdx);
        const cursorId = cursor.substring(sepIdx + 1);
        sql += ` AND (m.created_at, m.id) < ($${paramIdx}, $${paramIdx + 1})`;
        params.push(cursorDate, cursorId);
        paramIdx += 2;
      }
    }

    sql += `
      GROUP BY
        m.id, m.conv_id, m.sender_id, m.type, m.content, m.metadata, m.created_at,
        c.name, c.type, c.avatar_url, u.name
      HAVING COUNT(DISTINCT bi.token_hash) >= $3
      ORDER BY m.created_at DESC, m.id DESC
      LIMIT $${paramIdx}
    `;
    params.push(safeLimit + 1);

    await this.messageRepo.query(`SET LOCAL statement_timeout = '5000'`);
    const rows = await this.messageRepo.query(sql, params);

    const hasMore = rows.length > safeLimit;
    if (hasMore) rows.pop();

    const lastRow = rows[rows.length - 1];
    const nextCursor =
      hasMore && lastRow
        ? `${(lastRow.created_at as Date).toISOString()}_${lastRow.id}`
        : null;

    return {
      results: rows,
      next_cursor: nextCursor,
      has_more: hasMore,
    };
  }

  // --- Private bookmarks ---

  async bookmarkMessage(
    userId: string,
    convId: string,
    messageId: string,
  ): Promise<MessageBookmark> {
    await this.assertConversationMembership(userId, convId);
    await this.assertMessageBelongsToConversation(convId, messageId);

    const existing = await this.messageBookmarkRepo.findOne({
      where: { user_id: userId, conv_id: convId, message_id: messageId },
    });
    if (existing) {
      throw Object.assign(new Error('Message is already bookmarked'), {
        code: 'ALREADY_BOOKMARKED',
      });
    }

    return this.messageBookmarkRepo.save(
      this.messageBookmarkRepo.create({
        user_id: userId,
        conv_id: convId,
        message_id: messageId,
      }),
    );
  }

  async getBookmarks(
    userId: string,
    convId: string,
  ): Promise<
    Array<{
      user_id: string;
      conv_id: string;
      message_id: string;
      marked_at: Date;
      message_content: string | null;
      message_type: string;
      sender_id: string;
      sender_name: string;
      message_created_at: Date;
    }>
  > {
    await this.assertConversationMembership(userId, convId);

    return this.messageBookmarkRepo.query(
      `SELECT b.user_id, b.conv_id, b.message_id, b.marked_at,
              m.content AS message_content,
              m.type AS message_type,
              m.sender_id,
              u.name AS sender_name,
              m.created_at AS message_created_at
       FROM message_bookmarks b
       JOIN messages m
         ON m.id = b.message_id
        AND m.conv_id = b.conv_id
       JOIN users u ON u.id = m.sender_id
       WHERE b.user_id = $1
         AND b.conv_id = $2
       ORDER BY b.marked_at DESC`,
      [userId, convId],
    );
  }

  async getGlobalBookmarks(
    userId: string,
    query: GetGlobalBookmarksQueryDto,
  ): Promise<GlobalBookmarksResponseDto> {
    const limit = query.limit ?? 20;

    if (query.conv_id) {
      await this.assertConversationMembership(userId, query.conv_id);
    }

    const params: unknown[] = [userId];
    let paramIdx = 2;

    let sql = `
      SELECT b.message_id,
             b.conv_id,
             c.type AS conv_type,
             CASE
               WHEN c.type = 'DIRECT' THEN COALESCE(
                 NULLIF(BTRIM(direct_peer.name), ''),
                 NULLIF(BTRIM(c.name), ''),
                 'Direct chat'
               )
               ELSE COALESCE(NULLIF(BTRIM(c.name), ''), 'Group chat')
             END AS conv_name,
             CASE
               WHEN c.type = 'DIRECT' THEN COALESCE(direct_peer.avatar_url, c.avatar_url)
               ELSE c.avatar_url
             END AS conv_avatar_url,
             m.sender_id,
             COALESCE(sender.name, 'Unknown') AS sender_name,
             m.type AS message_type,
             m.content AS message_content,
             m.created_at AS message_created_at,
             b.marked_at
      FROM message_bookmarks b
      INNER JOIN conversation_members cm_self
        ON cm_self.conv_id = b.conv_id
       AND cm_self.user_id = $1
      INNER JOIN conversations c
        ON c.id = b.conv_id
      INNER JOIN messages m
        ON m.id = b.message_id
       AND m.conv_id = b.conv_id
      LEFT JOIN users sender
        ON sender.id = m.sender_id
      LEFT JOIN LATERAL (
        SELECT u.name, u.avatar_url
        FROM conversation_members cm_other
        LEFT JOIN users u ON u.id = cm_other.user_id
        WHERE cm_other.conv_id = c.id
          AND cm_other.user_id <> $1
        ORDER BY cm_other.joined_at ASC
        LIMIT 1
      ) AS direct_peer ON c.type = 'DIRECT'
      WHERE b.user_id = $1
        AND m.deleted_at IS NULL
    `;

    if (query.conv_id) {
      sql += ` AND b.conv_id = $${paramIdx}`;
      params.push(query.conv_id);
      paramIdx++;
    }

    if (query.type) {
      sql += ` AND m.type = $${paramIdx}`;
      params.push(query.type);
      paramIdx++;
    }

    if (query.cursor) {
      const { markedAt, messageId } = this.parseGlobalBookmarkCursor(
        query.cursor,
      );
      sql += ` AND (b.marked_at, b.message_id) < ($${paramIdx}, $${paramIdx + 1})`;
      params.push(markedAt, messageId);
      paramIdx += 2;
    }

    sql += ` ORDER BY b.marked_at DESC, b.message_id DESC LIMIT $${paramIdx}`;
    params.push(limit + 1);

    const rows: GlobalBookmarkQueryRow[] = await this.messageBookmarkRepo.query(
      sql,
      params,
    );

    const hasMore = rows.length > limit;
    if (hasMore) rows.pop();

    const items = rows.map((row) => ({
      ...row,
      message_created_at: this.toIsoString(row.message_created_at),
      marked_at: this.toIsoString(row.marked_at),
    }));
    const lastRow = items[items.length - 1];

    return {
      items,
      next_cursor:
        hasMore && lastRow
          ? this.buildGlobalBookmarkCursor(
              lastRow.marked_at,
              lastRow.message_id,
            )
          : null,
    };
  }

  async deleteBookmark(
    userId: string,
    convId: string,
    messageId: string,
  ): Promise<void> {
    await this.assertConversationMembership(userId, convId);

    const bookmark = await this.messageBookmarkRepo.findOne({
      where: { user_id: userId, conv_id: convId, message_id: messageId },
    });
    if (!bookmark) {
      throw Object.assign(new Error('Bookmark not found'), {
        code: 'NOT_FOUND',
      });
    }

    await this.messageBookmarkRepo.delete({
      user_id: userId,
      conv_id: convId,
      message_id: messageId,
    });
  }

  // --- Message reminders ---

  async listMessageReminders(
    userId: string,
    convId: string,
    messageId: string,
  ): Promise<MessageReminder[]> {
    await this.assertConversationMembership(userId, convId);
    await this.assertMessageBelongsToConversation(convId, messageId);

    return this.messageReminderRepo
      .createQueryBuilder('reminder')
      .where('reminder.conv_id = :convId', { convId })
      .andWhere('reminder.message_id = :messageId', { messageId })
      .andWhere(
        '(reminder.scope = :everyoneScope OR (reminder.scope = :selfScope AND reminder.creator_user_id = :userId))',
        {
          everyoneScope: 'everyone',
          selfScope: 'self',
          userId,
        },
      )
      .orderBy('reminder.remind_at', 'ASC')
      .getMany();
  }

  async getUpcomingReminders(userId: string): Promise<MessageReminder[]> {
    return this.messageReminderRepo
      .createQueryBuilder('reminder')
      .innerJoin(
        'conversation_members',
        'member',
        'member.conv_id = reminder.conv_id AND member.user_id = :userId',
        { userId },
      )
      .where('reminder.status = :status', { status: 'pending' })
      .andWhere('reminder.remind_at >= :now', { now: new Date() })
      .andWhere(
        '(reminder.scope = :everyoneScope OR (reminder.scope = :selfScope AND reminder.creator_user_id = :userId))',
        {
          everyoneScope: 'everyone',
          selfScope: 'self',
          userId,
        },
      )
      .orderBy('reminder.remind_at', 'ASC')
      .getMany();
  }

  async listConversationReminders(
    userId: string,
    convId: string,
  ): Promise<MessageReminder[]> {
    await this.assertConversationMembership(userId, convId);

    return this.messageReminderRepo
      .createQueryBuilder('reminder')
      .where('reminder.conv_id = :convId', { convId })
      .andWhere('reminder.status = :status', { status: 'pending' })
      .andWhere('reminder.remind_at >= :now', { now: new Date() })
      .andWhere(
        '(reminder.scope = :everyoneScope OR (reminder.scope = :selfScope AND reminder.creator_user_id = :userId))',
        {
          everyoneScope: 'everyone',
          selfScope: 'self',
          userId,
        },
      )
      .orderBy('reminder.remind_at', 'ASC')
      .getMany();
  }

  async createMessageReminder(
    userId: string,
    convId: string,
    dto: {
      message_id: string;
      scope: MessageReminderScope;
      remind_at: string;
    },
  ): Promise<MessageReminder> {
    await this.assertConversationMembership(userId, convId);
    const sourceMessage = await this.assertReminderSourceMessage(
      convId,
      dto.message_id,
    );
    const remindAt = this.parseFutureReminderTime(dto.remind_at);

    await this.assertNoDuplicatePendingReminder({
      convId,
      messageId: dto.message_id,
      creatorUserId: userId,
      scope: dto.scope,
      remindAt,
    });

    const reminder = await this.saveReminderOrThrowDuplicate(
      this.messageReminderRepo.create({
        conv_id: convId,
        message_id: dto.message_id,
        creator_user_id: userId,
        scope: dto.scope,
        status: 'pending',
        remind_at: remindAt,
        cancelled_at: null,
        fired_at: null,
      }),
    );

    await this.reminderJobService.scheduleReminder(reminder);
    await this.insertReminderLifecycleMessage(
      reminder,
      sourceMessage,
      'chat_reminder_created',
    );

    return reminder;
  }

  async updateMessageReminder(
    userId: string,
    convId: string,
    reminderId: string,
    dto: {
      scope?: MessageReminderScope;
      remind_at?: string;
    },
  ): Promise<MessageReminder> {
    const reminder = await this.getReminderForUpdate(
      userId,
      convId,
      reminderId,
    );
    if (!dto.scope && !dto.remind_at) {
      throw Object.assign(new Error('Nothing to update'), {
        code: 'INVALID_FORMAT',
      });
    }

    const nextScope = dto.scope ?? reminder.scope;
    const nextRemindAt = dto.remind_at
      ? this.parseFutureReminderTime(dto.remind_at)
      : reminder.remind_at;

    await this.assertNoDuplicatePendingReminder({
      convId,
      messageId: reminder.message_id,
      creatorUserId: userId,
      scope: nextScope,
      remindAt: nextRemindAt,
      excludeReminderId: reminder.id,
    });

    reminder.scope = nextScope;
    reminder.remind_at = nextRemindAt;
    reminder.updated_at = new Date();

    const saved = await this.saveReminderOrThrowDuplicate(reminder);
    await this.reminderJobService.scheduleReminder(saved);

    const sourceMessage = await this.getMessageOrThrow(reminder.message_id);
    await this.insertReminderLifecycleMessage(
      saved,
      sourceMessage,
      'chat_reminder_updated',
    );

    return saved;
  }

  async cancelMessageReminder(
    userId: string,
    convId: string,
    reminderId: string,
  ): Promise<MessageReminder> {
    const reminder = await this.getReminderForUpdate(
      userId,
      convId,
      reminderId,
    );

    reminder.status = 'cancelled';
    reminder.cancelled_at = new Date();
    reminder.updated_at = reminder.cancelled_at;

    const saved = await this.messageReminderRepo.save(reminder);
    await this.reminderJobService.removeReminder(reminder.id);

    const sourceMessage = await this.getMessageOrThrow(reminder.message_id);
    await this.insertReminderLifecycleMessage(
      saved,
      sourceMessage,
      'chat_reminder_cancelled',
    );

    return saved;
  }

  async fireReminder(reminderId: string): Promise<{
    recipientUserIds: string[];
    pushTitle: string;
    pushBody: string;
    pushData: Record<string, string>;
  } | null> {
    const reminder = await this.messageReminderRepo.findOne({
      where: { id: reminderId },
    });
    if (!reminder) return null;

    const now = new Date();
    const updateResult = await this.messageReminderRepo
      .createQueryBuilder()
      .update(MessageReminder)
      .set({
        status: 'fired',
        fired_at: now,
        updated_at: now,
      })
      .where('id = :id', { id: reminderId })
      .andWhere('status = :status', { status: 'pending' })
      .execute();

    if (!updateResult.affected) {
      return null;
    }

    const firedReminder = await this.getReminderOrThrow(reminderId);
    const sourceMessage = await this.getMessageOrThrow(
      firedReminder.message_id,
    );
    const metadata = await this.buildReminderSystemMetadata(
      firedReminder,
      sourceMessage,
      'chat_reminder_fired',
    );

    await this.insertSystemMessage(
      firedReminder.conv_id,
      firedReminder.creator_user_id,
      'chat_reminder_fired',
      metadata,
    );

    const recipientUserIds =
      firedReminder.scope === 'everyone'
        ? await this.getConversationMemberIds(firedReminder.conv_id)
        : [firedReminder.creator_user_id];

    return {
      recipientUserIds,
      pushTitle:
        firedReminder.scope === 'everyone'
          ? 'Chat reminder for everyone'
          : 'Chat reminder',
      pushBody:
        typeof metadata.source_message_preview === 'string' &&
        metadata.source_message_preview.length > 0
          ? metadata.source_message_preview
          : 'You have a chat reminder',
      pushData: {
        type: 'chat_reminder',
        conv_id: firedReminder.conv_id,
        message_id: firedReminder.message_id,
        reminder_id: firedReminder.id,
        scope: firedReminder.scope,
      },
    };
  }

  // --- Pin / Unpin ---

  private async assertConversationMembership(
    userId: string,
    convId: string,
  ): Promise<ConversationMember> {
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership) {
      throw Object.assign(new Error('Not a member of this conversation'), {
        code: 'FORBIDDEN',
      });
    }
    return membership;
  }

  private async createConversationEncryptionKey(
    convId: string,
  ): Promise<ConversationEncryptionKey> {
    const key = this.encryptionKeyRepo.create({
      conv_id: convId,
      key_id: crypto.randomUUID(),
      alg: ChatService.ENCRYPTION_ALGORITHM,
      version: ChatService.ENCRYPTION_VERSION,
      material: Buffer.from(crypto.getRandomValues(new Uint8Array(32))),
      is_active: true,
    });

    try {
      return await this.encryptionKeyRepo.save(key);
    } catch (error: any) {
      if (error?.code === '23505') {
        const activeKey = await this.encryptionKeyRepo.findOne({
          where: { conv_id: convId, is_active: true },
          order: { created_at: 'DESC' },
        });
        if (activeKey) {
          return activeKey;
        }
      }
      throw error;
    }
  }

  private parseMessageMetadata(
    metadata: unknown,
  ): Record<string, unknown> | null {
    if (!metadata) {
      return null;
    }

    if (typeof metadata === 'string') {
      try {
        const parsed = JSON.parse(metadata) as unknown;
        if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
          return parsed as Record<string, unknown>;
        }
      } catch {
        return null;
      }
      return null;
    }

    if (typeof metadata === 'object' && !Array.isArray(metadata)) {
      return metadata as Record<string, unknown>;
    }

    return null;
  }

  private extractEncryptedContentFromMetadata(
    metadata: Record<string, unknown> | null,
  ): EncryptedContentEnvelope | null {
    if (!metadata) {
      return null;
    }

    try {
      return this.normalizeEncryptedContent(
        MessageType.TEXT,
        metadata[ChatService.ENCRYPTED_CONTENT_METADATA_KEY],
      );
    } catch {
      return null;
    }
  }

  private serializeMessageForClient(
    message: Record<string, unknown>,
  ): Record<string, unknown> {
    const metadata = this.parseMessageMetadata(message.metadata);
    const encryptedContent = this.extractEncryptedContentFromMetadata(metadata);
    const nextMetadata = metadata ? { ...metadata } : null;

    if (nextMetadata) {
      delete nextMetadata[ChatService.ENCRYPTED_CONTENT_METADATA_KEY];
    }

    const serialized: Record<string, unknown> = {
      ...message,
      content: (message.content as string | null) ?? null,
      metadata:
        nextMetadata && Object.keys(nextMetadata).length > 0
          ? nextMetadata
          : null,
    };

    if (encryptedContent) {
      serialized.encrypted_content = encryptedContent;
    }

    return serialized;
  }

  private buildGlobalBookmarkCursor(
    markedAt: Date | string,
    messageId: string,
  ): string {
    const cursorDate = markedAt instanceof Date ? markedAt : new Date(markedAt);
    return `${cursorDate.toISOString()}_${messageId}`;
  }

  private toIsoString(value: Date | string): string {
    const dateValue = value instanceof Date ? value : new Date(value);
    return dateValue.toISOString();
  }

  private parseGlobalBookmarkCursor(cursor: string): {
    markedAt: string;
    messageId: string;
  } {
    const separatorIndex = cursor.lastIndexOf('_');
    if (separatorIndex <= 0 || separatorIndex === cursor.length - 1) {
      throw Object.assign(new Error('Invalid bookmark cursor'), {
        code: 'INVALID_CURSOR',
      });
    }

    const markedAt = cursor.substring(0, separatorIndex);
    const messageId = cursor.substring(separatorIndex + 1);

    if (Number.isNaN(Date.parse(markedAt))) {
      throw Object.assign(new Error('Invalid bookmark cursor'), {
        code: 'INVALID_CURSOR',
      });
    }

    return { markedAt, messageId };
  }

  private async assertMessageBelongsToConversation(
    convId: string,
    messageId: string,
  ): Promise<Message> {
    const message = await this.messageRepo.findOne({
      where: { id: messageId, conv_id: convId },
    });
    if (!message) {
      throw Object.assign(new Error('Message not found in this conversation'), {
        code: 'NOT_FOUND',
      });
    }
    return message;
  }

  private async assertReminderSourceMessage(
    convId: string,
    messageId: string,
  ): Promise<Message> {
    const message = await this.assertMessageBelongsToConversation(
      convId,
      messageId,
    );
    if (message.type === 'system') {
      throw Object.assign(
        new Error('Cannot create reminders for system messages'),
        {
          code: 'INVALID_MESSAGE_TYPE',
        },
      );
    }
    if (message.deleted_at) {
      throw Object.assign(
        new Error('Cannot create reminders for recalled messages'),
        {
          code: 'INVALID_MESSAGE_STATE',
        },
      );
    }
    return message;
  }

  private parseFutureReminderTime(remindAt: string): Date {
    const parsed = new Date(remindAt);
    if (Number.isNaN(parsed.getTime())) {
      throw Object.assign(new Error('Invalid remind_at'), {
        code: 'INVALID_FORMAT',
      });
    }
    if (parsed.getTime() <= Date.now()) {
      throw Object.assign(new Error('remind_at must be in the future'), {
        code: 'INVALID_REMIND_AT',
      });
    }
    return parsed;
  }

  private async assertNoDuplicatePendingReminder(params: {
    convId: string;
    messageId: string;
    creatorUserId: string;
    scope: MessageReminderScope;
    remindAt: Date;
    excludeReminderId?: string;
  }): Promise<void> {
    const qb = this.messageReminderRepo
      .createQueryBuilder('reminder')
      .where('reminder.conv_id = :convId', { convId: params.convId })
      .andWhere('reminder.message_id = :messageId', {
        messageId: params.messageId,
      })
      .andWhere('reminder.scope = :scope', { scope: params.scope })
      .andWhere('reminder.status = :status', { status: 'pending' })
      .andWhere('reminder.remind_at = :remindAt', {
        remindAt: params.remindAt,
      });

    if (params.scope === 'self') {
      qb.andWhere('reminder.creator_user_id = :creatorUserId', {
        creatorUserId: params.creatorUserId,
      });
    }

    if (params.excludeReminderId) {
      qb.andWhere('reminder.id != :excludeReminderId', {
        excludeReminderId: params.excludeReminderId,
      });
    }

    const duplicate = await qb.getOne();
    if (duplicate) {
      throw Object.assign(new Error('Duplicate reminder time is not allowed'), {
        code: 'DUPLICATE_REMINDER',
      });
    }
  }

  private async saveReminderOrThrowDuplicate(
    reminder: MessageReminder,
  ): Promise<MessageReminder> {
    try {
      return await this.messageReminderRepo.save(reminder);
    } catch (err: any) {
      if (err?.code === '23505') {
        throw Object.assign(
          new Error('Duplicate reminder time is not allowed'),
          {
            code: 'DUPLICATE_REMINDER',
          },
        );
      }
      throw err;
    }
  }

  private async getReminderOrThrow(
    reminderId: string,
  ): Promise<MessageReminder> {
    const reminder = await this.messageReminderRepo.findOne({
      where: { id: reminderId },
    });
    if (!reminder) {
      throw Object.assign(new Error('Reminder not found'), {
        code: 'NOT_FOUND',
      });
    }
    return reminder;
  }

  private async getReminderForUpdate(
    userId: string,
    convId: string,
    reminderId: string,
  ): Promise<MessageReminder> {
    await this.assertConversationMembership(userId, convId);
    const reminder = await this.getReminderOrThrow(reminderId);
    if (reminder.conv_id !== convId) {
      throw Object.assign(new Error('Reminder not found'), {
        code: 'NOT_FOUND',
      });
    }
    if (reminder.creator_user_id !== userId) {
      throw Object.assign(new Error('Only creator can manage reminder'), {
        code: 'FORBIDDEN',
      });
    }
    if (reminder.status !== 'pending') {
      throw Object.assign(new Error('Only pending reminders can be changed'), {
        code: 'INVALID_STATUS',
      });
    }
    return reminder;
  }

  async getMessageForUser(
    userId: string,
    messageId: string,
  ): Promise<Record<string, unknown>> {
    const message = await this.getMessageOrThrow(messageId);
    await this.assertConversationMembership(userId, message.conv_id);
    const plainMessage = { ...message };
    await this.attachReactionsToMessages([plainMessage]);
    await this.attachReplyToData([plainMessage]);
    return this.serializeMessageForClient(plainMessage);
  }

  private async getMessageOrThrow(messageId: string): Promise<Message> {
    const message = await this.messageRepo.findOne({
      where: { id: messageId },
    });
    if (!message) {
      throw Object.assign(new Error('Message not found'), {
        code: 'NOT_FOUND',
      });
    }
    return message;
  }

  private async getConversationMemberIds(convId: string): Promise<string[]> {
    const members = await this.memberRepo.find({
      where: { conv_id: convId },
      select: ['user_id'],
    });
    return [...new Set(members.map((member) => member.user_id))];
  }

  private getReminderMessagePreview(message: Message): string {
    const content = message.content?.trim();
    if (content) {
      return content.substring(0, 120);
    }

    switch (message.type) {
      case 'image':
        return '[Image]';
      case 'album':
        return '[Album]';
      case 'file':
        return '[File]';
      case 'voice':
        return '[Voice message]';
      case 'video':
        return '[Video]';
      default:
        return '[Message]';
    }
  }

  private async buildReminderSystemMetadata(
    reminder: MessageReminder,
    sourceMessage: Message,
    kind:
      | 'chat_reminder_created'
      | 'chat_reminder_updated'
      | 'chat_reminder_cancelled'
      | 'chat_reminder_fired',
  ): Promise<Record<string, unknown>> {
    const [creator, sourceSender] = await Promise.all([
      this.userRepo.findOne({
        where: { id: reminder.creator_user_id },
        select: ['id', 'name'],
      }),
      this.userRepo.findOne({
        where: { id: sourceMessage.sender_id },
        select: ['id', 'name'],
      }),
    ]);

    return {
      kind,
      reminder_id: reminder.id,
      source_message_id: reminder.message_id,
      source_message_preview: this.getReminderMessagePreview(sourceMessage),
      source_sender_id: sourceMessage.sender_id,
      source_sender_name: sourceSender?.name ?? 'Unknown',
      creator_user_id: reminder.creator_user_id,
      creator_name: creator?.name ?? 'Unknown',
      scope: reminder.scope,
      remind_at: reminder.remind_at.toISOString(),
      status: reminder.status,
      cancelled_at: reminder.cancelled_at?.toISOString() ?? null,
      fired_at: reminder.fired_at?.toISOString() ?? null,
    };
  }

  private async insertReminderLifecycleMessage(
    reminder: MessageReminder,
    sourceMessage: Message,
    kind:
      | 'chat_reminder_created'
      | 'chat_reminder_updated'
      | 'chat_reminder_cancelled',
  ): Promise<Message> {
    const metadata = await this.buildReminderSystemMetadata(
      reminder,
      sourceMessage,
      kind,
    );

    return this.insertSystemMessage(
      reminder.conv_id,
      reminder.creator_user_id,
      kind,
      metadata,
    );
  }

  private async canPin(userId: string, convId: string): Promise<boolean> {
    const conv = await this.convRepo.findOne({ where: { id: convId } });
    if (!conv) return false;
    if (conv.type === 'DIRECT') return true;
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership) return false;
    return (
      membership.role === 'creator' ||
      membership.role === 'admin' ||
      membership.role === 'member'
    );
  }

  async pinMessage(
    userId: string,
    convId: string,
    messageId: string,
  ): Promise<void> {
    await this.assertConversationMembership(userId, convId);

    if (!(await this.canPin(userId, convId))) {
      throw Object.assign(new Error('No permission to pin messages'), {
        code: 'FORBIDDEN',
      });
    }

    await this.assertMessageBelongsToConversation(convId, messageId);

    // Check not already pinned
    const existing = await this.pinnedMessageRepo.findOne({
      where: { conv_id: convId, message_id: messageId },
    });
    if (existing) {
      throw Object.assign(new Error('Message is already pinned'), {
        code: 'ALREADY_PINNED',
      });
    }

    // Check 5-pin limit
    const pinCount = await this.pinnedMessageRepo.count({
      where: { conv_id: convId },
    });
    // if (pinCount >= 5) {
    //   throw Object.assign(
    //     new Error('Maximum 5 pinned messages per conversation'),
    //     { code: 'PIN_LIMIT' },
    //   );
    // }

    await this.pinnedMessageRepo.save(
      this.pinnedMessageRepo.create({
        conv_id: convId,
        message_id: messageId,
        pinned_by: userId,
      }),
    );

    const actor = await this.userRepo.findOne({
      where: { id: userId },
      select: ['name'],
    });
    await this.insertSystemMessage(convId, userId, 'pinned_message', {
      actor_name: actor?.name ?? 'Unknown',
    });

    // Broadcast pin_update
    const pins = await this.getPinnedMessagesInternal(convId);
    await this.redisPubSub.publish(convId, {
      _event: 'pin_update',
      conv_id: convId,
      action: 'pinned',
      message_id: messageId,
      pinned_messages: pins,
    });
  }

  async unpinMessage(
    userId: string,
    convId: string,
    messageId: string,
  ): Promise<void> {
    await this.assertConversationMembership(userId, convId);

    if (!(await this.canPin(userId, convId))) {
      throw Object.assign(new Error('No permission to unpin messages'), {
        code: 'FORBIDDEN',
      });
    }

    const pin = await this.pinnedMessageRepo.findOne({
      where: { conv_id: convId, message_id: messageId },
    });
    if (!pin) {
      throw Object.assign(new Error('Message is not pinned'), {
        code: 'NOT_FOUND',
      });
    }

    await this.pinnedMessageRepo.delete({
      conv_id: convId,
      message_id: messageId,
    });

    const actor = await this.userRepo.findOne({
      where: { id: userId },
      select: ['name'],
    });
    await this.insertSystemMessage(convId, userId, 'unpinned_message', {
      actor_name: actor?.name ?? 'Unknown',
    });

    const pins = await this.getPinnedMessagesInternal(convId);
    await this.redisPubSub.publish(convId, {
      _event: 'pin_update',
      conv_id: convId,
      action: 'unpinned',
      message_id: messageId,
      pinned_messages: pins,
    });
  }

  async unpinAllMessages(userId: string, convId: string): Promise<void> {
    await this.assertConversationMembership(userId, convId);

    if (!(await this.canPin(userId, convId))) {
      throw Object.assign(new Error('No permission to unpin messages'), {
        code: 'FORBIDDEN',
      });
    }

    await this.pinnedMessageRepo.delete({ conv_id: convId });

    const actor = await this.userRepo.findOne({
      where: { id: userId },
      select: ['name'],
    });
    await this.insertSystemMessage(convId, userId, 'unpinned_all_messages', {
      actor_name: actor?.name ?? 'Unknown',
    });

    await this.redisPubSub.publish(convId, {
      _event: 'pin_update',
      conv_id: convId,
      action: 'unpinned_all',
      pinned_messages: [],
    });
  }

  async getPinnedMessages(
    userId: string,
    convId: string,
  ): Promise<
    Array<{
      conv_id: string;
      message_id: string;
      pinned_by: string;
      pinned_at: Date;
      message_content: string | null;
      message_type: string;
      sender_id: string;
      sender_name: string;
      pinner_name: string;
    }>
  > {
    await this.assertConversationMembership(userId, convId);

    return this.getPinnedMessagesInternal(convId);
  }

  private async getPinnedMessagesInternal(convId: string) {
    const rows = await this.pinnedMessageRepo.query(
      `SELECT p.conv_id, p.message_id, p.pinned_by, p.pinned_at,
              m.content AS message_content, m.metadata AS message_metadata, m.type AS message_type,
              m.sender_id, u.name AS sender_name, pu.name AS pinner_name
       FROM pinned_messages p
       JOIN messages m ON m.id = p.message_id
       JOIN users u ON u.id = m.sender_id
       JOIN users pu ON pu.id = p.pinned_by
       WHERE p.conv_id = $1
       ORDER BY p.pinned_at DESC`,
      [convId],
    );
    return rows;
  }

  async deleteGroup(convId: string, userId: string): Promise<void> {
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership || membership.role !== 'creator') {
      throw Object.assign(
        new Error('Only the group creator can delete the group'),
        { code: 'FORBIDDEN' },
      );
    }

    // Remove all members
    await this.memberRepo.delete({ conv_id: convId });

    // Soft-delete all messages
    await this.messageRepo
      .createQueryBuilder()
      .update(Message)
      .set({ deleted_at: new Date() })
      .where('conv_id = :convId', { convId })
      .andWhere('deleted_at IS NULL')
      .execute();

    // Mark conversation as deleted (set name null + clear last_message_at)
    await this.convRepo.update(convId, {
      name: '[Đã xóa]',
      last_message_at: null,
    });
  }

  // --- Edit Message ---

  async editMessage(
    userId: string,
    messageId: string,
    newContent?: string,
    newMetadata?: Record<string, unknown>,
    blindIndexPayload?: unknown,
  ): Promise<Message> {
    // Find the message
    const message = await this.messageRepo.findOne({
      where: { id: messageId },
    });
    if (!message) {
      throw Object.assign(new Error('Message not found'), {
        code: 'NOT_FOUND',
      });
    }

    // Check if message is recalled
    if (message.deleted_at) {
      throw Object.assign(new Error('Cannot edit a recalled message'), {
        code: 'FORBIDDEN',
      });
    }

    // Check ownership
    if (message.sender_id !== userId) {
      throw Object.assign(new Error('You can only edit your own messages'), {
        code: 'FORBIDDEN',
      });
    }

    // Check message type (only text can be edited)
    if (message.type !== 'text') {
      throw Object.assign(new Error('Only text messages can be edited'), {
        code: 'INVALID_MESSAGE_TYPE',
      });
    }

    const oldMetadata = this.parseMessageMetadata(message.metadata);
    const hasEncryptedContent =
      !!this.extractEncryptedContentFromMetadata(oldMetadata);

    let finalContent: string;
    let finalMetadata = oldMetadata ? { ...oldMetadata } : {};

    if (hasEncryptedContent) {
      // For encrypted messages, we require new encrypted_content
      const newEncryptedContent = this.extractEncryptedContentFromMetadata(
        newMetadata || null,
      );
      if (!newEncryptedContent) {
        throw Object.assign(
          new Error(
            'Encrypted text messages must provide new encrypted_content to be edited',
          ),
          { code: 'INVALID_MESSAGE_STATE' },
        );
      }

      // Preserve existing metadata, but update encrypted_content
      finalMetadata[ChatService.ENCRYPTED_CONTENT_METADATA_KEY] =
        newEncryptedContent;
      finalContent = '[Tin nhắn mã hóa]';
    } else {
      // For plaintext messages, we require newContent and forbid encrypted_content
      if (!newContent || newContent.trim().length === 0) {
        throw Object.assign(new Error('Content cannot be empty'), {
          code: 'INVALID_CONTENT',
        });
      }

      if (this.extractEncryptedContentFromMetadata(newMetadata || null)) {
        throw Object.assign(
          new Error(
            'Plaintext messages cannot be converted to encrypted messages',
          ),
          { code: 'INVALID_MESSAGE_STATE' },
        );
      }

      finalContent = newContent.trim();
      // If they provided other metadata, merge it (optional, but consistent)
      if (newMetadata) {
        finalMetadata = { ...finalMetadata, ...newMetadata };
      }
    }

    // Update the message using raw SQL (composite primary key)
    const now = new Date();
    if (blindIndexPayload && !hasEncryptedContent) {
      throw Object.assign(
        new Error(
          'blind_index_v1 is only supported for encrypted text messages',
        ),
        {
          code: 'INVALID_FORMAT',
        },
      );
    }
    await this.messageRepo.query(
      `UPDATE messages SET content = $1, metadata = $2, edited_at = $3 WHERE id = $4`,
      [
        finalContent,
        Object.keys(finalMetadata).length > 0
          ? JSON.stringify(finalMetadata)
          : null,
        now,
        messageId,
      ],
    );

    const nextBlindIndexTokens =
      this.normalizeBlindIndexTokens(blindIndexPayload);
    if (hasEncryptedContent || blindIndexPayload) {
      await this.replaceBlindIndexTokens(
        messageId,
        message.conv_id,
        nextBlindIndexTokens ?? [],
      );
    }

    // Fetch updated message
    const updated = await this.messageRepo.findOne({
      where: { id: messageId },
    });
    if (!updated) {
      throw Object.assign(new Error('Message not found'), {
        code: 'NOT_FOUND',
      });
    }

    // Publish to Redis for realtime
    await this.redisPubSub.publish(message.conv_id, {
      _event: 'message_updated',
      ...this.serializeMessageForClient({
        ...updated,
        edited_at: now.toISOString(),
      }),
      edited_at: now.toISOString(),
    });

    return updated;
  }

  // --- Recall Message ---

  async recallMessage(
    userId: string,
    messageId: string,
    reason?: string,
  ): Promise<Message> {
    // Find the message
    const message = await this.messageRepo.findOne({
      where: { id: messageId },
    });
    if (!message) {
      throw Object.assign(new Error('Message not found'), {
        code: 'NOT_FOUND',
      });
    }

    // Check if already recalled
    if (message.deleted_at) {
      throw Object.assign(new Error('Message is already recalled'), {
        code: 'ALREADY_RECALLED',
      });
    }

    // Check ownership
    if (message.sender_id !== userId) {
      throw Object.assign(new Error('You can only recall your own messages'), {
        code: 'FORBIDDEN',
      });
    }

    // Soft-delete the message (set deleted_at) using raw SQL
    const now = new Date();
    const metadata = message.metadata ? { ...message.metadata } : {};
    if (reason) {
      metadata.recall_reason = reason;
    }
    metadata.recalled_by = userId;
    metadata.recalled_at = now.toISOString();

    await this.messageRepo.query(
      `UPDATE messages SET deleted_at = $1, metadata = $2::jsonb WHERE id = $3`,
      [now, JSON.stringify(metadata), messageId],
    );
    await this.messageBlindIndexRepo.delete({ message_id: messageId });

    // Fetch updated message
    const updated = await this.messageRepo.findOne({
      where: { id: messageId },
    });
    if (!updated) {
      throw Object.assign(new Error('Message not found'), {
        code: 'NOT_FOUND',
      });
    }

    // Publish to Redis for realtime
    await this.redisPubSub.publish(message.conv_id, {
      _event: 'message_recalled',
      message_id: messageId,
      conv_id: message.conv_id,
      deleted_at: now.toISOString(),
      reason: reason || null,
    });

    return updated;
  }

  // ===== Group Info Assets APIs =====

  /**
   * Get media (image, album, video) from a conversation with cursor pagination
   */
  async getConversationMedia(
    userId: string,
    convId: string,
    cursor?: string,
    limit = 20,
    type: 'all' | 'image' | 'video' = 'all',
  ) {
    await this.assertConversationMembership(userId, convId);

    const safeLimit = Math.min(Math.max(limit, 1), 100);

    // Build type filter
    let typeFilter: string[] = [];
    if (type === 'all') {
      typeFilter = [MessageType.IMAGE, MessageType.ALBUM, MessageType.VIDEO];
    } else if (type === 'image') {
      typeFilter = [MessageType.IMAGE, MessageType.ALBUM];
    } else if (type === 'video') {
      typeFilter = [MessageType.VIDEO];
    }

    // Parse cursor: format "created_at|message_id"
    let cursorCreatedAt: Date | null = null;
    let cursorMessageId: string | null = null;
    if (cursor) {
      const parts = cursor.split('|');
      if (parts.length === 2) {
        cursorCreatedAt = new Date(parts[0]);
        cursorMessageId = parts[1];
      }
    }

    // Build query
    const qb = this.messageRepo
      .createQueryBuilder('m')
      .leftJoinAndSelect('m.sender', 'u')
      .where('m.conv_id = :convId', { convId })
      .andWhere('m.type IN (:...types)', { types: typeFilter })
      .andWhere('m.deleted_at IS NULL')
      .orderBy('m.created_at', 'DESC')
      .addOrderBy('m.id', 'DESC');

    // Apply cursor
    if (cursorCreatedAt && cursorMessageId) {
      qb.andWhere(
        '(m.created_at < :cursorCreatedAt OR (m.created_at = :cursorCreatedAt AND m.id < :cursorMessageId))',
        { cursorCreatedAt, cursorMessageId },
      );
    }

    const messages = await qb.take(safeLimit + 1).getMany();

    const hasMore = messages.length > safeLimit;
    const items = hasMore ? messages.slice(0, safeLimit) : messages;

    const nextCursor =
      hasMore && items.length > 0
        ? `${items[items.length - 1].created_at.toISOString()}|${items[items.length - 1].id}`
        : null;

    return {
      items: items.map((m) => ({
        message_id: m.id,
        conv_id: m.conv_id,
        sender_id: m.sender_id,
        sender_name: m.sender?.name || 'Unknown',
        type: m.type,
        content: m.content,
        created_at: m.created_at.toISOString(),
        metadata: m.metadata || {},
      })),
      next_cursor: nextCursor,
      has_more: hasMore,
    };
  }

  /**
   * Get files from a conversation with cursor pagination
   */
  async getConversationFiles(
    userId: string,
    convId: string,
    cursor?: string,
    limit = 20,
  ) {
    await this.assertConversationMembership(userId, convId);

    const safeLimit = Math.min(Math.max(limit, 1), 100);

    // Parse cursor
    let cursorCreatedAt: Date | null = null;
    let cursorMessageId: string | null = null;
    if (cursor) {
      const parts = cursor.split('|');
      if (parts.length === 2) {
        cursorCreatedAt = new Date(parts[0]);
        cursorMessageId = parts[1];
      }
    }

    // Build query
    const qb = this.messageRepo
      .createQueryBuilder('m')
      .leftJoinAndSelect('m.sender', 'u')
      .where('m.conv_id = :convId', { convId })
      .andWhere('m.type = :type', { type: MessageType.FILE })
      .andWhere('m.deleted_at IS NULL')
      .orderBy('m.created_at', 'DESC')
      .addOrderBy('m.id', 'DESC');

    // Apply cursor
    if (cursorCreatedAt && cursorMessageId) {
      qb.andWhere(
        '(m.created_at < :cursorCreatedAt OR (m.created_at = :cursorCreatedAt AND m.id < :cursorMessageId))',
        { cursorCreatedAt, cursorMessageId },
      );
    }

    const messages = await qb.take(safeLimit + 1).getMany();

    const hasMore = messages.length > safeLimit;
    const items = hasMore ? messages.slice(0, safeLimit) : messages;

    const nextCursor =
      hasMore && items.length > 0
        ? `${items[items.length - 1].created_at.toISOString()}|${items[items.length - 1].id}`
        : null;

    return {
      items: items.map((m) => ({
        message_id: m.id,
        conv_id: m.conv_id,
        sender_id: m.sender_id,
        sender_name: m.sender?.name || 'Unknown',
        type: m.type,
        content: m.content,
        created_at: m.created_at.toISOString(),
        metadata: m.metadata || {},
      })),
      next_cursor: nextCursor,
      has_more: hasMore,
    };
  }

  /**
   * Get messages with links from a conversation with cursor pagination
   */
  async getConversationLinks(
    userId: string,
    convId: string,
    cursor?: string,
    limit = 20,
  ) {
    await this.assertConversationMembership(userId, convId);

    const safeLimit = Math.min(Math.max(limit, 1), 100);

    // Parse cursor
    let cursorCreatedAt: Date | null = null;
    let cursorMessageId: string | null = null;
    if (cursor) {
      const parts = cursor.split('|');
      if (parts.length === 2) {
        cursorCreatedAt = new Date(parts[0]);
        cursorMessageId = parts[1];
      }
    }

    // Build query - find text messages with URLs
    // URL regex pattern to match http/https URLs
    const urlPattern = '(https?://[^\\s]+)';

    const qb = this.messageRepo
      .createQueryBuilder('m')
      .leftJoinAndSelect('m.sender', 'u')
      .where('m.conv_id = :convId', { convId })
      .andWhere('m.type = :type', { type: MessageType.TEXT })
      .andWhere('m.deleted_at IS NULL')
      .andWhere('m.content ~ :urlPattern', { urlPattern })
      .orderBy('m.created_at', 'DESC')
      .addOrderBy('m.id', 'DESC');

    // Apply cursor
    if (cursorCreatedAt && cursorMessageId) {
      qb.andWhere(
        '(m.created_at < :cursorCreatedAt OR (m.created_at = :cursorCreatedAt AND m.id < :cursorMessageId))',
        { cursorCreatedAt, cursorMessageId },
      );
    }

    const messages = await qb.take(safeLimit + 1).getMany();

    const hasMore = messages.length > safeLimit;
    const items = hasMore ? messages.slice(0, safeLimit) : messages;

    const nextCursor =
      hasMore && items.length > 0
        ? `${items[items.length - 1].created_at.toISOString()}|${items[items.length - 1].id}`
        : null;

    // Extract links from content
    const urlRegex = /(https?:\/\/[^\s]+)/g;

    return {
      items: items.map((m) => {
        const links = m.content
          ? [...m.content.matchAll(urlRegex)].map((match) => match[0])
          : [];
        return {
          message_id: m.id,
          conv_id: m.conv_id,
          sender_id: m.sender_id,
          sender_name: m.sender?.name || 'Unknown',
          type: m.type,
          content: m.content,
          created_at: m.created_at.toISOString(),
          metadata: m.metadata || {},
          links,
        };
      }),
      next_cursor: nextCursor,
      has_more: hasMore,
    };
  }

  /**
   * Get assets summary for a conversation
   */
  async getConversationAssetsSummary(userId: string, convId: string) {
    await this.assertConversationMembership(userId, convId);

    // Count members
    const membersCount = await this.memberRepo.count({
      where: { conv_id: convId },
    });

    // Count media (image, album, video)
    const mediaCount = await this.messageRepo.count({
      where: {
        conv_id: convId,
        type: In([MessageType.IMAGE, MessageType.ALBUM, MessageType.VIDEO]),
        deleted_at: IsNull(),
      },
    });

    // Count files
    const filesCount = await this.messageRepo.count({
      where: {
        conv_id: convId,
        type: MessageType.FILE,
        deleted_at: IsNull(),
      },
    });

    // Count links - messages with URLs in content
    const urlPattern = '(https?://[^\\s]+)';
    const linksCountResult = await this.messageRepo
      .createQueryBuilder('m')
      .where('m.conv_id = :convId', { convId })
      .andWhere('m.type = :type', { type: MessageType.TEXT })
      .andWhere('m.deleted_at IS NULL')
      .andWhere('m.content ~ :urlPattern', { urlPattern })
      .getCount();

    return {
      members_count: membersCount,
      media_count: mediaCount,
      files_count: filesCount,
      links_count: linksCountResult,
    };
  }
}
