import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource, QueryRunner } from 'typeorm';

@Injectable()
export class MessagePartitionService implements OnModuleInit {
  private static readonly DEFAULT_PARTITION = 'messages_default';
  private static readonly FUTURE_QUARTERS = 8;
  private static readonly LOCK_ID = 190001901;

  private readonly logger = new Logger(MessagePartitionService.name);

  constructor(
    @InjectDataSource()
    private readonly dataSource: DataSource,
  ) {}

  async onModuleInit(): Promise<void> {
    if (!this.dataSource.isInitialized) {
      return;
    }

    try {
      await this.ensurePartitions();
    } catch (err: any) {
      this.logger.error(
        `Failed to ensure message partitions: ${err.message}`,
        err.stack,
      );
    }
  }

  private async ensurePartitions(): Promise<void> {
    const queryRunner = this.dataSource.createQueryRunner();
    let lockAcquired = false;

    await queryRunner.connect();

    try {
      const parentExists = await this.messagesTableExists(queryRunner);
      if (!parentExists) {
        this.logger.warn(
          'Skipping partition bootstrap because messages table does not exist yet',
        );
        return;
      }

      await queryRunner.query(`SELECT pg_advisory_lock($1)`, [
        MessagePartitionService.LOCK_ID,
      ]);
      lockAcquired = true;

      await this.ensureDefaultPartition(queryRunner);

      const quarterStarts = this.getQuarterStarts(
        new Date(),
        MessagePartitionService.FUTURE_QUARTERS,
      );
      for (const quarterStart of quarterStarts) {
        await this.ensureQuarterPartition(queryRunner, quarterStart);
      }
    } finally {
      try {
        if (lockAcquired) {
          await queryRunner.query(`SELECT pg_advisory_unlock($1)`, [
            MessagePartitionService.LOCK_ID,
          ]);
        }
      } finally {
        await queryRunner.release();
      }
    }
  }

  private async messagesTableExists(queryRunner: QueryRunner): Promise<boolean> {
    const result = await queryRunner.query(
      `SELECT to_regclass('public.messages') AS table_name`,
    );
    return Boolean(result[0]?.table_name);
  }

  private async ensureDefaultPartition(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "${MessagePartitionService.DEFAULT_PARTITION}"
      PARTITION OF "messages" DEFAULT
    `);
  }

  private async ensureQuarterPartition(
    queryRunner: QueryRunner,
    quarterStart: Date,
  ): Promise<void> {
    const quarterEnd = this.addMonthsUtc(quarterStart, 3);
    const partitionName = this.getPartitionName(quarterStart);

    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "${partitionName}"
      PARTITION OF "messages"
      FOR VALUES FROM ('${this.formatDateUtc(quarterStart)}')
      TO ('${this.formatDateUtc(quarterEnd)}')
    `);
  }

  private getQuarterStarts(baseDate: Date, futureQuarters: number): Date[] {
    const starts: Date[] = [];
    const currentQuarterStart = this.startOfQuarterUtc(baseDate);

    for (let offset = 0; offset <= futureQuarters; offset += 1) {
      starts.push(this.addMonthsUtc(currentQuarterStart, offset * 3));
    }

    return starts;
  }

  private startOfQuarterUtc(date: Date): Date {
    const year = date.getUTCFullYear();
    const month = date.getUTCMonth();
    const quarterStartMonth = Math.floor(month / 3) * 3;
    return new Date(Date.UTC(year, quarterStartMonth, 1));
  }

  private addMonthsUtc(date: Date, months: number): Date {
    return new Date(
      Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + months, 1),
    );
  }

  private getPartitionName(date: Date): string {
    const year = date.getUTCFullYear();
    const quarter = Math.floor(date.getUTCMonth() / 3) + 1;
    return `messages_${year}_q${quarter}`;
  }

  private formatDateUtc(date: Date): string {
    const year = date.getUTCFullYear();
    const month = `${date.getUTCMonth() + 1}`.padStart(2, '0');
    const day = `${date.getUTCDate()}`.padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}
