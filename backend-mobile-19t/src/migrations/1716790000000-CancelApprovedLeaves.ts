import { MigrationInterface, QueryRunner } from 'typeorm';

export class CancelApprovedLeaves1716790000000 implements MigrationInterface {
  name = 'CancelApprovedLeaves1716790000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "leave_requests"
      ADD COLUMN "cancelled_by" uuid,
      ADD COLUMN "cancelled_at" TIMESTAMP WITH TIME ZONE,
      ADD COLUMN "cancel_reason" text
    `);
    await queryRunner.query(`
      ALTER TABLE "leave_requests"
      ADD CONSTRAINT "FK_leave_requests_cancelled_by"
      FOREIGN KEY ("cancelled_by") REFERENCES "users"("id")
      ON DELETE SET NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "leave_requests"
      DROP CONSTRAINT "FK_leave_requests_cancelled_by"
    `);
    await queryRunner.query(`
      ALTER TABLE "leave_requests"
      DROP COLUMN "cancel_reason",
      DROP COLUMN "cancelled_at",
      DROP COLUMN "cancelled_by"
    `);
  }
}
