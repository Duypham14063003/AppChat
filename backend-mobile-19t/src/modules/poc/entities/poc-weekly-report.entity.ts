import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';
import { Conversation } from '../../chat/entities/conversation.entity.js';

@Entity('poc_weekly_reports')
@Index('UQ_poc_weekly_report_week', ['iso_year', 'iso_week'], { unique: true })
export class PocWeeklyReport {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column({ type: 'integer' }) iso_year!: number;
  @Column({ type: 'integer' }) iso_week!: number;
  @Column('uuid') conversation_id!: string;
  @Column({ type: 'uuid', nullable: true }) chat_message_id!: string | null;
  @Column({ type: 'varchar', length: 20, default: 'draft' })
  status!: 'draft' | 'published' | 'failed';
  @Column({ type: 'jsonb', default: () => "'{}'::jsonb" })
  snapshot!: Record<string, unknown>;
  @Column({ type: 'timestamptz', nullable: true }) published_at!: Date | null;
  @CreateDateColumn({ type: 'timestamptz' }) created_at!: Date;
  @UpdateDateColumn({ type: 'timestamptz' }) updated_at!: Date;

  @ManyToOne(() => Conversation, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'conversation_id' })
  conversation!: Conversation;
}
