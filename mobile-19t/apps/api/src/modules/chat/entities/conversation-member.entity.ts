import { Entity, Column, ManyToOne, JoinColumn, PrimaryColumn } from 'typeorm';
import { Conversation } from './conversation.entity.js';
import { User } from '../../auth/entities/user.entity.js';

@Entity('conversation_members')
export class ConversationMember {
  @PrimaryColumn('uuid')
  conv_id!: string;

  @PrimaryColumn('uuid')
  user_id!: string;

  @Column({ type: 'varchar', length: 10, default: 'member' })
  role!: string;

  @Column({ type: 'uuid', nullable: true })
  last_read_message_id!: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  last_read_at!: Date | null;

  @Column({ type: 'boolean', default: false })
  is_muted!: boolean;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  joined_at!: Date;

  @ManyToOne(() => Conversation, (c) => c.members, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conv_id' })
  conversation!: Conversation;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;
}
