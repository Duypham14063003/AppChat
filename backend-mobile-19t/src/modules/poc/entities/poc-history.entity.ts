import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';
import { Poc } from './poc.entity.js';

@Entity('poc_history')
@Index('IDX_poc_history_poc_created', ['poc_id', 'created_at'])
export class PocHistory {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column('uuid') poc_id!: string;
  @Column({ type: 'uuid', nullable: true }) actor_user_id!: string | null;
  @Column({ type: 'varchar', length: 80 }) event_type!: string;
  @Column({ type: 'jsonb', nullable: true })
  previous_values!: Record<string, unknown> | null;
  @Column({ type: 'jsonb', nullable: true })
  new_values!: Record<string, unknown> | null;
  @CreateDateColumn({ type: 'timestamptz' }) created_at!: Date;

  @ManyToOne(() => Poc, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'poc_id' })
  poc!: Poc;
  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'actor_user_id' })
  actor!: User | null;
}
