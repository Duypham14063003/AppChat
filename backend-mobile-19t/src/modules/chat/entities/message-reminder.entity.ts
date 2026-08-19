import {
  Entity,
  Column,
  ManyToOne,
  JoinColumn,
  PrimaryGeneratedColumn,
  CreateDateColumn,
} from 'typeorm';
import { Conversation } from './conversation.entity.js';
import { User } from '../../auth/entities/user.entity.js';

export type MessageReminderScope = 'self' | 'everyone';
export type MessageReminderStatus = 'pending' | 'cancelled' | 'fired';

@Entity('message_reminders')
export class MessageReminder {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid')
  conv_id!: string;

  @Column('uuid')
  message_id!: string;

  @Column('uuid')
  creator_user_id!: string;

  @Column({ type: 'varchar', length: 20 })
  scope!: MessageReminderScope;

  @Column({ type: 'varchar', length: 20, default: 'pending' })
  status!: MessageReminderStatus;

  @Column({ type: 'timestamptz' })
  remind_at!: Date;

  @Column({ type: 'timestamptz', nullable: true })
  cancelled_at!: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  fired_at!: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  updated_at!: Date;

  @ManyToOne(() => Conversation, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conv_id' })
  conversation!: Conversation;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'creator_user_id' })
  creator!: User;
}
