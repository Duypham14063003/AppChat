import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';
import { Poc } from '../entities/poc.entity.js';
import { PocCalendarService } from './poc-calendar.service.js';

const ACTIVE_CAPACITY_STATUSES = ['assigned', 'in_progress', 'ready'] as const;

@Injectable()
export class PocCapacityService {
  constructor(
    @InjectRepository(Poc) private readonly pocRepo: Repository<Poc>,
    @InjectRepository(User) private readonly userRepo: Repository<User>,
    private readonly calendar: PocCalendarService,
    private readonly config: ConfigService,
  ) {}

  async getWeek(week: string, excludePocId?: string) {
    const window = this.calendar.weekWindow(week);
    const qb = this.pocRepo
      .createQueryBuilder('poc')
      .leftJoinAndSelect('poc.developer_user', 'developer')
      .where('poc.developer_user_id IS NOT NULL')
      .andWhere('poc.status IN (:...statuses)', {
        statuses: [...ACTIVE_CAPACITY_STATUSES],
      })
      .andWhere('poc.planned_start_at < :end AND poc.demo_at > :start', {
        start: window.start,
        end: window.end,
      });
    if (excludePocId) qb.andWhere('poc.id != :excludePocId', { excludePocId });
    const pocs = await qb.getMany();
    const users = await this.userRepo.find({
      where: { is_active: true, is_bot: false },
      order: { name: 'ASC' },
    });
    return this.aggregate(window, users, pocs);
  }

  async preview(params: {
    week: string;
    plannedStartAt: Date;
    demoAt: Date;
    estimatedHours: number;
    excludePocId?: string;
  }) {
    const result = await this.getWeek(params.week, params.excludePocId);
    const projected = this.calendar.allocate(
      params.plannedStartAt,
      params.demoAt,
      params.estimatedHours,
    );
    return {
      ...result,
      developers: result.developers.map((developer) => {
        const added = Object.entries(projected)
          .filter(([date]) => result.dates.includes(date))
          .reduce((sum, [, hours]) => sum + hours, 0);
        const projectedHours = Number(
          (developer.allocated_hours + added).toFixed(2),
        );
        const projectedHasOverlap = developer.pocs.some((poc) => {
          if (!poc.planned_start_at) return false;
          const start = new Date(poc.planned_start_at);
          const end = new Date(poc.demo_at);
          return params.plannedStartAt < end && params.demoAt > start;
        });
        return {
          ...developer,
          projected_hours: projectedHours,
          projected_remaining_hours: Number(
            (this.calendar.weeklyCapacity - projectedHours).toFixed(2),
          ),
          projected_over_capacity:
            projectedHours > this.calendar.weeklyCapacity,
          projected_has_overlap: projectedHasOverlap,
        };
      }),
    };
  }

  private aggregate(
    window: ReturnType<PocCalendarService['weekWindow']>,
    users: User[],
    pocs: Poc[],
  ) {
    const byDeveloper = new Map<string, Poc[]>();
    for (const poc of pocs) {
      const list = byDeveloper.get(poc.developer_user_id!) ?? [];
      list.push(poc);
      byDeveloper.set(poc.developer_user_id!, list);
    }
    const developers = users.map((user) => {
      const assigned = byDeveloper.get(user.id) ?? [];
      const daily: Record<string, number> = Object.fromEntries(
        window.dates.slice(0, 5).map((date) => [date, 0]),
      );
      const spans = assigned.map((poc) => {
        const allocation = this.calendar.allocate(
          poc.planned_start_at!,
          poc.demo_at,
          Number(poc.estimated_hours),
        );
        for (const [date, hours] of Object.entries(allocation)) {
          if (date in daily)
            daily[date] = Number((daily[date] + hours).toFixed(2));
        }
        return {
          id: poc.id,
          code: poc.code,
          title: poc.title,
          planned_start_at: poc.planned_start_at,
          demo_at: poc.demo_at,
          estimated_hours: Number(poc.estimated_hours),
        };
      });
      const overlaps: Array<{
        first_poc_id: string;
        second_poc_id: string;
        start: Date;
        end: Date;
      }> = [];
      for (let i = 0; i < assigned.length; i++) {
        for (let j = i + 1; j < assigned.length; j++) {
          const start = new Date(
            Math.max(
              assigned[i].planned_start_at!.getTime(),
              assigned[j].planned_start_at!.getTime(),
            ),
          );
          const end = new Date(
            Math.min(
              assigned[i].demo_at.getTime(),
              assigned[j].demo_at.getTime(),
            ),
          );
          if (end > start) {
            overlaps.push({
              first_poc_id: assigned[i].id,
              second_poc_id: assigned[j].id,
              start,
              end,
            });
          }
        }
      }
      const allocated = Number(
        Object.values(daily)
          .reduce((sum, value) => sum + value, 0)
          .toFixed(2),
      );
      return {
        user_id: user.id,
        name: user.name,
        avatar_url: user.avatar_url,
        department: user.department,
        job_title: user.job_title,
        allocated_hours: allocated,
        capacity_hours: this.calendar.weeklyCapacity,
        remaining_hours: Number(
          (this.calendar.weeklyCapacity - allocated).toFixed(2),
        ),
        excess_hours: Number(
          Math.max(0, allocated - this.calendar.weeklyCapacity).toFixed(2),
        ),
        over_capacity: allocated > this.calendar.weeklyCapacity,
        has_overlap: overlaps.length > 0,
        daily_load: daily,
        pocs: spans,
        overlaps,
      };
    });
    return {
      iso_year: window.isoYear,
      iso_week: window.isoWeek,
      timezone: this.config.get<string>('POC_TIMEZONE', 'Asia/Ho_Chi_Minh'),
      dates: window.dates,
      developers,
    };
  }
}
