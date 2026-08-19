import { Entity, Column, ManyToOne, JoinColumn, PrimaryColumn } from 'typeorm';
import { Conversation } from './conversation.entity.js';
import { User } from '../../auth/entities/user.entity.js';

@Entity('message_bookmarks')
export class MessageBookmark {
  @PrimaryColumn('uuid')
  user_id!: string;

  @PrimaryColumn('uuid')
  conv_id!: string;

  @PrimaryColumn('uuid')
  message_id!: string;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  marked_at!: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @ManyToOne(() => Conversation, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conv_id' })
  conversation!: Conversation;
}
