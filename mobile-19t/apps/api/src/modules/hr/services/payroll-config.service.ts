import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PayrollConfig } from '../entities/payroll-config.entity.js';
import { UpdatePayrollConfigDto } from '../dto/hr.dto.js';

@Injectable()
export class PayrollConfigService {
  constructor(
    @InjectRepository(PayrollConfig)
    private readonly configRepo: Repository<PayrollConfig>,
  ) {}

  async getConfig(): Promise<Record<string, unknown>> {
    let config = await this.configRepo.findOne({ where: { id: 1 } });
    if (!config) {
      config = this.configRepo.create({ id: 1 });
      config = await this.configRepo.save(config);
    }
    return this.serializeConfig(config);
  }

  async updateConfig(dto: UpdatePayrollConfigDto): Promise<Record<string, unknown>> {
    let config = await this.configRepo.findOne({ where: { id: 1 } });
    if (!config) {
      config = this.configRepo.create({ id: 1 });
    }
    Object.assign(config, dto);
    config.updated_at = new Date();
    const saved = await this.configRepo.save(config);
    return this.serializeConfig(saved);
  }

  private serializeConfig(config: PayrollConfig): Record<string, unknown> {
    return {
      ...config,
      work_start_time: this.normalizeTime(config.work_start_time),
      checkin_reminder_time: this.normalizeTime(config.checkin_reminder_time),
      checkout_reminder_time: this.normalizeTime(config.checkout_reminder_time),
      auto_checkout_time: this.normalizeTime(config.auto_checkout_time),
    };
  }

  private normalizeTime(value: string | null): string | null {
    if (value == null || value.length === 0) return value;
    return value.split(':').slice(0, 2).join(':');
  }
}
