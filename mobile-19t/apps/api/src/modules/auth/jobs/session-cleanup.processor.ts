import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { SessionService } from '../services/session.service.js';

export const SESSION_CLEANUP_QUEUE = 'session-cleanup';

@Processor(SESSION_CLEANUP_QUEUE)
export class SessionCleanupProcessor extends WorkerHost {
  private readonly logger = new Logger(SessionCleanupProcessor.name);

  constructor(private readonly sessionService: SessionService) {
    super();
  }

  async process(): Promise<void> {
    const deleted = await this.sessionService.deleteExpiredSessions();
    this.logger.log(`Cleaned up ${deleted} expired sessions`);
  }
}
