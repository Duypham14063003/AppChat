import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryColumn,
} from 'typeorm';
import { Conversation } from './conversation.entity.js';

@Entity('conversation_encryption_keys')
export class ConversationEncryptionKey {
  @PrimaryColumn('uuid')
  conv_id!: string;

  @PrimaryColumn({ type: 'varchar', length: 255 })
  key_id!: string;

  @Column({ type: 'varchar', length: 50, default: 'AES-256-GCM' })
  alg!: string;

  @Column({ type: 'int', default: 1 })
  version!: number;

  @Column({ type: 'bytea' })
  material!: Buffer;

  @Column({ type: 'boolean', default: true })
  is_active!: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @ManyToOne(() => Conversation, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'conv_id' })
  conversation!: Conversation;
}
