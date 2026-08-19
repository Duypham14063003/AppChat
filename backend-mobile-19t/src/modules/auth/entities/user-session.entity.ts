import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from './user.entity.js';

@Entity('user_sessions')
export class UserSession {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column('uuid')
  user_id!: string;

  @Column({ type: 'varchar', nullable: true })
  device_id!: string | null;

  @Column({ type: 'varchar', nullable: true })
  device_name!: string | null;

  @Column({ type: 'varchar' })
  refresh_token_hash!: string;

  @Column({ type: 'text', nullable: true })
  fcm_token!: string | null;

  @Column({ type: 'text', nullable: true })
  voip_token!: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  last_used_at!: Date | null;

  @Column({ type: 'varchar', length: 45, nullable: true })
  last_ip!: string | null;

  @Index()
  @Column({ type: 'timestamptz' })
  expires_at!: Date;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @ManyToOne(() => User, (u) => u.sessions, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;
}
