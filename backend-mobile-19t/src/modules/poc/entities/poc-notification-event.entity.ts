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
import type { PocNotificationKind } from '../poc.constants.js';
import { Poc } from './poc.entity.js';

@Entity('poc_notification_events')
@Index(
  'UQ_poc_notification_delivery',
  ['poc_id', 'event_kind', 'scheduled_at'],
  {
    unique: true,
  },
)
export class PocNotificationEvent {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column('uuid') poc_id!: string;
  @Column({ type: 'varchar', length: 50 }) event_kind!: PocNotificationKind;
  @Column({ type: 'timestamptz' }) scheduled_at!: Date;
  @Column({ type: 'varchar', length: 20, default: 'processing' })
  status!: 'processing' | 'delivered' | 'failed' | 'skipped';
  @Column({ type: 'integer', default: 0 }) attempts!: number;
  @Column({ type: 'timestamptz', nullable: true }) delivered_at!: Date | null;
  @Column({ type: 'text', nullable: true }) last_error!: string | null;
  @CreateDateColumn({ type: 'timestamptz' }) created_at!: Date;
  @UpdateDateColumn({ type: 'timestamptz' }) updated_at!: Date;

  @ManyToOne(() => Poc, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'poc_id' })
  poc!: Poc;
}
