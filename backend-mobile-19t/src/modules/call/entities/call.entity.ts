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

@Entity('calls')
export class Call {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column('uuid')
  caller_id!: string;

  @Index()
  @Column('uuid')
  receiver_id!: string;

  @Column({ type: 'varchar', unique: true })
  channel_name!: string;

  @Column({ type: 'enum', enum: ['audio', 'video'], default: 'audio' })
  type!: 'audio' | 'video';

  @Column({
    type: 'enum',
    enum: ['ringing', 'accepted', 'rejected', 'ended', 'missed', 'busy'],
    default: 'ringing',
  })
  status!: 'ringing' | 'accepted' | 'rejected' | 'ended' | 'missed' | 'busy';

  @Column({ type: 'timestamptz', nullable: true })
  started_at!: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  accepted_at!: Date | null;

  @Column({ type: 'timestamptz', nullable: true })
  ended_at!: Date | null;

  @Column({ type: 'int', default: 0 })
  duration!: number; // in seconds

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at!: Date;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'caller_id' })
  caller!: User;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'receiver_id' })
  receiver!: User;
}
