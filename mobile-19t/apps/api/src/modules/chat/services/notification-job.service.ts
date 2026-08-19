import { Injectable, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { CHAT_PUSH_QUEUE } from '../chat.constants.js';
import { Message } from '../entities/message.entity.js';

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
  ): Promise<void> {
    try {
      await this.pushQueue.add(
        'send-push',
        {
          recipientUserId,
          messageId: message.id,
          convId: message.conv_id,
          senderId: message.sender_id,
          content: message.content?.substring(0, 100),
          type: message.type,
          isMentioned,
          isMentionAll,
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

  async enqueueReminderPush(params: {
    recipientUserId: string;
    convId: string;
    reminderId: string;
    sourceMessageId: string;
    sourceMessagePreview: string;
    creatorName: string;
    scope: 'self' | 'everyone';
  }): Promise<void> {
    try {
      await this.pushQueue.add(
        'send-reminder-push',
        params,
        {
          attempts: 3,
          backoff: { type: 'exponential', delay: 2000 },
        },
      );
    } catch (err: any) {
      this.logger.error(
        `Failed to enqueue reminder push for user ${params.recipientUserId}: ${err.message}`,
      );
    }
  }
}
