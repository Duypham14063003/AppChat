import { Injectable, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { CHAT_PUSH_QUEUE } from '../chat.constants.js';
import { Message } from '../entities/message.entity.js';

export type ChatPushConversationContext = {
  id: string;
  type: string;
  name: string | null;
};

export type GroupMembershipNotificationContext = {
  id: string;
  type: string;
  name: string | null;
};

@Injectable()
export class NotificationJobService {
  private readonly logger = new Logger(NotificationJobService.name);

  constructor(
    @InjectQueue(CHAT_PUSH_QUEUE) private readonly pushQueue: Queue,
  ) {}

  async enqueuePush(
    recipientUserId: string,
    message: Message,
    isMentioned = false,
    isMentionAll = false,
    conversation?: ChatPushConversationContext,
  ): Promise<void> {
    try {
      await this.pushQueue.add(
        'send-push',
        {
          notificationKind: 'chat_message',
          recipientUserId,
          messageId: message.id,
          convId: message.conv_id,
          senderId: message.sender_id,
          content: message.content?.substring(0, 100),
          type: message.type,
          isMentioned,
          isMentionAll,
          conversationType: conversation?.type ?? 'DIRECT',
          conversationName: conversation?.name ?? null,
        },
        {
          attempts: 3,
          backoff: { type: 'exponential', delay: 2000 },
        },
      );
    } catch (err: any) {
      this.logger.error(
        `Failed to enqueue push for user ${recipientUserId}: ${err.message}`,
      );
    }
  }

  async enqueueGroupMembershipAdded(
    recipientUserId: string,
    actorId: string,
    actorName: string,
    conversation: GroupMembershipNotificationContext,
  ): Promise<void> {
    try {
      await this.pushQueue.add(
        'send-push',
        {
          notificationKind: 'group_membership_added',
          recipientUserId,
          convId: conversation.id,
          actorId,
          actorName,
          conversationType: conversation.type,
          conversationName: conversation.name,
        },
        {
          attempts: 3,
          backoff: { type: 'exponential', delay: 2000 },
        },
      );
    } catch (err: any) {
      this.logger.error(
        `Failed to enqueue group membership push for user ${recipientUserId}: ${err.message}`,
      );
    }
  }
}
