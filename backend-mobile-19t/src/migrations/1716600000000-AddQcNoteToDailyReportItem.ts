import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddQcNoteToDailyReportItem1716600000000 implements MigrationInterface {
  name = 'AddQcNoteToDailyReportItem1716600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "daily_report_items" ADD "qc_note" character varying(1000)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "daily_report_items" DROP COLUMN "qc_note"`);
  }
}
