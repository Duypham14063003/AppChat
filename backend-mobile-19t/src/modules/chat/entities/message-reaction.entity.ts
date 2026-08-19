import { Entity, Column, ManyToOne, JoinColumn, PrimaryColumn } from 'typeorm';
import { Message } from './message.entity.js';
import { User } from '../../auth/entities/user.entity.js';

@Entity('message_reactions')
export class MessageReaction {
  @PrimaryColumn('uuid')
  message_id!: string;

  @PrimaryColumn('uuid')
  user_id!: string;

  @PrimaryColumn({ type: 'varchar', length: 10 })
  emoji!: string;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  created_at!: Date;

  @ManyToOne(() => Message, (m) => m.reactions, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'message_id', referencedColumnName: 'id' })
  message!: Message;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;
}
