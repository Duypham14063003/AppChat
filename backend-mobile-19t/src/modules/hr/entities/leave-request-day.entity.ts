import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { LeaveRequest } from './leave-request.entity.js';

@Entity('leave_request_days')
@Index('IDX_leave_request_days_request_date', [
  'leave_request_id',
  'leave_date',
])
@Index('IDX_leave_request_days_date', ['leave_date'])
export class LeaveRequestDay {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid')
  leave_request_id!: string;

  @Column({ type: 'date' })
  leave_date!: string;

  @Column({ type: 'decimal', precision: 3, scale: 1 })
  duration_days!: number;

  @Column({ type: 'varchar', length: 20, nullable: true })
  half_day_part!: string | null;

  @Column({ type: 'boolean', default: false })
  is_paid!: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @ManyToOne(() => LeaveRequest, (leave) => leave.leave_days, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'leave_request_id' })
  leave_request!: LeaveRequest;
}
