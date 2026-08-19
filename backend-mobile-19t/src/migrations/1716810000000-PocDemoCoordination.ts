import { MigrationInterface, QueryRunner } from 'typeorm';

export class PocDemoCoordination1716810000000 implements MigrationInterface {
  name = 'PocDemoCoordination1716810000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE SEQUENCE "poc_code_sequence" START 1`);
    await queryRunner.query(`
      CREATE TABLE "pocs" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "sequence_number" bigint UNIQUE,
        "code" varchar(120) UNIQUE,
        "customer_name" varchar(255) NOT NULL,
        "title" varchar(255) NOT NULL,
        "requirement" text NOT NULL,
        "product_type" varchar(30) NOT NULL CHECK ("product_type" IN ('website','web_app','validation')),
        "priority" varchar(20) NOT NULL DEFAULT 'normal' CHECK ("priority" IN ('low','normal','high','urgent')),
        "sale_user_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE RESTRICT,
        "developer_user_id" uuid REFERENCES "users"("id") ON DELETE SET NULL,
        "assigned_by_user_id" uuid REFERENCES "users"("id") ON DELETE SET NULL,
        "working_conversation_id" uuid REFERENCES "conversations"("id") ON DELETE SET NULL,
        "source_message_id" uuid,
        "planned_start_at" timestamptz,
        "estimated_hours" numeric(8,2),
        "demo_at" timestamptz NOT NULL,
        "status" varchar(20) NOT NULL DEFAULT 'unassigned' CHECK ("status" IN ('unassigned','assigned','in_progress','ready','demonstrated','cancelled')),
        "outcome" varchar(30) CHECK ("outcome" IS NULL OR "outcome" IN ('completed','revision_required','not_proceeding')),
        "poc_url" varchar(1000),
        "reference_links" jsonb NOT NULL DEFAULT '[]'::jsonb,
        "cancel_reason" text,
        "ready_at" timestamptz,
        "demonstrated_at" timestamptz,
        "version" integer NOT NULL DEFAULT 1,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "CHK_pocs_assignment_plan" CHECK (
          ("developer_user_id" IS NULL AND "planned_start_at" IS NULL AND "estimated_hours" IS NULL)
          OR ("developer_user_id" IS NOT NULL AND "planned_start_at" IS NOT NULL AND "estimated_hours" > 0 AND "planned_start_at" < "demo_at")
        )
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_pocs_demo_status" ON "pocs" ("demo_at", "status")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_pocs_developer_plan" ON "pocs" ("developer_user_id", "planned_start_at", "demo_at")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_pocs_sale_created" ON "pocs" ("sale_user_id", "created_at")`,
    );

    await queryRunner.query(`
      CREATE TABLE "poc_history" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "poc_id" uuid NOT NULL REFERENCES "pocs"("id") ON DELETE CASCADE,
        "actor_user_id" uuid REFERENCES "users"("id") ON DELETE SET NULL,
        "event_type" varchar(80) NOT NULL,
        "previous_values" jsonb,
        "new_values" jsonb,
        "created_at" timestamptz NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_poc_history_poc_created" ON "poc_history" ("poc_id", "created_at")`,
    );

    await queryRunner.query(`
      CREATE TABLE "poc_notification_events" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "poc_id" uuid NOT NULL REFERENCES "pocs"("id") ON DELETE CASCADE,
        "event_kind" varchar(50) NOT NULL,
        "scheduled_at" timestamptz NOT NULL,
        "status" varchar(20) NOT NULL DEFAULT 'processing' CHECK ("status" IN ('processing','delivered','failed','skipped')),
        "attempts" integer NOT NULL DEFAULT 0,
        "delivered_at" timestamptz,
        "last_error" text,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_poc_notification_delivery" UNIQUE ("poc_id", "event_kind", "scheduled_at")
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "poc_weekly_reports" (
        "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        "iso_year" integer NOT NULL,
        "iso_week" integer NOT NULL CHECK ("iso_week" BETWEEN 1 AND 53),
        "conversation_id" uuid NOT NULL REFERENCES "conversations"("id") ON DELETE RESTRICT,
        "chat_message_id" uuid,
        "status" varchar(20) NOT NULL DEFAULT 'draft' CHECK ("status" IN ('draft','published','failed')),
        "snapshot" jsonb NOT NULL DEFAULT '{}'::jsonb,
        "published_at" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "UQ_poc_weekly_report_week" UNIQUE ("iso_year", "iso_week")
      )
    `);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "poc_weekly_reports"`);
    await queryRunner.query(`DROP TABLE "poc_notification_events"`);
    await queryRunner.query(`DROP TABLE "poc_history"`);
    await queryRunner.query(`DROP TABLE "pocs"`);
    await queryRunner.query(`DROP SEQUENCE "poc_code_sequence"`);
  }
}
