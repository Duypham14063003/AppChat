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

@Entity('attendance')
@Index('IDX_attendance_user_checkin', ['user_id', 'checkin_at'])
export class Attendance {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column('uuid')
  user_id!: string;

  @Column({ type: 'timestamptz' })
  checkin_at!: Date;

  @Column({ type: 'timestamptz', nullable: true })
  checkout_at!: Date | null;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  checkin_lat!: number | null;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  checkin_lng!: number | null;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  checkout_lat!: number | null;

  @Column({ type: 'decimal', precision: 10, scale: 7, nullable: true })
  checkout_lng!: number | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  device_id!: string | null;

  @Column({ type: 'decimal', precision: 4, scale: 2, nullable: true })
  total_hours!: number | null;

  @Column({ type: 'decimal', precision: 4, scale: 2, nullable: true })
  ot_hours!: number | null;

  @Column({ type: 'boolean', default: false })
  odoo_synced!: boolean;

  @Column({ type: 'timestamptz', nullable: true })
  odoo_synced_at!: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;
}
