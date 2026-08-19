import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { Job } from 'bullmq';
import { UserSession } from '../../auth/entities/user-session.entity.js';
import { User } from '../../auth/entities/user.entity.js';
import { ConversationMember } from '../../chat/entities/conversation-member.entity.js';
import { Message } from '../../chat/entities/message.entity.js';
import { CHAT_PUSH_QUEUE } from '../../chat/chat.constants.js';
import { FirebaseService } from './firebase.service.js';

@Processor(CHAT_PUSH_QUEUE)
export class PushNotificationProcessor extends WorkerHost {
  private readonly logger = new Logger(PushNotificationProcessor.name);

  constructor(
    private readonly firebaseService: FirebaseService,
    @InjectRepository(UserSession)
    private readonly sessionRepo: Repository<UserSession>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(ConversationMember)
    private readonly memberRepo: Repository<ConversationMember>,
    @InjectRepository(Message)
    private readonly messageRepo: Repository<Message>,
  ) {
    super();
  }

  async process(job: Job): Promise<void> {
    if (!this.firebaseService.isEnabled()) return;

    const notificationKind =
      typeof job.data.notificationKind === 'string'
        ? job.data.notificationKind
        : 'chat_message';

    if (notificationKind === 'group_membership_added') {
      await this.processGroupMembershipAdded(job);
      return;
    }

    const {
      recipientUserId,
      senderId,
      convId,
      content,
      type,
      isMentioned,
      isMentionAll,
      conversationType,
      conversationName,
    } = job.data;

    // Multi-device sync can still fan out websocket events to the sender's
    // other live sessions, but push notifications should never alert the sender.
    if (
      typeof recipientUserId === 'string' &&
      typeof senderId === 'string' &&
      recipientUserId === senderId
    ) {
      return;
    }

    // Check mute — mentions override mute
    const membership = await this.memberRepo.findOne({
      where: { conv_id: convId, user_id: recipientUserId },
    });
    if (membership?.is_muted && !isMentioned) return;

    // Get sender name
    const sender = await this.userRepo.findOne({
      where: { id: senderId },
      select: ['name'],
    });

    // Get recipient's active sessions with FCM tokens
    const sessions = await this.sessionRepo.find({
      where: { user_id: recipientUserId },
      select: ['id', 'fcm_token'],
    });

    const senderName = sender?.name || 'New message';
    const normalizedConversationType =
      typeof conversationType === 'string' ? conversationType : 'DIRECT';
    const normalizedConversationName =
      typeof conversationName === 'string' && conversationName.trim()
        ? conversationName.trim()
        : 'Group chat';
    const isGroupConversation = normalizedConversationType === 'GROUP';
    const title = isGroupConversation ? normalizedConversationName : senderName;
    const messagePreview =
      type === 'text'
        ? typeof content === 'string' && content.trim()
          ? content.trim()
          : 'Bạn có tin nhắn mới'
        : `Sent a ${type}`;
    const body = this.buildNotificationBody({
      senderName,
      messagePreview,
      isGroupConversation,
      isMentioned: Boolean(isMentioned),
      isMentionAll: Boolean(isMentionAll),
    });
    const badgeCount = await this.getTotalUnreadCount(recipientUserId);

    for (const session of sessions) {
      if (!session.fcm_token) continue;

      const data: Record<string, string> = {
        conv_id: convId,
        message_id: job.data.messageId,
        type: 'chat_message',
        conv_type: normalizedConversationType,
      };
      if (isGroupConversation) {
        data.conv_name = normalizedConversationName;
      }
      if (isMentioned) {
        data.is_mention = 'true';
      }

      try {
        const result = await this.firebaseService.sendPush(
          session.fcm_token,
          title,
          body,
          data,
          badgeCount,
        );

        // Remove invalid token
        if (!result.success && result.shouldRemoveToken) {
          await this.sessionRepo.update(session.id, { fcm_token: null });
          this.logger.log(`Removed invalid FCM token for session ${session.id}`);
        }
      } catch (err: any) {
        this.logger.error(
          `Failed to send push notification to session ${session.id}: ${err.message}`,
        );
      }
    }
  }

  private async processGroupMembershipAdded(job: Job): Promise<void> {
    const {
      recipientUserId,
      convId,
      actorId,
      actorName,
      conversationType,
      conversationName,
    } = job.data;

    const sessions = await this.sessionRepo.find({
      where: { user_id: recipientUserId },
      select: ['id', 'fcm_token'],
    });

    const resolvedActorName =
      typeof actorName === 'string' && actorName.trim()
        ? actorName.trim()
        : await this.resolveActorName(actorId);
    const normalizedConversationType =
      typeof conversationType === 'string' ? conversationType : 'GROUP';
    const normalizedConversationName =
      typeof conversationName === 'string' && conversationName.trim()
        ? conversationName.trim()
        : 'Group chat';
    const badgeCount = await this.getTotalUnreadCount(recipientUserId);

    for (const session of sessions) {
      if (!session.fcm_token) continue;

      const data: Record<string, string> = {
        conv_id: convId,
        type: 'group_membership_added',
        conv_type: normalizedConversationType,
        conv_name: normalizedConversationName,
      };
      if (typeof actorId === 'string' && actorId) {
        data.actor_id = actorId;
      }
      if (resolvedActorName) {
        data.actor_name = resolvedActorName;
      }

      try {
        const result = await this.firebaseService.sendPush(
          session.fcm_token,
          normalizedConversationName,
          `${resolvedActorName} đã thêm bạn vào nhóm`,
          data,
          badgeCount,
        );

        if (!result.success && result.shouldRemoveToken) {
          await this.sessionRepo.update(session.id, { fcm_token: null });
          this.logger.log(`Removed invalid FCM token for session ${session.id}`);
        }
      } catch (err: any) {
        this.logger.error(
          `Failed to send group membership push to session ${session.id}: ${err.message}`,
        );
      }
    }
  }

  private async resolveActorName(actorId: unknown): Promise<string> {
    if (typeof actorId !== 'string' || !actorId) {
      return 'Someone';
    }

    const actor = await this.userRepo.findOne({
      where: { id: actorId },
      select: ['name'],
    });

    return actor?.name?.trim() || 'Someone';
  }

  private buildNotificationBody(params: {
    senderName: string;
    messagePreview: string;
    isGroupConversation: boolean;
    isMentioned: boolean;
    isMentionAll: boolean;
  }): string {
    const {
      senderName,
      messagePreview,
      isGroupConversation,
      isMentioned,
      isMentionAll,
    } = params;

    if (!isGroupConversation) {
      return messagePreview;
    }

    if (isMentionAll) {
      return `${senderName} đã nhắc đến mọi người: ${messagePreview}`;
    }

    if (isMentioned) {
      return `${senderName} đã nhắc đến bạn: ${messagePreview}`;
    }

    return `${senderName}: ${messagePreview}`;
  }

  private async getTotalUnreadCount(userId: string): Promise<number> {
    const rows: Array<{ cnt: string }> = await this.messageRepo.query(
      `SELECT COUNT(*) AS cnt
       FROM conversation_members cm
       JOIN messages m ON m.conv_id = cm.conv_id
       WHERE cm.user_id = $1
         AND m.deleted_at IS NULL
         AND m.sender_id != $1
         AND (cm.last_read_at IS NULL OR m.created_at > cm.last_read_at)`,
      [userId],
    );

    return parseInt(rows[0]?.cnt ?? '0', 10);
  }
}
