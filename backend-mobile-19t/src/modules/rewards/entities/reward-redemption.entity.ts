import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';
import { RewardItem } from './reward-item.entity.js';

@Entity('reward_redemptions')
@Index('IDX_reward_redemptions_user_created', ['user_id', 'created_at'])
@Index('IDX_reward_redemptions_status_created', ['status', 'created_at'])
export class RewardRedemption {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid')
  user_id!: string;

  @Column('uuid')
  reward_item_id!: string;

  @Column({ type: 'int', default: 1 })
  quantity!: number;

  @Column({ type: 'int' })
  unit_points_cost!: number;

  @Column({ type: 'int' })
  total_points_cost!: number;

  @Column({ type: 'varchar', length: 20, default: 'pending' })
  status!: string;

  @Column({ type: 'text', nullable: true })
  requested_note!: string | null;

  @Column({ type: 'text', nullable: true })
  processed_note!: string | null;

  @Column({ type: 'uuid', nullable: true })
  processed_by!: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  processed_at!: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at!: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @ManyToOne(() => RewardItem, (item) => item.redemptions, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'reward_item_id' })
  reward_item!: RewardItem;

  @ManyToOne(() => User, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'processed_by' })
  processor!: User | null;
}
