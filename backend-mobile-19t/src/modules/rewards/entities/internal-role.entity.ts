import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { JobTitleMapping } from './job-title-mapping.entity';

@Entity('internal_roles')
export class InternalRole {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'varchar', unique: true, length: 100 })
  name!: string;

  @Column({ type: 'decimal', precision: 5, scale: 2, default: '1.00' })
  multiplier!: number;

  @OneToMany(() => JobTitleMapping, (mapping) => mapping.internal_role)
  mappings!: JobTitleMapping[];

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at!: Date;
}
