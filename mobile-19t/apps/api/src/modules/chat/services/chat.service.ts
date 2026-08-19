import { Injectable, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Queue } from 'bullmq';
import type { WebSocket } from 'ws';
import { Conversation } from '../entities/conversation.entity.js';
import { ConversationMember } from '../entities/conversation-member.entity.js';
import { Message } from '../entities/message.entity.js';
import { MessageReaction } from '../entities/message-reaction.entity.js';
import { PinnedMessage } from '../entities/pinned-message.entity.js';
import { MessageBookmark } from '../entities/message-bookmark.entity.js';
import {
  MessageReminder,
  type MessageReminderScope,
} from '../entities/message-reminder.entity.js';
import { User } from '../../auth/entities/user.entity.js';
import {
  CreateMessageReminderDto,
  UpdateMessageReminderDto,
  BookmarkConversationTypeFilterDto,
} from '../dto/chat.dto.js';
import { CHAT_REMINDER_QUEUE } from '../chat.constants.js';
import { RedisPubSubService } from './redis-pubsub.service.js';
import { NotificationJobService } from './notification-job.service.js';
import { ConnectionManager } from './connection-manager.service.js';

export interface ReactionGroup {
  emoji: string;
  count: number;
  users: Array<{ id: string; name: string }>;
}

type PlainMessage = Record<string, unknown>;

type GlobalBookmarkedMessageRow = {
  user_id: string;
  conv_id: string;
  message_id: string;
  marked_at: Date;
  message_content: string | null;
  message_type: string;
  sender_id: string;
  sender_name: string;
  message_created_at: Date;
  conversation_type: string;
  conversation_name: string | null;
  conversation_avatar_url: string | null;
};

@Injectable()
export class ChatService {
  private readonly logger = new Logger(ChatService.name);

  constructor(
    @InjectRepository(Conversation)
    private readonly convRepo: Repository<Conversation>,
    @InjectRepository(ConversationMember)
    private readonly memberRepo: Repository<ConversationMember>,
    @InjectRepository(Message)
    private readonly messageRepo: Repository<Message>,
    @InjectRepository(MessageReaction)
    private readonly reactionRepo: Repository<MessageReaction>,
    @InjectRepository(PinnedMessage)
    private readonly pinnedMessageRepo: Repository<PinnedMessage>,
    @InjectRepository(MessageBookmark)
    private readonly messageBookmarkRepo: Repository<MessageBookmark>,
    @InjectRepository(MessageReminder)
    private readonly messageReminderRepo: Repository<MessageReminder>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectQueue(CHAT_REMINDER_QUEUE)
    private readonly reminderQueue: Queue,
    private readonly redisPubSub: RedisPubSubService,
    private readonly notificationJob: NotificationJobService,
    private readonly connectionManager: ConnectionManager,
  ) {}

  // --- Send message ---

