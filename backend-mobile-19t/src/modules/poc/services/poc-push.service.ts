import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserSession } from '../../auth/entities/user-session.entity.js';
import { FirebaseService } from '../../notification/services/firebase.service.js';

@Injectable()
export class PocPushService {
  private readonly logger = new Logger(PocPushService.name);

  constructor(
    private readonly firebase: FirebaseService,
    @InjectRepository(UserSession)
    private readonly sessionRepo: Repository<UserSession>,
  ) {}

  async send(
    userIds: Array<string | null | undefined>,
    title: string,
    body: string,
    data: Record<string, string>,
  ): Promise<void> {
    if (!this.firebase.isEnabled()) return;
    for (const userId of [...new Set(userIds.filter(Boolean))] as string[]) {
      const sessions = await this.sessionRepo.find({
        where: { user_id: userId },
        select: ['id', 'fcm_token'],
      });
      for (const session of sessions) {
        if (!session.fcm_token) continue;
        try {
          const result = await this.firebase.sendPush(
            session.fcm_token,
            title,
            body,
            data,
          );
          if (!result.success && result.shouldRemoveToken) {
            await this.sessionRepo.update(session.id, { fcm_token: null });
          }
        } catch (error) {
          this.logger.error(
            `PoC push failed for session ${session.id}: ${error instanceof Error ? error.message : String(error)}`,
          );
          throw error;
        }
      }
    }
  }
}
