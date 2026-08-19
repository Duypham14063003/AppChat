import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';
import { PointRule } from './point-rule.entity.js';

@Entity('point_transactions')
@Index('IDX_point_transactions_user_created', ['user_id', 'created_at'])
export class PointTransaction {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid')
  user_id!: string;

  @Column({ type: 'uuid', nullable: true })
  rule_id!: string | null;

  @Column({ type: 'uuid', nullable: true })
  created_by!: string | null;

  @Column({ type: 'varchar', length: 20 })
  type!: string;

  @Index()
  @Column({ type: 'varchar', length: 40 })
  source_type!: string;

  @Column({ type: 'varchar', length: 100, nullable: true })
  source_ref_id!: string | null;

  @Column({ type: 'varchar', length: 150, nullable: true, unique: true })
  event_key!: string | null;

  @Column({ type: 'int' })
  points!: number;

  @Column({ type: 'int' })
  balance_after!: number;

  @Column({ type: 'text', nullable: true })
  note!: string | null;

  @Column({ type: 'jsonb', nullable: true })
  metadata!: Record<string, unknown> | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @ManyToOne(() => PointRule, (rule) => rule.transactions, {
    onDelete: 'SET NULL',
  })
  @JoinColumn({ name: 'rule_id' })
  rule!: PointRule | null;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'created_by' })
  actor!: User | null;
}