  async sendMessage(
    senderId: string,
    data: Record<string, unknown>,
    senderSocket?: WebSocket,
  ): Promise<Message> {
    const convId = data.conv_id as string;
    const messageId = data.id as string;

    // Validate membership
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: senderId },
    });
    if (!membership) {
      const err = new Error('Not a member of this conversation');
      (err as any).code = 'FORBIDDEN';
      throw err;
    }

    // Idempotent insert using ON CONFLICT
    const now = new Date();
    const msgType = (data.type as string) || 'text';
    const content = (data.content as string) || null;
    const replyToId = (data.reply_to_id as string) || null;
    const metadata = data.metadata ? JSON.stringify(data.metadata) : null;
    const forwardedFromId = (data.forwarded_from_id as string) || null;
    const forwardedFromSender = (data.forwarded_from_sender as string) || null;

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

    // Publish to Redis for fan-out (include reply_to snapshot if applicable)
    const publishData: Record<string, unknown> = {
      ...saved,
      _senderSocket: undefined, // internal marker removed by pubsub
    };
    if (replyToId) {
      publishData.reply_to = await this.getReplyToSnapshot(replyToId);
    }
    await this.redisPubSub.publish(convId, publishData);

    // Enqueue push notifications for offline members
    await this.enqueueOfflinePush(convId, senderId, saved);

    return saved;
  }

  async editMessage(
    userId: string,
    convId: string,
    messageId: string,
    content: string,
  ): Promise<PlainMessage> {
    await this.ensureConversationMembership(userId, convId);
    const message = await this.ensureMessageBelongsToConversation(convId, messageId);

    if (message.sender_id !== userId) {
      throw Object.assign(new Error('No permission to edit this message'), {
        code: 'FORBIDDEN',
      });
    }
    if (message.deleted_at) {
      throw Object.assign(new Error('Message has already been recalled'), {
        code: 'ALREADY_RECALLED',
      });
    }
    if (message.type !== 'text') {
      throw Object.assign(new Error('Only text messages can be edited'), {
        code: 'INVALID_MESSAGE_TYPE',
      });
    }

    const nextContent = content.trim();
    if (nextContent.length === 0) {
      throw Object.assign(new Error('Message content cannot be empty'), {
        code: 'INVALID_CONTENT',
      });
    }

    if (message.content !== nextContent) {
      await this.messageRepo.update(
        { id: messageId, conv_id: convId },
        { content: nextContent, edited_at: new Date() },
      );
    }

    const updated = await this.ensureMessageBelongsToConversation(convId, messageId);
    const serialized = await this.serializeSingleMessage(updated);
    await this.redisPubSub.publish(convId, {
      ...(serialized as Record<string, unknown>),
      _event: 'message_updated',
    });
    return serialized;
  }

  async recallMessage(
    userId: string,
    convId: string,
    messageId: string,
  ): Promise<PlainMessage> {
    await this.ensureConversationMembership(userId, convId);
    const message = await this.ensureMessageBelongsToConversation(convId, messageId);

    if (message.sender_id !== userId) {
      throw Object.assign(new Error('No permission to recall this message'), {
        code: 'FORBIDDEN',
      });
    }
    if (message.deleted_at) {
      throw Object.assign(new Error('Message has already been recalled'), {
        code: 'ALREADY_RECALLED',
      });
    }

    await this.messageRepo.update(
      { id: messageId, conv_id: convId },
      { deleted_at: new Date() },
    );

    const recalled = await this.ensureMessageBelongsToConversation(convId, messageId);
    const serialized = await this.serializeSingleMessage(recalled);
    await this.redisPubSub.publish(convId, {
      ...(serialized as Record<string, unknown>),
      _event: 'message_recalled',
    });
    return serialized;
  }

  async listMessageReminders(
    userId: string,
    convId: string,
    messageId: string,
  ): Promise<Array<Record<string, unknown>>> {
    await this.ensureConversationMembership(userId, convId);
    await this.ensureMessageBelongsToConversation(convId, messageId);

    const reminders = await this.messageReminderRepo
      .createQueryBuilder('reminder')
      .where('reminder.conv_id = :convId', { convId })
      .andWhere('reminder.message_id = :messageId', { messageId })
      .andWhere(
        '(reminder.creator_user_id = :userId OR reminder.scope = :everyone)',
        { userId, everyone: 'everyone' },
      )
      .orderBy('reminder.remind_at', 'ASC')
      .addOrderBy('reminder.created_at', 'ASC')
      .getMany();

    return reminders.map((reminder) => this.serializeReminder(reminder));
  }

  async createMessageReminder(
    userId: string,
    convId: string,
    dto: CreateMessageReminderDto,
  ): Promise<Record<string, unknown>> {
    await this.ensureConversationMembership(userId, convId);
    const sourceMessage = await this.ensureReminderSourceMessage(
      convId,
      dto.message_id,
      { allowDeleted: false },
    );
    const scope = this.normalizeReminderScope(dto.scope);
    const remindAt = this.parseReminderDate(dto.remind_at);

    await this.ensureReminderDuplicateFree({
      convId,
      messageId: sourceMessage.id,
      creatorUserId: userId,
      scope,
      remindAt,
    });

    const reminder = await this.messageReminderRepo.save(
      this.messageReminderRepo.create({
        id: crypto.randomUUID(),
        conv_id: convId,
        message_id: sourceMessage.id,
        creator_user_id: userId,
        scope,
        remind_at: remindAt,
        status: 'pending',
      }),
    );

    await this.scheduleReminderJob(reminder);

    const metadata = await this.buildReminderMetadata(
      reminder,
      sourceMessage,
      'chat_reminder_created',
    );
    await this.insertSystemMessage(
      convId,
      userId,
      'chat_reminder_created',
      metadata,
    );

    return this.serializeReminder(reminder);
  }

  async updateMessageReminder(
    userId: string,
    convId: string,
    reminderId: string,
    dto: UpdateMessageReminderDto,
  ): Promise<Record<string, unknown>> {
    const reminder = await this.ensureEditableReminder(userId, convId, reminderId);
    const sourceMessage = await this.ensureReminderSourceMessage(
      convId,
      reminder.message_id,
    );

    const scope = dto.scope
      ? this.normalizeReminderScope(dto.scope)
      : reminder.scope;
    const remindAt = dto.remind_at
      ? this.parseReminderDate(dto.remind_at)
      : reminder.remind_at;

    await this.ensureReminderDuplicateFree({
      convId,
      messageId: reminder.message_id,
      creatorUserId: reminder.creator_user_id,
      scope,
      remindAt,
      excludeReminderId: reminder.id,
    });

    reminder.scope = scope;
    reminder.remind_at = remindAt;
    await this.messageReminderRepo.save(reminder);
    await this.scheduleReminderJob(reminder);

    const metadata = await this.buildReminderMetadata(
      reminder,
      sourceMessage,
      'chat_reminder_updated',
    );
    await this.insertSystemMessage(
      convId,
      userId,
      'chat_reminder_updated',
      metadata,
    );

    return this.serializeReminder(reminder);
  }

  async cancelMessageReminder(
    userId: string,
    convId: string,
    reminderId: string,
  ): Promise<Record<string, unknown>> {
    const reminder = await this.ensureEditableReminder(userId, convId, reminderId);
    const sourceMessage = await this.ensureReminderSourceMessage(
      convId,
      reminder.message_id,
    );

    reminder.status = 'cancelled';
    reminder.cancelled_at = new Date();
    await this.messageReminderRepo.save(reminder);
    await this.removeReminderJob(reminder.id);

    const metadata = await this.buildReminderMetadata(
      reminder,
      sourceMessage,
      'chat_reminder_cancelled',
    );
    await this.insertSystemMessage(
      convId,
      userId,
      'chat_reminder_cancelled',
      metadata,
    );

    return this.serializeReminder(reminder);
  }

  async fireMessageReminder(reminderId: string): Promise<void> {
    const reminder = await this.messageReminderRepo.findOne({
      where: { id: reminderId },
    });
    if (!reminder || reminder.status !== 'pending') return;

    const fireResult = await this.messageReminderRepo
      .createQueryBuilder()
      .update(MessageReminder)
      .set({ status: 'fired', fired_at: new Date() })
      .where('id = :id', { id: reminderId })
      .andWhere('status = :status', { status: 'pending' })
      .execute();
    if (!fireResult.affected) return;

    const firedReminder = await this.ensureReminderExists(reminderId, reminder.conv_id);
    const sourceMessage = await this.ensureReminderSourceMessage(
      firedReminder.conv_id,
      firedReminder.message_id,
    );
    const metadata = await this.buildReminderMetadata(
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

    const recipients =
      firedReminder.scope === 'everyone'
        ? await this.memberRepo.find({
            where: { conv_id: firedReminder.conv_id },
            select: ['user_id'],
          })
        : [{ user_id: firedReminder.creator_user_id }];

    for (const recipient of recipients) {
      await this.notificationJob.enqueueReminderPush({
        recipientUserId: recipient.user_id,
        convId: firedReminder.conv_id,
        reminderId: firedReminder.id,
        sourceMessageId: firedReminder.message_id,
        sourceMessagePreview:
          (metadata.source_message_preview as string | undefined) ??
          'Da den gio nhac hen',
        creatorName: (metadata.creator_name as string | undefined) ?? 'Reminder',
        scope: firedReminder.scope,
      });
    }
  }

  private serializeReminder(
    reminder: MessageReminder,
  ): Record<string, unknown> {
    return {
      id: reminder.id,
      conv_id: reminder.conv_id,
      message_id: reminder.message_id,
      creator_user_id: reminder.creator_user_id,
      scope: reminder.scope,
      status: reminder.status,
      remind_at: reminder.remind_at.toISOString(),
      cancelled_at: reminder.cancelled_at?.toISOString() ?? null,
      fired_at: reminder.fired_at?.toISOString() ?? null,
      created_at: reminder.created_at.toISOString(),
      updated_at: reminder.updated_at.toISOString(),
    };
  }

  private async ensureReminderSourceMessage(
    convId: string,
    messageId: string,
    options: { allowDeleted?: boolean } = {},
  ): Promise<Message> {
    const { allowDeleted = true } = options;
    const sourceMessage = await this.ensureMessageBelongsToConversation(
      convId,
      messageId,
    );

    if (sourceMessage.type === 'system') {
      throw Object.assign(
        new Error('System messages cannot be used as reminder sources'),
        { code: 'INVALID_REMINDER_SOURCE' },
      );
    }

    if (!allowDeleted && sourceMessage.deleted_at) {
      throw Object.assign(
        new Error('Recalled messages cannot be used as reminder sources'),
        { code: 'INVALID_REMINDER_SOURCE' },
      );
    }

    return sourceMessage;
  }

  private normalizeReminderScope(scope: string): MessageReminderScope {
    if (scope === 'self' || scope === 'everyone') {
      return scope;
    }

    throw Object.assign(new Error('Invalid reminder scope'), {
      code: 'INVALID_REMINDER_SCOPE',
    });
  }

  private parseReminderDate(remindAt: string): Date {
    const parsedDate = new Date(remindAt);
    if (Number.isNaN(parsedDate.getTime())) {
      throw Object.assign(new Error('Invalid reminder time'), {
        code: 'INVALID_REMIND_AT',
      });
    }

    if (parsedDate.getTime() <= Date.now()) {
      throw Object.assign(new Error('Reminder time must be in the future'), {
        code: 'INVALID_REMIND_AT',
      });
    }

    return parsedDate;
  }

  private async ensureReminderDuplicateFree(params: {
    convId: string;
    messageId: string;
    creatorUserId: string;
    scope: MessageReminderScope;
    remindAt: Date;
    excludeReminderId?: string;
  }): Promise<void> {
    const query = this.messageReminderRepo
      .createQueryBuilder('reminder')
      .where('reminder.conv_id = :convId', { convId: params.convId })
      .andWhere('reminder.message_id = :messageId', {
        messageId: params.messageId,
      })
      .andWhere('reminder.scope = :scope', { scope: params.scope })
      .andWhere('reminder.remind_at = :remindAt', { remindAt: params.remindAt })
      .andWhere('reminder.status = :status', { status: 'pending' });

    if (params.scope === 'self') {
      query.andWhere('reminder.creator_user_id = :creatorUserId', {
        creatorUserId: params.creatorUserId,
      });
    }

    if (params.excludeReminderId) {
      query.andWhere('reminder.id != :excludeReminderId', {
        excludeReminderId: params.excludeReminderId,
      });
    }

    const duplicate = await query.getOne();
    if (duplicate) {
      throw Object.assign(
        new Error('A reminder already exists for the same time and audience'),
        { code: 'REMINDER_DUPLICATE' },
      );
    }
  }

  private async ensureEditableReminder(
    userId: string,
    convId: string,
    reminderId: string,
  ): Promise<MessageReminder> {
    await this.ensureConversationMembership(userId, convId);

    const reminder = await this.ensureReminderExists(reminderId, convId);
    if (reminder.creator_user_id !== userId) {
      throw Object.assign(new Error('Only the reminder creator can edit it'), {
        code: 'FORBIDDEN',
      });
    }

    if (reminder.status !== 'pending') {
      throw Object.assign(new Error('Reminder can no longer be modified'), {
        code: 'REMINDER_FINALIZED',
      });
    }

    return reminder;
  }

  private async ensureReminderExists(
    reminderId: string,
    convId: string,
  ): Promise<MessageReminder> {
    const reminder = await this.messageReminderRepo.findOne({
      where: { id: reminderId, conv_id: convId },
    });

    if (!reminder) {
      throw Object.assign(new Error('Reminder not found'), {
        code: 'NOT_FOUND',
      });
    }

    return reminder;
  }

  private async buildReminderMetadata(
    reminder: MessageReminder,
    sourceMessage: Message,
    kind: string,
  ): Promise<Record<string, unknown>> {
    const creator = await this.userRepo.findOne({
      where: { id: reminder.creator_user_id },
      select: ['name'],
    });

    return {
      kind,
      reminder_id: reminder.id,
      conv_id: reminder.conv_id,
      message_id: reminder.message_id,
      source_message_id: sourceMessage.id,
      source_message_preview: this.buildReminderSourceMessagePreview(
        sourceMessage,
      ),
      creator_user_id: reminder.creator_user_id,
      creator_name: creator?.name ?? 'Ai do',
      scope: reminder.scope,
      status: reminder.status,
      remind_at: reminder.remind_at.toISOString(),
      cancelled_at: reminder.cancelled_at?.toISOString() ?? null,
      fired_at: reminder.fired_at?.toISOString() ?? null,
    };
  }

  private buildReminderSourceMessagePreview(sourceMessage: Message): string {
    if (sourceMessage.deleted_at) {
      return 'Tin nhan da duoc thu hoi';
    }

    const trimmedContent = sourceMessage.content?.trim() ?? '';
    const previewText =
      trimmedContent.length > 120
        ? `${trimmedContent.slice(0, 117)}...`
        : trimmedContent;

    switch (sourceMessage.type) {
      case 'image':
        return previewText.length > 0 ? `Hinh anh: ${previewText}` : 'Hinh anh';
      case 'album':
        return previewText.length > 0 ? `Bo anh: ${previewText}` : 'Bo anh';
      case 'file':
        return previewText.length > 0 ? `Tap tin: ${previewText}` : 'Tap tin';
      case 'voice':
        return 'Tin nhan thoai';
      case 'video':
        return previewText.length > 0 ? `Video: ${previewText}` : 'Video';
      default:
        return previewText.length > 0 ? previewText : 'Tin nhan';
    }
  }

  private async scheduleReminderJob(reminder: MessageReminder): Promise<void> {
    await this.removeReminderJob(reminder.id);

    const delay = Math.max(reminder.remind_at.getTime() - Date.now(), 0);
    await this.reminderQueue.add(
      'fire-reminder',
      { reminderId: reminder.id },
      {
        jobId: reminder.id,
        delay,
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
        removeOnComplete: true,
        removeOnFail: 20,
      },
    );
  }

  private async removeReminderJob(reminderId: string): Promise<void> {
    const job = await this.reminderQueue.getJob(reminderId);
    if (!job) return;

    try {
      await job.remove();
    } catch (error: any) {
      this.logger.warn(
        `Failed to remove reminder job ${reminderId}: ${error?.message ?? error}`,
      );
    }
  }

  // --- Offline push ---

  private async enqueueOfflinePush(
    convId: string,
    senderId: string,
    message: Message,
  ): Promise<void> {
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
      if (this.connectionManager.isOnline(member.user_id)) continue;

      const isMentioned = isMentionAll || mentionedUserIds.has(member.user_id);
      if (member.is_muted && !isMentioned) continue;

      await this.notificationJob.enqueuePush(
        member.user_id,
        message,
        isMentioned,
        isMentionAll,
      );
    }
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
        await this.redisPubSub.publish(convId, { ...saved });

        // Enqueue push notifications for offline members
        await this.enqueueOfflinePush(convId, senderId, saved);

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

  async getConversations(userId: string, cursor?: string, limit = 20) {
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
        const lastMessage = await this.messageRepo.findOne({
          where: { conv_id: conv.id },
          order: { created_at: 'DESC' },
          select: [
            'id',
            'content',
            'type',
            'sender_id',
            'created_at',
            'deleted_at',
          ],
        });

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
    const plainMessages = await this.serializeMessages(ordered.map((m) => ({ ...m })));

    return {
      messages: plainMessages,
      nextCursor: hasMore ? ordered[0]?.created_at?.toISOString() : null,
      hasMore,
    };
  }

  // --- Read receipts ---

  async markRead(userId: string, data: Record<string, unknown>): Promise<void> {
    const convId = data.conv_id as string;
    const messageId = data.message_id as string;

    await this.memberRepo.update(
      { conv_id: convId, user_id: userId },
      { last_read_message_id: messageId, last_read_at: new Date() },
    );

    // Notify senders of unread messages that they've been read
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership) return;

    // Send message_read event to other members
    const members = await this.memberRepo.find({
      where: { conv_id: convId },
      select: ['user_id'],
    });

    const readEvent = JSON.stringify({
      event: 'message_read',
      data: { conv_id: convId, user_id: userId, message_id: messageId },
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
  ): Promise<PlainMessage[]> {
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
      .andWhere(
        '(m.created_at > :since OR m.edited_at > :since OR m.deleted_at > :since)',
        { since },
      )
      .orderBy('m.created_at', 'ASC')
      .take(100)
      .getMany();

    const plainMessages = await this.serializeMessages(
      messages.map((m) => ({ ...m })),
    );

    return plainMessages;
  }

  // --- Membership check ---

  async isMember(convId: string, userId: string): Promise<boolean> {
    const count = await this.memberRepo.count({
      where: { conv_id: convId, user_id: userId },
    });
    return count > 0;
  }

  // --- System messages ---

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
    await this.redisPubSub.publish(convId, { ...saved } as Record<
      string,
      unknown
    >);
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
      select: ['id'],
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

    // Subscribe online members
    const allIds = [userId, ...uniqueIds];
    for (const id of allIds) {
      if (this.connectionManager.isOnline(id)) {
        await this.redisPubSub.subscribeConversation(saved.id);
      }
    }

    // System message
    const actor = await this.userRepo.findOne({
      where: { id: userId },
      select: ['name'],
    });
    await this.insertSystemMessage(saved.id, userId, 'created_group', {
      actor_name: actor?.name ?? 'Unknown',
      group_name: name,
    });

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
    if (membership.role !== 'creator' && membership.role !== 'admin') {
      throw Object.assign(new Error('Only admin or creator can add members'), {
        code: 'FORBIDDEN',
      });
    }

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
      if (this.connectionManager.isOnline(user.id)) {
        await this.redisPubSub.subscribeConversation(convId);
      }
      await this.insertSystemMessage(convId, userId, 'added_member', {
        actor_name: actorName,
        member_name: user.name,
        member_id: user.id,
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

    if (targetMembership.role === 'creator') {
      throw Object.assign(new Error('Cannot remove the group creator'), {
        code: 'FORBIDDEN',
      });
    }

    const isSelfRemoval = actorId === targetUserId;
    if (!isSelfRemoval) {
      const actorMembership = await this.memberRepo.findOne({
        where: { conv_id: convId, user_id: actorId },
      });
      if (
        !actorMembership ||
        (actorMembership.role !== 'creator' && actorMembership.role !== 'admin')
      ) {
        throw Object.assign(
          new Error('Only admin or creator can remove members'),
          { code: 'FORBIDDEN' },
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

  private normalizeMessageForClient(message: PlainMessage): PlainMessage {
    const normalized = { ...message };
    if (normalized.deleted_at != null) {
      normalized.content = null;
    }
    return normalized;
  }

  private async serializeMessages(
    messages: PlainMessage[],
  ): Promise<PlainMessage[]> {
    if (messages.length === 0) return messages;
    await this.attachReactionsToMessages(messages);
    await this.attachReplyToData(messages);
    return messages.map((message) => this.normalizeMessageForClient(message));
  }

  private async serializeSingleMessage(message: Message): Promise<PlainMessage> {
    const [serialized] = await this.serializeMessages([{ ...message }]);
    return serialized;
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
      edited_at: Date | null;
      deleted_at: Date | null;
    }> = await this.messageRepo.query(
      `SELECT m.id, m.sender_id, m.content, m.type, m.edited_at, m.deleted_at,
              u.name AS sender_name
       FROM messages m
       LEFT JOIN users u ON u.id = m.sender_id
       WHERE m.id = ANY($1)`,
      [Array.from(replyToIds)],
    );

    const lookup = new Map<string, Record<string, unknown>>();
    for (const row of rows) {
      lookup.set(row.id, {
        id: row.id,
        sender_id: row.sender_id,
        sender_name: row.sender_name,
        content: row.deleted_at ? null : row.content,
        type: row.type,
        edited_at: row.edited_at,
        deleted_at: row.deleted_at,
      });
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
      edited_at: Date | null;
      deleted_at: Date | null;
    }> = await this.messageRepo.query(
      `SELECT m.id, m.sender_id, m.content, m.type, m.edited_at, m.deleted_at,
              u.name AS sender_name
       FROM messages m
       LEFT JOIN users u ON u.id = m.sender_id
       WHERE m.id = $1`,
      [messageId],
    );
    if (rows.length === 0) return null;
    const row = rows[0];
    return {
      id: row.id,
      sender_id: row.sender_id,
      sender_name: row.sender_name,
      content: row.deleted_at ? null : row.content,
      type: row.type,
      edited_at: row.edited_at,
      deleted_at: row.deleted_at,
    };
  }

  // --- Search ---

  async searchMessages(
    userId: string,
    query: string,
    convId?: string,
    cursor?: string,
    limit = 20,
  ) {
    // Get user's conversation IDs for membership check
    const memberships = await this.memberRepo.find({
      where: { user_id: userId },
      select: ['conv_id'],
    });
    if (memberships.length === 0) {
      return { results: [], next_cursor: null, has_more: false };
    }
    const memberConvIds = memberships.map((m) => m.conv_id);

    // If conv_id specified, verify membership
    if (convId && !memberConvIds.includes(convId)) {
      return { results: [], next_cursor: null, has_more: false };
    }

    const params: unknown[] = [query, userId];
    let paramIdx = 3;

    let sql = `
      SELECT m.id, m.conv_id, m.sender_id, m.type, m.content, m.created_at,
             ts_headline('simple', COALESCE(m.content, ''), plainto_tsquery('simple', $1),
                         'MaxWords=30, MinWords=15, StartSel=<mark>, StopSel=</mark>') as snippet,
             c.name as conv_name, c.type as conv_type, c.avatar_url as conv_avatar_url,
             u.name as sender_name
      FROM messages m
      INNER JOIN conversation_members cm ON cm.conv_id = m.conv_id AND cm.user_id = $2
      INNER JOIN conversations c ON c.id = m.conv_id
      INNER JOIN users u ON u.id = m.sender_id
      WHERE m.search_vector @@ plainto_tsquery('simple', $1)
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

    sql += ` ORDER BY m.created_at DESC, m.id DESC LIMIT $${paramIdx}`;
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

  // --- Pin / Unpin ---

  private async canPin(userId: string, convId: string): Promise<boolean> {
    const conv = await this.convRepo.findOne({ where: { id: convId } });
    if (!conv) return false;
    if (conv.type === 'DIRECT') return true;
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership) return false;
    return membership.role === 'creator' || membership.role === 'admin' || membership.role === 'employee';
  }

  async pinMessage(
    userId: string,
    convId: string,
    messageId: string,
  ): Promise<void> {
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership) {
      throw Object.assign(new Error('Not a member of this conversation'), {
        code: 'FORBIDDEN',
      });
    }

    if (!(await this.canPin(userId, convId))) {
      throw Object.assign(new Error('No permission to pin messages'), {
        code: 'FORBIDDEN',
      });
    }

    // Verify message belongs to conversation
    const message = await this.messageRepo.findOne({
      where: { id: messageId, conv_id: convId },
    });
    if (!message) {
      throw Object.assign(new Error('Message not found in this conversation'), {
        code: 'NOT_FOUND',
      });
    }

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
    if (pinCount >= 5) {
      throw Object.assign(
        new Error('Maximum 5 pinned messages per conversation'),
        { code: 'PIN_LIMIT' },
      );
    }

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
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership) {
      throw Object.assign(new Error('Not a member of this conversation'), {
        code: 'FORBIDDEN',
      });
    }

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
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership) {
      throw Object.assign(new Error('Not a member of this conversation'), {
        code: 'FORBIDDEN',
      });
    }

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
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: userId },
    });
    if (!membership) {
      throw Object.assign(new Error('Not a member of this conversation'), {
        code: 'FORBIDDEN',
      });
    }

    return this.getPinnedMessagesInternal(convId);
  }

  async bookmarkMessage(
    userId: string,
    convId: string,
    messageId: string,
  ): Promise<void> {
    await this.ensureConversationMembership(userId, convId);
    await this.ensureMessageBelongsToConversation(convId, messageId);

    const existing = await this.messageBookmarkRepo.findOne({
      where: { user_id: userId, conv_id: convId, message_id: messageId },
    });
    if (existing) {
      throw Object.assign(new Error('Message is already bookmarked'), {
        code: 'ALREADY_BOOKMARKED',
      });
    }

    await this.messageBookmarkRepo.save(
      this.messageBookmarkRepo.create({
        user_id: userId,
        conv_id: convId,
        message_id: messageId,
      }),
    );
  }

  async removeBookmark(
    userId: string,
    convId: string,
    messageId: string,
  ): Promise<void> {
    await this.ensureConversationMembership(userId, convId);

    const existing = await this.messageBookmarkRepo.findOne({
      where: { user_id: userId, conv_id: convId, message_id: messageId },
    });
    if (!existing) {
      throw Object.assign(new Error('Message bookmark not found'), {
        code: 'NOT_FOUND',
      });
    }

    await this.messageBookmarkRepo.delete({
      user_id: userId,
      conv_id: convId,
      message_id: messageId,
    });
  }

  async getBookmarkedMessages(
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
    await this.ensureConversationMembership(userId, convId);

    return this.messageBookmarkRepo.query(
      `SELECT b.user_id, b.conv_id, b.message_id, b.marked_at,
              m.content AS message_content, m.type AS message_type,
              m.sender_id, u.name AS sender_name, m.created_at AS message_created_at
       FROM message_bookmarks b
       JOIN messages m ON m.id = b.message_id
       JOIN users u ON u.id = m.sender_id
       WHERE b.user_id = $1 AND b.conv_id = $2
       ORDER BY b.marked_at DESC`,
      [userId, convId],
    );
  }

  async getGlobalBookmarkedMessages(
    userId: string,
    options?: {
      convType?: BookmarkConversationTypeFilterDto;
      cursor?: string;
      limit?: number;
    },
  ): Promise<{
    items: GlobalBookmarkedMessageRow[];
    next_cursor: string | null;
    has_more: boolean;
  }> {
    const convType = this.normalizeBookmarkConversationType(
      options?.convType,
    );
    const limit = options?.limit ?? 20;

    const params: unknown[] = [userId];
    let paramIdx = 2;

    let sql = `
      SELECT
        b.user_id,
        b.conv_id,
        b.message_id,
        b.marked_at,
        m.content AS message_content,
        m.type AS message_type,
        m.sender_id,
        sender.name AS sender_name,
        m.created_at AS message_created_at,
        c.type AS conversation_type,
        CASE
          WHEN c.type = 'DIRECT' THEN COALESCE(
            (
              SELECT direct_user.name
              FROM conversation_members direct_member
              INNER JOIN users direct_user
                ON direct_user.id = direct_member.user_id
              WHERE direct_member.conv_id = c.id
                AND direct_member.user_id <> $1
              ORDER BY direct_member.user_id
              LIMIT 1
            ),
            c.name
          )
          ELSE c.name
        END AS conversation_name,
        CASE
          WHEN c.type = 'DIRECT' THEN COALESCE(
            (
              SELECT direct_user.avatar_url
              FROM conversation_members direct_member
              INNER JOIN users direct_user
                ON direct_user.id = direct_member.user_id
              WHERE direct_member.conv_id = c.id
                AND direct_member.user_id <> $1
              ORDER BY direct_member.user_id
              LIMIT 1
            ),
            c.avatar_url
          )
          ELSE c.avatar_url
        END AS conversation_avatar_url
      FROM message_bookmarks b
      INNER JOIN conversation_members cm
        ON cm.conv_id = b.conv_id
       AND cm.user_id = $1
      INNER JOIN conversations c
        ON c.id = b.conv_id
      INNER JOIN messages m
        ON m.id = b.message_id
       AND m.conv_id = b.conv_id
      INNER JOIN users sender
        ON sender.id = m.sender_id
      WHERE b.user_id = $1
        AND m.deleted_at IS NULL
    `;

    if (convType) {
      sql += ` AND c.type = $${paramIdx}`;
      params.push(convType);
      paramIdx += 1;
    }

    if (options?.cursor) {
      const sepIdx = options.cursor.lastIndexOf('_');
      if (sepIdx > 0) {
        const cursorDate = options.cursor.substring(0, sepIdx);
        const cursorMessageId = options.cursor.substring(sepIdx + 1);
        sql += ` AND (b.marked_at, b.message_id) < ($${paramIdx}, $${paramIdx + 1})`;
        params.push(cursorDate, cursorMessageId);
        paramIdx += 2;
      }
    }

    sql += ` ORDER BY b.marked_at DESC, b.message_id DESC LIMIT $${paramIdx}`;
    params.push(limit + 1);

    const rows = (await this.messageBookmarkRepo.query(
      sql,
      params,
    )) as GlobalBookmarkedMessageRow[];

    const hasMore = rows.length > limit;
    if (hasMore) {
      rows.pop();
    }

    const lastRow = rows[rows.length - 1];
    const nextCursor =
      hasMore && lastRow
        ? `${(lastRow.marked_at as Date).toISOString()}_${lastRow.message_id}`
        : null;

    return {
      items: rows,
      next_cursor: nextCursor,
      has_more: hasMore,
    };
  }

  private async getPinnedMessagesInternal(convId: string) {
    const rows = await this.pinnedMessageRepo.query(
      `SELECT p.conv_id, p.message_id, p.pinned_by, p.pinned_at,
              m.content AS message_content, m.type AS message_type,
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

  private async ensureConversationMembership(
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

  private normalizeBookmarkConversationType(
    convType?: BookmarkConversationTypeFilterDto,
  ): 'DIRECT' | 'GROUP' | undefined {
    switch (convType) {
      case BookmarkConversationTypeFilterDto.DIRECT:
        return 'DIRECT';
      case BookmarkConversationTypeFilterDto.GROUP:
        return 'GROUP';
      default:
        return undefined;
    }
  }

  private async ensureMessageBelongsToConversation(
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
}
