import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import type { Job } from 'bullmq';
import { Repository } from 'typeorm';
import { PocNotificationEvent } from '../entities/poc-notification-event.entity.js';
import { POC_QUEUE, type PocNotificationKind } from '../poc.constants.js';
import { PocChatService } from '../services/poc-chat.service.js';
import { PocPushService } from '../services/poc-push.service.js';
import { PocService } from '../services/poc.service.js';
import { PocSystemBotService } from '../services/poc-system-bot.service.js';
import { PocWeeklyReportService } from '../services/poc-weekly-report.service.js';

@Processor(POC_QUEUE)
export class PocProcessor extends WorkerHost {
  private readonly logger = new Logger(PocProcessor.name);

  constructor(
    private readonly pocs: PocService,
    private readonly chat: PocChatService,
    private readonly push: PocPushService,
    private readonly systemBot: PocSystemBotService,
    private readonly weekly: PocWeeklyReportService,
    @InjectRepository(PocNotificationEvent)
    private readonly eventRepo: Repository<PocNotificationEvent>,
  ) {
    super();
  }

  async process(job: Job): Promise<void> {
    if (job.name === 'refresh-weekly-report') {
      await this.weekly.refreshCurrentPublished();
      return;
    }
    if (job.name === 'publish-weekly-report') {
      await this.weekly.publish(new Date().toISOString());
      return;
    }
    if (job.name !== 'poc-notification') return;
    await this.deliverNotification(
      job.data as {
        pocId: string;
        kind: PocNotificationKind;
        scheduledAt: string;
      },
    );
  }

  private async deliverNotification(data: {
    pocId: string;
    kind: PocNotificationKind;
    scheduledAt: string;
  }) {
    const scheduledAt = new Date(data.scheduledAt);
    let event = await this.eventRepo.findOne({
      where: {
        poc_id: data.pocId,
        event_kind: data.kind,
        scheduled_at: scheduledAt,
      },
    });
    if (event?.status === 'delivered' || event?.status === 'skipped') return;
    if (!event) {
      event = await this.eventRepo.save(
        this.eventRepo.create({
          poc_id: data.pocId,
          event_kind: data.kind,
          scheduled_at: scheduledAt,
          status: 'processing',
          attempts: 1,
          delivered_at: null,
          last_error: null,
        }),
      );
    } else {
      event.status = 'processing';
      event.attempts += 1;
      event.last_error = null;
      await this.eventRepo.save(event);
    }
    const poc = await this.pocs.getForNotification(data.pocId);
    if (!poc || ['cancelled', 'demonstrated'].includes(poc.status)) {
      event.status = 'skipped';
      await this.eventRepo.save(event);
      return;
    }
    if (data.kind === 'deadline' && ['ready'].includes(poc.status)) {
      event.status = 'skipped';
      await this.eventRepo.save(event);
      return;
    }
    try {
      const kind =
        data.kind === 'deadline'
          ? 'poc_overdue'
          : data.kind === 'demo_24h'
            ? 'poc_demo_24h'
            : 'poc_demo_30m';
      const botId = await this.systemBot.ensure();
      await this.chat.project(poc, botId, kind, undefined, true);
      const title =
        data.kind === 'deadline'
          ? 'PoC đã đến hạn demo'
          : data.kind === 'demo_24h'
            ? 'Còn 24 giờ đến lịch demo'
            : 'Còn 30 phút đến lịch demo';
      await this.push.send(
        [poc.developer_user_id, poc.sale_user_id],
        title,
        poc.code ?? poc.title,
        {
          type: 'poc',
          poc_id: poc.id,
          deep_link: `/pocs/${poc.id}`,
        },
      );
      event.status = 'delivered';
      event.delivered_at = new Date();
      await this.eventRepo.save(event);
    } catch (error) {
      event.status = 'failed';
      event.last_error = error instanceof Error ? error.message : String(error);
      await this.eventRepo.save(event);
      throw error;
    }
  }
}
