import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { ChatService } from '../../chat/services/chat.service.js';
import { Conversation } from '../../chat/entities/conversation.entity.js';
import { ConversationMember } from '../../chat/entities/conversation-member.entity.js';
import { Poc } from '../entities/poc.entity.js';
import { PocWeeklyReport } from '../entities/poc-weekly-report.entity.js';
import { PocCalendarService } from './poc-calendar.service.js';
import { PocCapacityService } from './poc-capacity.service.js';
import { PocSystemBotService } from './poc-system-bot.service.js';

@Injectable()
export class PocWeeklyReportService {
  private readonly logger = new Logger(PocWeeklyReportService.name);

  constructor(
    @InjectRepository(Poc) private readonly pocRepo: Repository<Poc>,
    @InjectRepository(PocWeeklyReport)
    private readonly reportRepo: Repository<PocWeeklyReport>,
    private readonly capacity: PocCapacityService,
    private readonly calendar: PocCalendarService,
    private readonly chat: ChatService,
    private readonly config: ConfigService,
    private readonly dataSource: DataSource,
    private readonly systemBot: PocSystemBotService,
  ) {}

  async view(week: string) {
    const snapshot = await this.buildSnapshot(week);
    const report = await this.reportRepo.findOne({
      where: { iso_year: snapshot.iso_year, iso_week: snapshot.iso_week },
    });
    return { ...snapshot, publication: report ?? null };
  }

  async publish(week: string) {
    const snapshot = await this.buildSnapshot(week);
    const conversationId = this.config.get<string>(
      'POC_REPORT_CONVERSATION_ID',
      '35353995-517b-4fcb-b4d7-e0f23c5f4042',
    );
    const botId = await this.systemBot.ensure();
    await this.ensureConversation(conversationId, botId);
    let report = await this.reportRepo.findOne({
      where: { iso_year: snapshot.iso_year, iso_week: snapshot.iso_week },
    });
    if (!report) {
      report = await this.reportRepo.save(
        this.reportRepo.create({
          iso_year: snapshot.iso_year,
          iso_week: snapshot.iso_week,
          conversation_id: conversationId,
          chat_message_id: null,
          status: 'draft',
          snapshot,
          published_at: null,
        }),
      );
    }
    const metadata = {
      schema_version: 1,
      kind: 'poc_weekly_summary',
      ...snapshot,
      deep_link: `/pocs/week?week=${snapshot.week_start}`,
    };
    try {
      if (report.chat_message_id) {
        await this.chat.updateBusinessSystemMessage(
          report.chat_message_id,
          'poc_weekly_summary',
          metadata,
        );
      } else {
        const message = await this.chat.createBusinessSystemMessage(
          conversationId,
          botId,
          'poc_weekly_summary',
          metadata,
        );
        report.chat_message_id = message.id;
      }
      report.status = 'published';
      report.snapshot = snapshot;
      report.published_at = report.published_at ?? new Date();
      return await this.reportRepo.save(report);
    } catch (error) {
      report.status = 'failed';
      report.snapshot = snapshot;
      await this.reportRepo.save(report);
      throw error;
    }
  }

  async refreshCurrentPublished(): Promise<void> {
    const current = this.calendar.weekWindow(new Date());
    const report = await this.reportRepo.findOne({
      where: { iso_year: current.isoYear, iso_week: current.isoWeek },
    });
    if (!report?.chat_message_id) return;
    await this.publish(current.start.toISOString());
  }

  async buildSnapshot(week: string) {
    const window = this.calendar.weekWindow(week);
    const pocs = await this.pocRepo
      .createQueryBuilder('poc')
      .leftJoinAndSelect('poc.sale_user', 'sale')
      .leftJoinAndSelect('poc.developer_user', 'developer')
      .where('poc.demo_at >= :start AND poc.demo_at < :end', {
        start: window.start,
        end: window.end,
      })
      .orderBy('poc.demo_at', 'ASC')
      .getMany();
    const capacity = await this.capacity.getWeek(week);
    const now = new Date();
    const counts: Record<string, number> = {};
    for (const poc of pocs) counts[poc.status] = (counts[poc.status] ?? 0) + 1;
    return {
      iso_year: window.isoYear,
      iso_week: window.isoWeek,
      week_start: window.dates[0],
      week_end: window.dates[6],
      generated_at: now.toISOString(),
      total: pocs.length,
      counts,
      overdue: pocs
        .filter(
          (poc) =>
            poc.demo_at < now &&
            !['ready', 'demonstrated', 'cancelled'].includes(poc.status),
        )
        .map((poc) => this.summaryPoc(poc)),
      demos: pocs.map((poc) => this.summaryPoc(poc)),
      capacity: capacity.developers.map((developer) => ({
        user_id: developer.user_id,
        name: developer.name,
        allocated_hours: developer.allocated_hours,
        capacity_hours: developer.capacity_hours,
        over_capacity: developer.over_capacity,
        excess_hours: developer.excess_hours,
      })),
    };
  }

  private summaryPoc(poc: Poc) {
    return {
      id: poc.id,
      code: poc.code,
      title: poc.title,
      customer_name: poc.customer_name,
      sale_name: poc.sale_user?.name ?? null,
      developer_name: poc.developer_user?.name ?? null,
      demo_at: poc.demo_at.toISOString(),
      status: poc.status,
      deep_link: `/pocs/${poc.id}`,
    };
  }

  private async ensureConversation(
    conversationId: string,
    botId: string,
  ): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      const convRepo = manager.getRepository(Conversation);
      if (!(await convRepo.findOne({ where: { id: conversationId } }))) {
        await convRepo.save(
          convRepo.create({
            id: conversationId,
            type: 'GROUP',
            name: 'Báo cáo hàng ngày',
            created_by: botId,
            last_message_at: null,
          }),
        );
      }
      const memberRepo = manager.getRepository(ConversationMember);
      if (
        !(await memberRepo.findOne({
          where: { conv_id: conversationId, user_id: botId },
        }))
      ) {
        await memberRepo.save(
          memberRepo.create({
            conv_id: conversationId,
            user_id: botId,
            role: 'admin',
            last_read_message_id: null,
            last_read_at: null,
            is_muted: false,
          }),
        );
      }
    });
    this.logger.log(`PoC weekly report target ready: ${conversationId}`);
  }
}
