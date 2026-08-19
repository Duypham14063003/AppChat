import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { Job } from 'bullmq';
import { CHAT_REMINDER_QUEUE } from '../chat.constants.js';
import { ChatService } from '../services/chat.service.js';
import { FirebaseService } from '../../notification/services/firebase.service.js';
import { UserSession } from '../../auth/entities/user-session.entity.js';

@Processor(CHAT_REMINDER_QUEUE)
export class ChatReminderProcessor extends WorkerHost {
  private readonly logger = new Logger(ChatReminderProcessor.name);

  constructor(
    private readonly chatService: ChatService,
    private readonly firebaseService: FirebaseService,
    @InjectRepository(UserSession)
    private readonly sessionRepo: Repository<UserSession>,
  ) {
    super();
  }

  async process(job: Job<{ reminderId?: string }>): Promise<void> {
    const reminderId = job.data?.reminderId;
    if (!reminderId) {
      this.logger.warn('Reminder job missing reminderId');
      return;
    }

    const fired = await this.chatService.fireReminder(reminderId);
    if (!fired) {
      this.logger.log(`Reminder ${reminderId} already processed or missing`);
      return;
    }

    if (!this.firebaseService.isEnabled()) return;

    for (const recipientUserId of fired.recipientUserIds) {
      const sessions = await this.sessionRepo.find({
        where: { user_id: recipientUserId },
        select: ['id', 'fcm_token'],
      });

      for (const session of sessions) {
        if (!session.fcm_token) continue;

        try {
          const sent = await this.firebaseService.sendPush(
            session.fcm_token,
            fired.pushTitle,
            fired.pushBody,
            fired.pushData,
          );

          if (!sent) {
            await this.sessionRepo.update(session.id, { fcm_token: null });
          }
        } catch (err: any) {
          this.logger.error(
            `Failed to send reminder push to session ${session.id}: ${err.message}`,
          );
        }
      }
    }
  }
}
