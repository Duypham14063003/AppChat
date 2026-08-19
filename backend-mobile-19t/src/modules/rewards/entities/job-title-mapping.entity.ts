import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { InternalRole } from './internal-role.entity';

@Entity('job_title_mappings')
export class JobTitleMapping {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'odoo_job_title', type: 'varchar', unique: true, length: 255 })
  job_title!: string;

  @Column({ type: 'uuid' })
  internal_role_id!: string;

  @ManyToOne(() => InternalRole, (role) => role.mappings, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'internal_role_id' })
  internal_role!: InternalRole;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at!: Date;
}
