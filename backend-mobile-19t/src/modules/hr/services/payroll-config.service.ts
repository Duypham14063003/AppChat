import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PayrollConfig } from '../entities/payroll-config.entity.js';
import { UpdatePayrollConfigDto } from '../dto/hr.dto.js';
import { AttendanceReminderScheduler } from '../jobs/attendance-reminder.scheduler.js';

@Injectable()
export class PayrollConfigService {
  constructor(
    @InjectRepository(PayrollConfig)
    private readonly configRepo: Repository<PayrollConfig>,
    private readonly reminderScheduler: AttendanceReminderScheduler,
  ) {}

  async getConfig(userId: string): Promise<PayrollConfig> {
    let config = await this.configRepo.findOne({
      where: { user_id: userId },
    });
    if (!config) {
      config = this.configRepo.create({ user_id: userId });
      config = await this.configRepo.save(config);
    }
    return config;
  }

  async getPayrollConfigStartDay(userId: string): Promise<number> {
    const config = await this.getConfig(userId);
    return config.payroll_start_day;
  }

  async updateConfig(
    userId: string,
    dto: UpdatePayrollConfigDto,
  ): Promise<PayrollConfig> {
    const config = await this.getConfig(userId);
    Object.assign(config, dto);
    config.updated_at = new Date();
    const saved = await this.configRepo.save(config);
    await this.reminderScheduler.reconcileUser(saved);
    return saved;
  }
}
