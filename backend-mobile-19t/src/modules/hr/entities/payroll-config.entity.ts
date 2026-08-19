import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';

@Entity('payroll_config')
export class PayrollConfig {
  @PrimaryGeneratedColumn('increment', { type: 'int' })
  id!: number;

  @Index({ unique: true })
  @Column('uuid')
  user_id!: string;

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

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;
}
