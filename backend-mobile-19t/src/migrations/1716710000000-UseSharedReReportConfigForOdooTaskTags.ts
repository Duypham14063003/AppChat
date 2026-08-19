import { MigrationInterface, QueryRunner } from 'typeorm';

const REREPORT_TAG_NAME = 'Báo cáo lại';

export class UseSharedReReportConfigForOdooTaskTags1716710000000
  implements MigrationInterface
{
  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "odoo_task_tag_configs" DROP COLUMN IF EXISTS "re_report_multiplier"`,
    );

    await queryRunner.query(`
      WITH next_id AS (
        SELECT COALESCE(MAX(id), 0) + 1 AS id
        FROM "odoo_task_tag_configs"
      )
      INSERT INTO "odoo_task_tag_configs" ("id", "tag_name", "base_points", "created_at", "updated_at")
      SELECT next_id.id, '${REREPORT_TAG_NAME}', 1, NOW(), NOW()
      FROM next_id
      WHERE NOT EXISTS (
        SELECT 1 FROM "odoo_task_tag_configs" WHERE "tag_name" = '${REREPORT_TAG_NAME}'
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "odoo_task_tag_configs" ADD COLUMN IF NOT EXISTS "re_report_multiplier" integer NOT NULL DEFAULT 1`,
    );

    await queryRunner.query(
      `DELETE FROM "odoo_task_tag_configs" WHERE "tag_name" = '${REREPORT_TAG_NAME}'`,
    );
  }
}
