import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Queue } from 'bullmq';
import { Poc } from '../entities/poc.entity.js';
import { POC_QUEUE, type PocNotificationKind } from '../poc.constants.js';

@Injectable()
export class PocJobService {
  private readonly logger = new Logger(PocJobService.name);

  constructor(
    @InjectQueue(POC_QUEUE) private readonly queue: Queue,
    private readonly config: ConfigService,
  ) {}

  async reconcile(poc: Poc): Promise<void> {
    await this.removePocJobs(poc.id);
    if (!['assigned', 'in_progress'].includes(poc.status)) return;
    const now = Date.now();
    for (const offset of this.reminderOffsets()) {
      const scheduledAt = new Date(poc.demo_at.getTime() - offset * 60000);
      if (scheduledAt.getTime() <= now) continue;
      const kind = offset === 1440 ? 'demo_24h' : 'demo_30m';
      await this.addNotification(poc.id, kind, scheduledAt);
    }
    if (poc.demo_at.getTime() > now) {
      await this.addNotification(poc.id, 'deadline', poc.demo_at);
    }
  }

  async removePocJobs(pocId: string): Promise<void> {
    for (const kind of ['demo_24h', 'demo_30m', 'deadline'] as const) {
      const job = await this.queue.getJob(this.jobId(pocId, kind));
      if (!job) continue;
      try {
        await job.remove();
      } catch (error) {
        this.logger.warn(
          `Could not remove PoC job ${job.id}: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    }
  }

  async enqueueWeeklyRefresh(delay = 5000): Promise<void> {
    await this.queue.add(
      'refresh-weekly-report',
      {},
      {
        jobId: 'poc-weekly-refresh',
        delay,
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
      },
    );
  }

  private async addNotification(
    pocId: string,
    kind: PocNotificationKind,
    scheduledAt: Date,
  ) {
    await this.queue.add(
      'poc-notification',
      { pocId, kind, scheduledAt: scheduledAt.toISOString() },
      {
        jobId: this.jobId(pocId, kind),
        delay: Math.max(scheduledAt.getTime() - Date.now(), 0),
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
      },
    );
  }

  private reminderOffsets(): number[] {
    return this.config
      .get<string>('POC_REMINDER_OFFSETS_MINUTES', '1440,30')
      .split(',')
      .map((value: string) => Number(value.trim()))
      .filter((value: number) => Number.isFinite(value) && value > 0);
  }

  private jobId(pocId: string, kind: PocNotificationKind): string {
    return `poc:${pocId}:${kind}`;
  }
}
