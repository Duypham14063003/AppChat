import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  OneToOne,
  PrimaryColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from '../../auth/entities/user.entity.js';

@Entity('employee_profiles')
export class EmployeeProfile {
  @PrimaryColumn('uuid') user_id!: string;
  @Column({ type: 'date', nullable: true }) date_of_birth!: string | null;
  @Column({ type: 'varchar', length: 20, nullable: true }) gender!:
    | string
    | null;
  @Column({ type: 'varchar', length: 50, nullable: true }) identity_number!:
    | string
    | null;
  @Column({ type: 'date', nullable: true }) identity_issued_date!:
    | string
    | null;
  @Column({ type: 'varchar', length: 255, nullable: true })
  identity_issued_place!: string | null;
  @Column({ type: 'text', nullable: true }) permanent_address!: string | null;
  @Column({ type: 'text', nullable: true }) current_address!: string | null;
  @Column({ type: 'varchar', length: 30, nullable: true }) personal_phone!:
    | string
    | null;
  @Column({ type: 'varchar', length: 255, nullable: true }) personal_email!:
    | string
    | null;
  @Column({ type: 'varchar', length: 255, nullable: true })
  emergency_contact_name!: string | null;
  @Column({ type: 'varchar', length: 30, nullable: true })
  emergency_contact_phone!: string | null;
  @Column({ type: 'varchar', length: 100, nullable: true })
  emergency_contact_relationship!: string | null;
  @Column({ type: 'varchar', length: 30, nullable: true }) marital_status!:
    | string
    | null;
  @Column({ type: 'varchar', length: 50, nullable: true }) tax_code!:
    | string
    | null;
  @Column({ type: 'varchar', length: 100, nullable: true })
  bank_account_number!: string | null;
  @Column({ type: 'varchar', length: 255, nullable: true }) bank_name!:
    | string
    | null;
  @Column({ type: 'varchar', length: 20, nullable: true }) bank_code!:
    | string
    | null;
  @Column({ type: 'varchar', length: 255, nullable: true }) bank_account_name!:
    | string
    | null;
  @Column({ type: 'varchar', length: 500, nullable: true }) bank_qr_image_url!:
    | string
    | null;
  @Column({ type: 'varchar', length: 20, nullable: true }) bank_qr_source!:
    | 'generated'
    | 'uploaded'
    | null;
  @Column({ type: 'date', nullable: true }) joined_at!: string | null;
  @Column({ type: 'uuid', nullable: true }) updated_by!: string | null;
  @CreateDateColumn({ type: 'timestamptz' }) created_at!: Date;
  @UpdateDateColumn({ type: 'timestamptz' }) updated_at!: Date;

  @OneToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;
}
