import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateAuditLogsTable1716760000000 implements MigrationInterface {
  name = 'CreateAuditLogsTable1716760000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "audit_logs" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "category" varchar(100) NOT NULL,
        "event_type" varchar(150) NOT NULL,
        "user_id" uuid,
        "entity_type" varchar(100),
        "entity_id" varchar(255),
        "status" varchar(100),
        "reason" varchar(255),
        "email" varchar(255),
        "ip" varchar(100),
        "user_agent" text,
        "metadata" jsonb,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_audit_logs" PRIMARY KEY ("id")
      )
    `);

    await queryRunner.query(`
      CREATE INDEX "IDX_audit_logs_category_created_at"
      ON "audit_logs" ("category", "created_at")
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_audit_logs_user_id_created_at"
      ON "audit_logs" ("user_id", "created_at")
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_audit_logs_entity"
      ON "audit_logs" ("entity_type", "entity_id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "IDX_audit_logs_entity"`);
    await queryRunner.query(`DROP INDEX "IDX_audit_logs_user_id_created_at"`);
    await queryRunner.query(`DROP INDEX "IDX_audit_logs_category_created_at"`);
    await queryRunner.query(`DROP TABLE "audit_logs"`);
  }
}
