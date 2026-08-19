import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';
import { ConversationMember } from './conversation-member.entity.js';
import { Message } from './message.entity.js';

@Entity('conversations')
export class Conversation {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'varchar', length: 10, default: 'DIRECT' })
  type!: string;

  @Column({ type: 'varchar', nullable: true })
  name!: string | null;

  @Column({ type: 'text', nullable: true })
  avatar_url!: string | null;

  @Column('uuid')
  created_by!: string;

  @Column({ type: 'timestamptz', nullable: true })
  last_message_at!: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'created_by' })
  creator!: User;

  @OneToMany(() => ConversationMember, (m) => m.conversation)
  members!: ConversationMember[];

  @OneToMany(() => Message, (m) => m.conversation)
  messages!: Message[];
}
