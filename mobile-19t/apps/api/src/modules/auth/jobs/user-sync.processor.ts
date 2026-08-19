import { Processor, WorkerHost, InjectQueue } from '@nestjs/bullmq';
import { Logger, OnModuleInit } from '@nestjs/common';
import { Queue } from 'bullmq';
import { AuthService } from '../services/auth.service.js';

export const USER_SYNC_QUEUE = 'user-sync';

@Processor(USER_SYNC_QUEUE)
export class UserSyncProcessor extends WorkerHost implements OnModuleInit {
  private readonly logger = new Logger(UserSyncProcessor.name);

  constructor(
    private readonly authService: AuthService,
    @InjectQueue(USER_SYNC_QUEUE) private readonly queue: Queue,
  ) {
    super();
  }

  async onModuleInit(): Promise<void> {
    await this.queue.upsertJobScheduler(
      'user-sync-hourly',
      { every: 3_600_000 },
      { opts: { attempts: 3, backoff: { type: 'exponential', delay: 2000 } } },
    );
    this.logger.log('User sync scheduled: every 1 hour');
  }

  async process(): Promise<void> {
    try {
      const result = await this.authService.syncUsersFromOdoo();
      this.logger.log(
        `User sync: ${result.created} created, ${result.updated} updated, ${result.deactivated} deactivated`,
      );
    } catch (error) {
      this.logger.error(`User sync failed: ${error}`);
      throw error;
    }
  }
}
