import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import type { Job } from 'bullmq';
import { ChatService } from './chat.service.js';
import { CHAT_REMINDER_QUEUE } from '../chat.constants.js';

@Processor(CHAT_REMINDER_QUEUE)
export class MessageReminderProcessor extends WorkerHost {
  private readonly logger = new Logger(MessageReminderProcessor.name);

  constructor(private readonly chatService: ChatService) {
    super();
  }

  async process(job: Job): Promise<void> {
    if (job.name !== 'fire-reminder') return;

    const reminderId = job.data?.reminderId as string | undefined;
    if (!reminderId) return;

    try {
      await this.chatService.fireMessageReminder(reminderId);
    } catch (error: any) {
      this.logger.error(
        `Failed to fire reminder ${reminderId}: ${error?.message ?? error}`,
      );
      throw error;
    }
  }
}
