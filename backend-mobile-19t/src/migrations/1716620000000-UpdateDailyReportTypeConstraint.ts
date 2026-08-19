import { MigrationInterface, QueryRunner } from 'typeorm';

export class UpdateDailyReportTypeConstraint1716620000000 implements MigrationInterface {
  name = 'UpdateDailyReportTypeConstraint1716620000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Drop existing constraint
    await queryRunner.query(
      `ALTER TABLE "daily_reports" DROP CONSTRAINT "CHK_daily_reports_type"`,
    );

    // Add updated constraint including 'ot'
    await queryRunner.query(
      `ALTER TABLE "daily_reports" ADD CONSTRAINT "CHK_daily_reports_type" CHECK ("report_type" IN ('morning', 'evening', 'ot'))`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Revert to original constraint
    await queryRunner.query(
      `ALTER TABLE "daily_reports" DROP CONSTRAINT "CHK_daily_reports_type"`,
    );
    await queryRunner.query(
      `ALTER TABLE "daily_reports" ADD CONSTRAINT "CHK_daily_reports_type" CHECK ("report_type" IN ('morning', 'evening'))`,
    );
  }
}
