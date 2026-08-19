import { MigrationInterface, QueryRunner } from 'typeorm';

export class PayrollConfig1710700000003 implements MigrationInterface {
  name = 'PayrollConfig1710700000003';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "payroll_config" (
        "id" integer NOT NULL DEFAULT 1,
        "payroll_start_day" integer NOT NULL DEFAULT 1,
        "standard_hours_per_day" decimal(4,2) NOT NULL DEFAULT 8.0,
        "standard_days_per_month" integer NOT NULL DEFAULT 22,
        "work_start_time" time NOT NULL DEFAULT '08:00',
        "checkin_reminder_time" time,
        "checkout_reminder_time" time,
        "auto_checkout_enabled" boolean NOT NULL DEFAULT false,
        "auto_checkout_time" time NOT NULL DEFAULT '23:59',
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_payroll_config" PRIMARY KEY ("id"),
        CONSTRAINT "CHK_payroll_config_singleton" CHECK ("id" = 1)
      )
    `);

    // Insert default row
    await queryRunner.query(`
      INSERT INTO "payroll_config" ("id") VALUES (1)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "payroll_config"`);
  }
}
