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

    if (job.name === 'send-reminder-push') {
      await this.processReminderPush(job);
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
    } = job.data;

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
    let title: string;
    if (isMentionAll) {
      title = `${senderName} đã nhắc đến mọi người`;
    } else if (isMentioned) {
      title = `${senderName} đã nhắc đến bạn`;
    } else {
      title = senderName;
    }
    const body = type === 'text' ? content || '' : `Sent a ${type}`;
    const badgeCount = await this._getUnreadBadgeCount(recipientUserId);

    for (const session of sessions) {
      if (!session.fcm_token) continue;

      const data: Record<string, string> = {
        conv_id: convId,
        message_id: job.data.messageId,
        type: 'chat_message',
        badge_count: `${badgeCount}`,
      };
      if (isMentioned) {
        data.is_mention = 'true';
      }

      const success = await this.firebaseService.sendPush(
        session.fcm_token,
        title,
        body,
        data,
        badgeCount,
      );

      // Remove invalid token
      if (!success) {
        await this.sessionRepo.update(session.id, { fcm_token: null });
      }
    }
  }

  private async processReminderPush(job: Job): Promise<void> {
    const {
      recipientUserId,
      convId,
      reminderId,
      sourceMessageId,
      sourceMessagePreview,
      creatorName,
      scope,
    } = job.data;

    const sessions = await this.sessionRepo.find({
      where: { user_id: recipientUserId },
      select: ['id', 'fcm_token'],
    });

    const title =
      scope === 'everyone'
        ? `${creatorName} đã nhắc hẹn trong cuộc trò chuyện`
        : 'Nhắc hẹn tin nhắn';
    const body = sourceMessagePreview || 'Đã đến giờ nhắc hẹn';
    const badgeCount = await this._getUnreadBadgeCount(recipientUserId);

    for (const session of sessions) {
      if (!session.fcm_token) continue;

      const success = await this.firebaseService.sendPush(
        session.fcm_token,
        title,
        body,
        {
          conv_id: convId,
          reminder_id: reminderId,
          message_id: sourceMessageId,
          type: 'chat_reminder',
          badge_count: `${badgeCount}`,
        },
        badgeCount,
      );

      if (!success) {
        await this.sessionRepo.update(session.id, { fcm_token: null });
      }
    }
  }

  private async _getUnreadBadgeCount(userId: string): Promise<number> {
    const rows: Array<{ cnt: string }> = await this.messageRepo.query(
      `SELECT COUNT(*) AS cnt
       FROM messages m
       INNER JOIN conversation_members cm ON cm.conv_id = m.conv_id
       WHERE cm.user_id = $1
         AND m.sender_id != $1
         AND m.deleted_at IS NULL
         AND (
           cm.last_read_at IS NULL
           OR m.created_at > cm.last_read_at
         )`,
      [userId],
    );

    return parseInt(rows[0]?.cnt ?? '0', 10);
  }
}
