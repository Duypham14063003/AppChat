import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddReReportMultiplierToOdooTaskTagConfigs1716700000000
  implements MigrationInterface
{
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "odoo_task_tag_configs" ADD "re_report_multiplier" integer NOT NULL DEFAULT 1`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "odoo_task_tag_configs" DROP COLUMN "re_report_multiplier"`,
    );
  }
}
