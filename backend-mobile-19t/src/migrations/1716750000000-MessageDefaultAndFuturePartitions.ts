import { MigrationInterface, QueryRunner } from 'typeorm';

export class MessageDefaultAndFuturePartitions1716750000000
  implements MigrationInterface
{
  name = 'MessageDefaultAndFuturePartitions1716750000000';

  private static readonly DEFAULT_PARTITION = 'messages_default';
  private static readonly FUTURE_QUARTERS = 8;

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "${MessageDefaultAndFuturePartitions1716750000000.DEFAULT_PARTITION}"
      PARTITION OF "messages" DEFAULT
    `);

    const currentQuarterStart = this.startOfQuarterUtc(new Date());
    for (
      let offset = 0;
      offset <= MessageDefaultAndFuturePartitions1716750000000.FUTURE_QUARTERS;
      offset += 1
    ) {
      const quarterStart = this.addMonthsUtc(currentQuarterStart, offset * 3);
      const quarterEnd = this.addMonthsUtc(quarterStart, 3);
      const partitionName = this.getPartitionName(quarterStart);

      await queryRunner.query(`
        CREATE TABLE IF NOT EXISTS "${partitionName}"
        PARTITION OF "messages"
        FOR VALUES FROM ('${this.formatDateUtc(quarterStart)}')
        TO ('${this.formatDateUtc(quarterEnd)}')
      `);
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP TABLE IF EXISTS "${MessageDefaultAndFuturePartitions1716750000000.DEFAULT_PARTITION}"`,
    );
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
