import { MigrationInterface, QueryRunner } from 'typeorm';

export class LeaveRequests1710700000002 implements MigrationInterface {
  name = 'LeaveRequests1710700000002';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "leave_requests" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "user_id" uuid NOT NULL,
        "type" varchar(30) NOT NULL,
        "start_date" date NOT NULL,
        "end_date" date NOT NULL,
        "reason" text,
        "status" varchar(20) NOT NULL DEFAULT 'draft',
        "approved_by" uuid,
        "approved_at" timestamptz,
        "reject_reason" text,
        "odoo_synced" boolean NOT NULL DEFAULT false,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_leave_requests" PRIMARY KEY ("id"),
        CONSTRAINT "FK_leave_requests_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_leave_requests_approver" FOREIGN KEY ("approved_by")
          REFERENCES "users"("id") ON DELETE SET NULL
      )
    `);

    await queryRunner.query(
      `CREATE INDEX "IDX_leave_requests_user_created" ON "leave_requests" ("user_id", "created_at" DESC)`,
    );

    await queryRunner.query(
      `CREATE INDEX "IDX_leave_requests_status" ON "leave_requests" ("status")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "leave_requests"`);
  }
}
