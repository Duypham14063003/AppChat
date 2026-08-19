import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Queue } from 'bullmq';
import { POC_QUEUE } from '../poc.constants.js';

@Injectable()
export class PocScheduler implements OnModuleInit {
  constructor(
    @InjectQueue(POC_QUEUE) private readonly queue: Queue,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit(): Promise<void> {
    const [hour = '12', minute = '0'] = this.config
      .get<string>('POC_REPORT_TIME', '12:00')
      .split(':');
    await this.queue.upsertJobScheduler(
      'poc:weekly-report',
      {
        pattern: `${Number(minute)} ${Number(hour)} * * 5`,
        tz: this.config.get<string>('POC_TIMEZONE', 'Asia/Ho_Chi_Minh'),
      },
      {
        name: 'publish-weekly-report',
        data: {},
        opts: {
          attempts: 3,
          backoff: { type: 'exponential', delay: 2000 },
        },
      },
    );
  }
}
