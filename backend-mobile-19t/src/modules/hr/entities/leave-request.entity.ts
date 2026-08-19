import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';
import { LeaveRequestDay } from './leave-request-day.entity.js';

@Entity('leave_requests')
@Index('IDX_leave_requests_user_created', ['user_id', 'created_at'])
export class LeaveRequest {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid')
  user_id!: string;

  @Column({ type: 'varchar', length: 30 })
  type!: string; // annual | sick | personal

  @Column({ type: 'date' })
  start_date!: string;

  @Column({ type: 'date' })
  end_date!: string;

  @Column({ type: 'time', nullable: true })
  start_time!: string | null;

  @Column({ type: 'time', nullable: true })
  end_time!: string | null;

  @Column({ type: 'boolean', default: false })
  is_half_day!: boolean;

  @Column({ type: 'varchar', length: 20, nullable: true })
  half_day_part!: string | null;

  @Column({ type: 'decimal', precision: 4, scale: 1, default: 0 })
  requested_days!: number;

  @Column({ type: 'decimal', precision: 4, scale: 1, default: 0 })
  paid_days!: number;

  @Column({ type: 'decimal', precision: 4, scale: 1, default: 0 })
  unpaid_days!: number;

  @Column({ type: 'decimal', precision: 4, scale: 1, default: 0 })
  ot_time!: number;

  @Column({ type: 'text', nullable: true })
  reason!: string | null;

  @Column({ type: 'varchar', length: 20, default: 'draft' })
  status!: string; // draft | submitted | approved | rejected | cancelled

  @Column({ type: 'uuid', nullable: true })
  approved_by!: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  approved_at!: Date | null;

  @Column({ type: 'text', nullable: true })
  reject_reason!: string | null;

  @Column({ type: 'uuid', nullable: true })
  cancelled_by!: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  cancelled_at!: Date | null;

  @Column({ type: 'text', nullable: true })
  cancel_reason!: string | null;

  @Column({ type: 'boolean', default: false })
  odoo_synced!: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  requester!: User;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'approved_by' })
  approver!: User | null;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'cancelled_by' })
  canceller!: User | null;

  @OneToMany(() => LeaveRequestDay, (day) => day.leave_request)
  leave_days!: LeaveRequestDay[];
}
