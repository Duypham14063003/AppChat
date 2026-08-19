import { Column, CreateDateColumn, Entity, Index, JoinColumn, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { EmployeeContract } from './employee-contract.entity.js';

@Entity('contract_reminder_events')
@Index('UQ_contract_reminder_event_key', ['contract_id', 'threshold_days', 'reminder_date'], { unique: true })
export class ContractReminderEvent {
  @PrimaryGeneratedColumn('uuid') id!: string;
  @Column('uuid') contract_id!: string;
  @Column({ type: 'integer' }) threshold_days!: number;
  @Column({ type: 'date' }) reminder_date!: string;
  @Column({ type: 'varchar', length: 20, default: 'pending' }) status!: 'pending' | 'delivered' | 'failed';
  @Column({ type: 'timestamptz', nullable: true }) delivered_at!: Date | null;
  @CreateDateColumn({ type: 'timestamptz' }) created_at!: Date;

  @ManyToOne(() => EmployeeContract, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'contract_id' })
  contract!: EmployeeContract;
}
