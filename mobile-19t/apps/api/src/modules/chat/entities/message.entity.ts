import {
  Entity,
  Column,
  ManyToOne,
  JoinColumn,
  PrimaryColumn,
  OneToMany,
} from 'typeorm';
import { Conversation } from './conversation.entity.js';
import { User } from '../../auth/entities/user.entity.js';
import { MessageReaction } from './message-reaction.entity.js';

@Entity('messages')
export class Message {
  @PrimaryColumn('uuid')
  id!: string;

  @Column('uuid')
  conv_id!: string;

  @Column('uuid')
  sender_id!: string;

  @Column({ type: 'varchar', length: 20, default: 'text' })
  type!: string;

  @Column({ type: 'text', nullable: true })
  content!: string | null;

  @Column({ type: 'uuid', nullable: true })
  reply_to_id!: string | null;

  @Column({ type: 'uuid', nullable: true })
  forwarded_from_id!: string | null;

  @Column({ type: 'varchar', nullable: true })
  forwarded_from_sender!: string | null;

  @Column({ type: 'jsonb', nullable: true })
  metadata!: Record<string, unknown> | null;

  @PrimaryColumn({ type: 'timestamptz', default: () => 'now()' })
  created_at!: Date;

  @Column({ type: 'timestamptz', nullable: true })
  edited_at!: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  deleted_at!: Date | null;

  @ManyToOne(() => Conversation, (c) => c.messages, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conv_id' })
  conversation!: Conversation;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'sender_id' })
  sender!: User;

  @OneToMany(() => MessageReaction, (r) => r.message)
  reactions!: MessageReaction[];
}
