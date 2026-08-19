import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  Index,
  Unique,
  CreateDateColumn,
} from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';

@Entity('point_period_history')
@Unique(['user_id', 'period'])
export class PointPeriodHistory {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column('uuid')
  user_id!: string;

  /**
   * The period string, e.g., "2026-05"
   */
  @Column({ type: 'varchar', length: 7 })
  period!: string;

  @Column({ type: 'int', default: 0 })
  points_earned!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;
}
