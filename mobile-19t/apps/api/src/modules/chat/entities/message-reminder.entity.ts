import {
  Entity,
  Column,
  PrimaryColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Conversation } from './conversation.entity.js';
import { Message } from './message.entity.js';
import { User } from '../../auth/entities/user.entity.js';

export type MessageReminderScope = 'self' | 'everyone';
export type MessageReminderStatus = 'pending' | 'cancelled' | 'fired';

@Entity('message_reminders')
@Index('idx_message_reminders_conv_remind_at', ['conv_id', 'remind_at'])
export class MessageReminder {
  @PrimaryColumn('uuid')
  id!: string;

  @Column('uuid')
  conv_id!: string;

  @Column('uuid')
  message_id!: string;

  @Column('uuid')
  creator_user_id!: string;

  @Column({ type: 'varchar', length: 20 })
  scope!: MessageReminderScope;

  @Column({ type: 'timestamptz' })
  remind_at!: Date;

  @Column({ type: 'varchar', length: 20, default: 'pending' })
  status!: MessageReminderStatus;

  @Column({ type: 'timestamptz', nullable: true })
  cancelled_at!: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  fired_at!: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at!: Date;

  @ManyToOne(() => Conversation, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conv_id' })
  conversation!: Conversation;

  @ManyToOne(() => Message, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'message_id' })
  message!: Message;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'creator_user_id' })
  creator!: User;
}
