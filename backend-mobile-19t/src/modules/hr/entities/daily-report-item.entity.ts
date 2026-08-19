import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { DailyReport } from './daily-report.entity.js';

@Entity('daily_report_items')
export class DailyReportItem {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid')
  report_id!: string;

  @Index()
  @Column({ type: 'varchar', length: 255 })
  task_id!: string;

  @Column({ type: 'varchar', length: 1000 })
  task_name!: string;

  @Column({ type: 'integer' })
  project_id!: number;

  @Column({ type: 'varchar', length: 255 })
  project_name!: string;

  @Column({ type: 'varchar', length: 20, nullable: true })
  status!: string | null;

  @Column({ type: 'integer', nullable: true })
  progress!: number | null;

  @Column({ type: 'integer', nullable: true })
  qc_done!: number | null;

  @Column({ type: 'integer', nullable: true })
  qc_miss!: number | null;

  @Column({ type: 'integer', nullable: true })
  qc_fail!: number | null;

  @Column({ type: 'varchar', length: 1000, nullable: true })
  qc_note!: string | null;

  @Column({ type: 'integer', default: 0 })
  points_awarded!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @ManyToOne(() => DailyReport, (report) => report.items, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'report_id' })
  report!: DailyReport;
}
