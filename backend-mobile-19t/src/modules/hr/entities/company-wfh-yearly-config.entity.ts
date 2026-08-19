import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('company_wfh_yearly_configs')
@Index('IDX_company_wfh_yearly_configs_year', ['year'], { unique: true })
export class CompanyWfhYearlyConfig {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'int' })
  year!: number;

  @Column({ type: 'decimal', precision: 4, scale: 1, default: 0 })
  allocated_days!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at!: Date;
}
