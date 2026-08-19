import {
  Entity,
  PrimaryColumn,
  Column,
  UpdateDateColumn,
  OneToMany,
  OneToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';
import { PointTransaction } from './point-transaction.entity.js';

@Entity('user_point_wallets')
export class UserPointWallet {
  @PrimaryColumn('uuid')
  user_id!: string;

  @Column({ type: 'int', default: 0 })
  balance!: number;

  @Column({ type: 'int', default: 0 })
  lifetime_earned!: number;

  @Column({ type: 'int', default: 0 })
  lifetime_spent!: number;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at!: Date;

  @OneToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @OneToMany(() => PointTransaction, (tx) => tx.user)
  transactions!: PointTransaction[];
}
