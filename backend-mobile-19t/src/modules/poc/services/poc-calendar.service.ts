import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export type WeekWindow = {
  isoYear: number;
  isoWeek: number;
  start: Date;
  end: Date;
  dates: string[];
};

@Injectable()
export class PocCalendarService {
  readonly timezone: string;
  readonly dailyCapacity: number;
  readonly weeklyCapacity: number;

  constructor(config: ConfigService) {
    this.timezone = config.get('POC_TIMEZONE', 'Asia/Ho_Chi_Minh');
    this.dailyCapacity = config.get<number>('POC_DAILY_CAPACITY_HOURS', 8);
    this.weeklyCapacity = config.get<number>('POC_WEEKLY_CAPACITY_HOURS', 40);
  }

  localDate(value: Date): string {
    return new Intl.DateTimeFormat('en-CA', {
      timeZone: this.timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(value);
  }

  weekWindow(value: string | Date): WeekWindow {
    const local =
      typeof value === 'string' ? value.slice(0, 10) : this.localDate(value);
    const noon = new Date(`${local}T12:00:00+07:00`);
    const day = noon.getUTCDay() || 7;
    noon.setUTCDate(noon.getUTCDate() - day + 1);
    const monday = this.localDate(noon);
    const start = new Date(`${monday}T00:00:00+07:00`);
    const end = new Date(start.getTime() + 7 * 86400000);
    const dates = Array.from({ length: 7 }, (_, index) =>
      this.localDate(new Date(start.getTime() + index * 86400000)),
    );
    const thursday = new Date(start.getTime() + 3 * 86400000);
    const isoYear = Number(this.localDate(thursday).slice(0, 4));
    const yearStart = new Date(`${isoYear}-01-01T00:00:00+07:00`);
    const isoWeek = Math.ceil(
      ((thursday.getTime() - yearStart.getTime()) / 86400000 +
        (yearStart.getUTCDay() || 7)) /
        7,
    );
    return { isoYear, isoWeek, start, end, dates };
  }

  workdayWindows(
    start: Date,
    end: Date,
  ): Array<{ date: string; start: Date; end: Date }> {
    if (end <= start) return [];
    const firstDate = this.localDate(start);
    const lastDate = this.localDate(new Date(end.getTime() - 1));
    const cursor = new Date(`${firstDate}T00:00:00+07:00`);
    const last = new Date(`${lastDate}T00:00:00+07:00`);
    const result: Array<{ date: string; start: Date; end: Date }> = [];
    while (cursor <= last) {
      const date = this.localDate(cursor);
      const day = new Date(`${date}T12:00:00+07:00`).getUTCDay();
      if (day >= 1 && day <= 5) {
        const dayStart = new Date(`${date}T08:00:00+07:00`);
        const dayEnd = new Date(`${date}T17:00:00+07:00`);
        const clippedStart = new Date(
          Math.max(start.getTime(), dayStart.getTime()),
        );
        const clippedEnd = new Date(Math.min(end.getTime(), dayEnd.getTime()));
        if (clippedEnd > clippedStart) {
          result.push({ date, start: clippedStart, end: clippedEnd });
        }
      }
      cursor.setUTCDate(cursor.getUTCDate() + 1);
    }
    return result;
  }

  allocate(
    start: Date,
    end: Date,
    estimatedHours: number,
  ): Record<string, number> {
    const windows = this.workdayWindows(start, end);
    if (!windows.length) return {};
    const weights = windows.map((window) =>
      Math.min(
        this.dailyCapacity,
        (window.end.getTime() - window.start.getTime()) / 3600000,
      ),
    );
    const totalWeight = weights.reduce((sum, value) => sum + value, 0);
    let allocated = 0;
    return Object.fromEntries(
      windows.map((window, index) => {
        const hours =
          index === windows.length - 1
            ? Number((estimatedHours - allocated).toFixed(2))
            : Number(
                ((estimatedHours * weights[index]) / totalWeight).toFixed(2),
              );
        allocated = Number((allocated + hours).toFixed(2));
        return [window.date, hours];
      }),
    );
  }
}
