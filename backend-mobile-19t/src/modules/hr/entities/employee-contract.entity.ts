import { Column, CreateDateColumn, Entity, Index, JoinColumn, ManyToOne, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';

export type EmployeeContractType = 'internship' | 'probation' | 'official' | 'temporary';
export type EmployeeContractStatus = 'draft' | 'active' | 'expired' | 'terminated' | 'renewed';

@Entity('employee_contracts')
@Index('IDX_employee_contracts_user_start', ['user_id', 'start_date'])
@Index('IDX_employee_contracts_status_end', ['status', 'end_date'])
export class EmployeeContract {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column('uuid') user_id!: string;
  @Column({ type: 'varchar', length: 20 }) type!: EmployeeContractType;
  @Column({ type: 'date', nullable: true }) signed_date!: string | null;
  @Column({ type: 'date' }) start_date!: string;
  @Column({ type: 'date', nullable: true }) end_date!: string | null;
  @Column({ type: 'varchar', length: 20, default: 'draft' }) status!: EmployeeContractStatus;
  @Column({ type: 'text', nullable: true }) notes!: string | null;
  @Column({ type: 'varchar', length: 500, nullable: true }) attachment_url!: string | null;
  @Column({ type: 'varchar', length: 255, nullable: true }) attachment_name!: string | null;
  @Column({ type: 'varchar', length: 100, nullable: true }) attachment_mime_type!: string | null;
  @Column({ type: 'integer', nullable: true }) attachment_size!: number | null;
  @Column({ type: 'uuid', nullable: true }) renewed_from_id!: string | null;
  @Column({ type: 'uuid' }) created_by!: string;
  @Column({ type: 'uuid', nullable: true }) updated_by!: string | null;
  @CreateDateColumn({ type: 'timestamptz' }) created_at!: Date;
  @UpdateDateColumn({ type: 'timestamptz' }) updated_at!: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;
}
