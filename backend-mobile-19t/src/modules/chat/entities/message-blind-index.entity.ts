import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

@Entity('message_blind_indexes')
export class MessageBlindIndex {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id!: string;

  @Column('uuid')
  message_id!: string;

  @Column('uuid')
  conv_id!: string;

  @Column({ type: 'varchar', length: 64 })
  token_hash!: string;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at!: Date;
}
