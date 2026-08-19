import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';

@Entity('odoo_task_reward_logs')
export class OdooTaskRewardLog {
  @PrimaryColumn({ type: 'int' })
  task_id!: number;

  @Index()
  @Column({ type: 'uuid' })
  user_id!: string;

  @Column({ type: 'int' })
  points!: number;

  @Column({ type: 'boolean', default: false })
  is_miss!: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  rewarded_at!: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;
}
