import { Injectable, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { CHAT_REMINDER_QUEUE } from '../chat.constants.js';
import { MessageReminder } from '../entities/message-reminder.entity.js';

@Injectable()
export class ReminderJobService {
  private readonly logger = new Logger(ReminderJobService.name);

  constructor(
    @InjectQueue(CHAT_REMINDER_QUEUE) private readonly reminderQueue: Queue,
  ) {}

  async scheduleReminder(reminder: MessageReminder): Promise<void> {
    const delay = Math.max(reminder.remind_at.getTime() - Date.now(), 0);
    await this.removeReminder(reminder.id);

    await this.reminderQueue.add(
      'fire-reminder',
      { reminderId: reminder.id },
      {
        jobId: this.getJobId(reminder.id),
        delay,
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
      },
    );
  }

  async removeReminder(reminderId: string): Promise<void> {
    const existing = await this.reminderQueue.getJob(this.getJobId(reminderId));
    if (!existing) return;

    try {
      await existing.remove();
    } catch (err: any) {
      this.logger.warn(
        `Failed to remove reminder job ${reminderId}: ${err.message}`,
      );
    }
  }

  private getJobId(reminderId: string): string {
    return `chat-reminder-${reminderId}`;
  }
}
