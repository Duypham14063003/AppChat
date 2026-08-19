import { Entity, PrimaryColumn, Column, UpdateDateColumn } from 'typeorm';

@Entity('payroll_config')
export class PayrollConfig {
  @PrimaryColumn({ type: 'int', default: 1 })
  id!: number;

  @Column({ type: 'int', default: 1 })
  payroll_start_day!: number;

  @Column({ type: 'decimal', precision: 4, scale: 2, default: 8.0 })
  standard_hours_per_day!: number;

  @Column({ type: 'int', default: 22 })
  standard_days_per_month!: number;

  @Column({ type: 'time', default: '08:00' })
  work_start_time!: string;

  @Column({ type: 'time', nullable: true })
  checkin_reminder_time!: string | null;

  @Column({ type: 'time', nullable: true })
  checkout_reminder_time!: string | null;

  @Column({ type: 'boolean', default: false })
  auto_checkout_enabled!: boolean;

  @Column({ type: 'time', default: '23:59' })
  auto_checkout_time!: string;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at!: Date;
}
