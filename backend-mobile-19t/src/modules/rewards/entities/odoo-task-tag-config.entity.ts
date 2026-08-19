import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('odoo_task_tag_configs')
export class OdooTaskTagConfig {
  @PrimaryColumn({ type: 'int' })
  id!: number;

  @Index({ unique: true })
  @Column({ type: 'varchar', length: 100 })
  tag_name!: string;

  @Column({ type: 'int' })
  base_points!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at!: Date;
}
