import { MigrationInterface, QueryRunner } from 'typeorm';

export class DailyReportSystem1715000000002 implements MigrationInterface {
  name = 'DailyReportSystem1715000000002';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Create daily_reports table
    await queryRunner.query(`
      CREATE TABLE "daily_reports" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "report_date" date NOT NULL DEFAULT CURRENT_DATE,
        "report_type" varchar(20) NOT NULL,
        "report_role" varchar(10) NOT NULL DEFAULT 'dev',
        "projects" jsonb NOT NULL,
        "note" text,
        "chat_message_id" uuid,
        "total_points_earned" integer NOT NULL DEFAULT 0,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_daily_reports" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_daily_reports_user_date_type" UNIQUE ("user_id", "report_date", "report_type"),
        CONSTRAINT "CHK_daily_reports_type" CHECK ("report_type" IN ('morning', 'evening')),
        CONSTRAINT "CHK_daily_reports_role" CHECK ("report_role" IN ('dev', 'qc'))
      )
    `);

    // 2. Create daily_report_items table
    await queryRunner.query(`
      CREATE TABLE "daily_report_items" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "report_id" uuid NOT NULL,
        "task_id" varchar(255) NOT NULL,
        "task_name" varchar(1000) NOT NULL,
        "project_id" integer NOT NULL,
        "project_name" varchar(255) NOT NULL,
        "status" varchar(20),
        "progress" integer,
        "qc_done" integer,
        "qc_miss" integer,
        "qc_fail" integer,
        "points_awarded" integer NOT NULL DEFAULT 0,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_daily_report_items" PRIMARY KEY ("id"),
        CONSTRAINT "FK_daily_report_items_report" FOREIGN KEY ("report_id") REFERENCES "daily_reports"("id") ON DELETE CASCADE
      )
    `);

    // 3. Add indices for Admin analytics
    await queryRunner.query(
      `CREATE INDEX "IDX_daily_report_items_task_id" ON "daily_report_items" ("task_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_daily_reports_user_date" ON "daily_reports" ("user_id", "report_date")`,
    );

    // 4. Seed Bot User
    const botUserId = '00000000-0000-0000-0000-000000000001';
    await queryRunner.query(`
      INSERT INTO "users" (id, odoo_uid, email, name, employment_status, is_active)
      VALUES ('${botUserId}', 0, 'bot@system.local', 'Task Report Bot', 'official', true)
      ON CONFLICT (id) DO NOTHING
    `);

    // 5. Add Bot User to the target conversation
    const targetConvId = '6998761a-f0db-4dfd-8d95-ecc23cfae783';
    // First, ensure the conversation exists (it should, based on requirements, but safe to check)
    const convExists = await queryRunner.query(
      `SELECT id FROM conversations WHERE id = '${targetConvId}'`,
    );
    if (convExists.length > 0) {
      await queryRunner.query(`
        INSERT INTO "conversation_members" (conv_id, user_id)
        VALUES ('${targetConvId}', '${botUserId}')
        ON CONFLICT (conv_id, user_id) DO NOTHING
      `);
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "IDX_daily_reports_user_date"`);
    await queryRunner.query(`DROP INDEX "IDX_daily_report_items_task_id"`);
    await queryRunner.query(`DROP TABLE "daily_report_items"`);
    await queryRunner.query(`DROP TABLE "daily_reports"`);

    // We don't remove the Bot User or membership in down to avoid potential FK issues or accidental data loss if it's reused.
  }
}
