import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Queue } from 'bullmq';
import { REWARDS_RESET_QUEUE } from './rewards-reset.processor.js';

@Injectable()
export class RewardsResetScheduler implements OnModuleInit {
  private readonly logger = new Logger(RewardsResetScheduler.name);
  private readonly timezone = 'Asia/Ho_Chi_Minh';
  // lấy ngày từ setting để linh hoạt hơn trong tương lai nếu muốn thay đổi ngày reset mà không cần deploy lại code
  private readonly resetDay = 25;
  constructor(
    @InjectQueue(REWARDS_RESET_QUEUE)
    private readonly resetQueue: Queue,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.scheduleMonthlyReset();
  }

  async scheduleMonthlyReset(): Promise<void> {
    const jobName = 'monthly-reset';
    const schedulerId = 'rewards:monthly-reset';

    // Cron for 00:00 on the 25th day of every month
    const cron = `0 0 ${this.resetDay} * *`;

    await this.resetQueue.upsertJobScheduler(
      schedulerId,
      {
        pattern: cron,
        tz: this.timezone,
      },
      {
        name: jobName,
        data: {},
        opts: {
          attempts: 3,
          backoff: { type: 'exponential', delay: 5000 },
        },
      },
    );

    this.logger.log(
      `Scheduled monthly rewards reset at: ${cron} (${this.timezone})`,
    );
  }
}
