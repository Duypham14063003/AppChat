import { MigrationInterface, QueryRunner } from 'typeorm';

export class UserPayrollConfig1713700000000 implements MigrationInterface {
  name = 'UserPayrollConfig1713700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "payroll_config"
      DROP CONSTRAINT IF EXISTS "CHK_payroll_config_singleton"
    `);
    await queryRunner.query(`
      CREATE SEQUENCE IF NOT EXISTS "payroll_config_id_seq"
      OWNED BY "payroll_config"."id"
    `);
    await queryRunner.query(`
      SELECT setval(
        '"payroll_config_id_seq"',
        GREATEST(COALESCE((SELECT MAX("id") FROM "payroll_config"), 0), 1),
        true
      )
    `);
    await queryRunner.query(`
      ALTER TABLE "payroll_config"
      ALTER COLUMN "id" SET DEFAULT nextval('"payroll_config_id_seq"')
    `);
    await queryRunner.query(`
      ALTER TABLE "payroll_config"
      ADD COLUMN IF NOT EXISTS "user_id" uuid
    `);

    await queryRunner.query(`
      WITH first_user AS (
        SELECT "id"
        FROM "users"
        ORDER BY "created_at" ASC, "id" ASC
        LIMIT 1
      )
      UPDATE "payroll_config"
      SET "user_id" = (SELECT "id" FROM first_user)
      WHERE "user_id" IS NULL
        AND EXISTS (SELECT 1 FROM first_user)
    `);
    await queryRunner.query(`
      INSERT INTO "payroll_config" (
        "user_id",
        "payroll_start_day",
        "standard_hours_per_day",
        "standard_days_per_month",
        "work_start_time",
        "checkin_reminder_time",
        "checkout_reminder_time",
        "auto_checkout_enabled",
        "auto_checkout_time"
      )
      SELECT
        u."id",
        template."payroll_start_day",
        template."standard_hours_per_day",
        template."standard_days_per_month",
        template."work_start_time",
        template."checkin_reminder_time",
        template."checkout_reminder_time",
        template."auto_checkout_enabled",
        template."auto_checkout_time"
      FROM "users" u
      CROSS JOIN LATERAL (
        SELECT *
        FROM "payroll_config"
        ORDER BY "id" ASC
        LIMIT 1
      ) template
      WHERE NOT EXISTS (
        SELECT 1
        FROM "payroll_config" pc
        WHERE pc."user_id" = u."id"
      )
    `);
    await queryRunner.query(`
      DELETE FROM "payroll_config"
      WHERE "user_id" IS NULL
    `);
    await queryRunner.query(`
      ALTER TABLE "payroll_config"
      ALTER COLUMN "user_id" SET NOT NULL
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS "IDX_payroll_config_user_id"
      ON "payroll_config" ("user_id")
    `);
    await queryRunner.query(`
      ALTER TABLE "payroll_config"
      ADD CONSTRAINT "FK_payroll_config_user"
      FOREIGN KEY ("user_id")
      REFERENCES "users"("id")
      ON DELETE CASCADE
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "payroll_config"
      DROP CONSTRAINT IF EXISTS "FK_payroll_config_user"
    `);
    await queryRunner.query(`
      DROP INDEX IF EXISTS "IDX_payroll_config_user_id"
    `);
    await queryRunner.query(`
      ALTER TABLE "payroll_config"
      DROP COLUMN IF EXISTS "user_id"
    `);
    await queryRunner.query(`
      ALTER TABLE "payroll_config"
      ALTER COLUMN "id" SET DEFAULT 1
    `);
    await queryRunner.query(`
      DROP SEQUENCE IF EXISTS "payroll_config_id_seq"
    `);
    await queryRunner.query(`
      DELETE FROM "payroll_config"
      WHERE "id" <> 1
    `);
    await queryRunner.query(`
      INSERT INTO "payroll_config" ("id")
      SELECT 1
      WHERE NOT EXISTS (
        SELECT 1 FROM "payroll_config" WHERE "id" = 1
      )
    `);
    await queryRunner.query(`
      ALTER TABLE "payroll_config"
      ADD CONSTRAINT "CHK_payroll_config_singleton" CHECK ("id" = 1)
    `);
  }
}
