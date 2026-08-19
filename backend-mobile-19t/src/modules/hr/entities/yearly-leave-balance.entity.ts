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

@Entity('yearly_leave_balances')
@Index('IDX_yearly_leave_balances_user_year', ['user_id', 'year'], {
  unique: true,
})
export class YearlyLeaveBalance {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid')
  user_id!: string;

  @Column({ type: 'int' })
  year!: number;

  @Column({ type: 'decimal', precision: 4, scale: 1, default: 12.0 })
  allocated_days!: number;

  @Column({ type: 'decimal', precision: 4, scale: 1, default: 0 })
  used_paid_days!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at!: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;
}
