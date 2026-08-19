import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  Index,
} from 'typeorm';
import { UserRole } from './user-role.entity.js';
import { UserSession } from './user-session.entity.js';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Index()
  @Column({ type: 'int', unique: true })
  odoo_uid!: number;

  @Index()
  @Column({ type: 'int', nullable: true, unique: true })
  odoo_employee_id!: number | null;

  @Index()
  @Column({ type: 'varchar', unique: true })
  email!: string;

  @Column({ type: 'varchar' })
  name!: string;

  @Column({ type: 'text', nullable: true })
  avatar_url!: string | null;

  @Column({ type: 'varchar', nullable: true })
  department!: string | null;

  @Column({ type: 'varchar', nullable: true })
  job_title!: string | null;

  @Column({ type: 'varchar', length: 30, nullable: true })
  phone_number!: string | null;

  @Column({ type: 'varchar', length: 20, default: 'official' })
  employment_status!: string;

  @Column({ type: 'boolean', default: true })
  is_active!: boolean;

  @Index()
  @Column({ type: 'boolean', default: false })
  is_bot!: boolean;

  @Column({ type: 'text', nullable: true })
  bot_description!: string | null;

  @Column({ type: 'varchar', length: 500, nullable: true })
  bot_webhook_url!: string | null;

  @Column({ type: 'uuid', nullable: true })
  bot_created_by!: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  last_seen_at!: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at!: Date;

  @OneToMany(() => UserRole, (ur) => ur.user)
  userRoles!: UserRole[];

  @OneToMany(() => UserSession, (s) => s.user)
  sessions!: UserSession[];
}
