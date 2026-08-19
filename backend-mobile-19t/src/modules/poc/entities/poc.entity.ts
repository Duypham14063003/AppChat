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
import { User } from '../../auth/entities/user.entity.js';
import { Conversation } from '../../chat/entities/conversation.entity.js';
import type {
  PocOutcome,
  PocPriority,
  PocProductType,
  PocStatus,
} from '../poc.constants.js';

@Entity('pocs')
@Index('IDX_pocs_demo_status', ['demo_at', 'status'])
@Index('IDX_pocs_developer_plan', [
  'developer_user_id',
  'planned_start_at',
  'demo_at',
])
@Index('IDX_pocs_sale_created', ['sale_user_id', 'created_at'])
export class Poc {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column({ type: 'bigint', nullable: true, unique: true })
  sequence_number!: string | null;
  @Column({ type: 'varchar', length: 120, nullable: true, unique: true })
  code!: string | null;
  @Column({ type: 'varchar', length: 255 }) customer_name!: string;
  @Column({ type: 'varchar', length: 255 }) title!: string;
  @Column({ type: 'text' }) requirement!: string;
  @Column({ type: 'varchar', length: 30 }) product_type!: PocProductType;
  @Column({ type: 'varchar', length: 20, default: 'normal' })
  priority!: PocPriority;
  @Column('uuid') sale_user_id!: string;
  @Column({ type: 'uuid', nullable: true }) developer_user_id!: string | null;
  @Column({ type: 'uuid', nullable: true }) assigned_by_user_id!: string | null;
  @Column({ type: 'uuid', nullable: true })
  working_conversation_id!: string | null;
  @Column({ type: 'uuid', nullable: true }) source_message_id!: string | null;
  @Column({ type: 'timestamptz', nullable: true })
  planned_start_at!: Date | null;
  @Column({ type: 'numeric', precision: 8, scale: 2, nullable: true })
  estimated_hours!: string | null;
  @Column({ type: 'timestamptz' }) demo_at!: Date;
  @Column({ type: 'varchar', length: 20, default: 'unassigned' })
  status!: PocStatus;
  @Column({ type: 'varchar', length: 30, nullable: true })
  outcome!: PocOutcome | null;
  @Column({ type: 'varchar', length: 1000, nullable: true })
  poc_url!: string | null;
  @Column({ type: 'jsonb', default: () => "'[]'::jsonb" })
  reference_links!: string[];
  @Column({ type: 'text', nullable: true }) cancel_reason!: string | null;
  @Column({ type: 'timestamptz', nullable: true }) ready_at!: Date | null;
  @Column({ type: 'timestamptz', nullable: true })
  demonstrated_at!: Date | null;
  @Column({ type: 'integer', default: 1 }) version!: number;
  @CreateDateColumn({ type: 'timestamptz' }) created_at!: Date;
  @UpdateDateColumn({ type: 'timestamptz' }) updated_at!: Date;

  @ManyToOne(() => User, { onDelete: 'RESTRICT' })
  @JoinColumn({ name: 'sale_user_id' })
  sale_user!: User;
  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'developer_user_id' })
  developer_user!: User | null;
  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'assigned_by_user_id' })
  assigned_by_user!: User | null;
  @ManyToOne(() => Conversation, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'working_conversation_id' })
  working_conversation!: Conversation | null;
}
