import { Entity, Column, ManyToOne, JoinColumn, PrimaryColumn } from 'typeorm';
import { Conversation } from './conversation.entity.js';
import { User } from '../../auth/entities/user.entity.js';

@Entity('pinned_messages')
export class PinnedMessage {
  @PrimaryColumn('uuid')
  conv_id!: string;

  @PrimaryColumn('uuid')
  message_id!: string;

  @Column('uuid')
  pinned_by!: string;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  pinned_at!: Date;

  @ManyToOne(() => Conversation, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conv_id' })
  conversation!: Conversation;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'pinned_by' })
  user!: User;
}
