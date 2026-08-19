import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
  Index,
} from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';
import { DailyReportItem } from './daily-report-item.entity.js';

@Entity('daily_reports')
@Index('IDX_daily_reports_user_date', ['user_id', 'report_date'])
@Index('UQ_daily_reports_user_date_type', ['user_id', 'report_date', 'report_type'], {
  unique: true,
})
export class DailyReport {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid')
  user_id!: string;

  @Column({ type: 'date', default: () => 'CURRENT_DATE' })
  report_date!: string;

  @Column({ type: 'varchar', length: 20 })
  report_type!: 'morning' | 'evening' | 'ot';

  @Column({ type: 'varchar', length: 10, default: 'dev' })
  report_role!: 'dev' | 'qc';

  @Column({ type: 'jsonb' })
  projects!: any[];

  @Column({ type: 'text', nullable: true })
  note!: string | null;

  @Column({ type: 'uuid', nullable: true })
  chat_message_id!: string | null;

  @Column({ type: 'integer', default: 0 })
  total_points_earned!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at!: Date;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @OneToMany(() => DailyReportItem, (item) => item.report)
  items!: DailyReportItem[];
}
