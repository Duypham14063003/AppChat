import { MigrationInterface, QueryRunner } from 'typeorm';

export class MonthlyPaidLeavePolicy1713600000000 implements MigrationInterface {
  name = 'MonthlyPaidLeavePolicy1713600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD COLUMN "employment_status" varchar(20) NOT NULL DEFAULT 'official'`,
    );

    await queryRunner.query(
      `ALTER TABLE "leave_requests" ADD COLUMN "is_half_day" boolean NOT NULL DEFAULT false`,
    );
    await queryRunner.query(
      `ALTER TABLE "leave_requests" ADD COLUMN "half_day_part" varchar(20)`,
    );
    await queryRunner.query(
      `ALTER TABLE "leave_requests" ADD COLUMN "requested_days" numeric(4,1) NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `ALTER TABLE "leave_requests" ADD COLUMN "paid_days" numeric(4,1) NOT NULL DEFAULT 0`,
    );
    await queryRunner.query(
      `ALTER TABLE "leave_requests" ADD COLUMN "unpaid_days" numeric(4,1) NOT NULL DEFAULT 0`,
    );

    await queryRunner.query(`
      CREATE TABLE "monthly_leave_balances" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "user_id" uuid NOT NULL,
        "year" integer NOT NULL,
        "month" integer NOT NULL,
        "allocated_days" numeric(3,1) NOT NULL DEFAULT 1.0,
        "used_paid_days" numeric(3,1) NOT NULL DEFAULT 0,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_monthly_leave_balances" PRIMARY KEY ("id"),
        CONSTRAINT "FK_monthly_leave_balances_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "IDX_monthly_leave_balances_user_period" ON "monthly_leave_balances" ("user_id", "year", "month")`,
    );

    await queryRunner.query(`
      CREATE TABLE "leave_request_days" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "leave_request_id" uuid NOT NULL,
        "leave_date" date NOT NULL,
        "duration_days" numeric(3,1) NOT NULL,
        "half_day_part" varchar(20),
        "is_paid" boolean NOT NULL DEFAULT false,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_leave_request_days" PRIMARY KEY ("id"),
        CONSTRAINT "FK_leave_request_days_request" FOREIGN KEY ("leave_request_id")
          REFERENCES "leave_requests"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_leave_request_days_request_date" ON "leave_request_days" ("leave_request_id", "leave_date")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_leave_request_days_date" ON "leave_request_days" ("leave_date")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "IDX_leave_request_days_date"`);
    await queryRunner.query(`DROP INDEX "IDX_leave_request_days_request_date"`);
    await queryRunner.query(`DROP TABLE "leave_request_days"`);

    await queryRunner.query(
      `DROP INDEX "IDX_monthly_leave_balances_user_period"`,
    );
    await queryRunner.query(`DROP TABLE "monthly_leave_balances"`);

    await queryRunner.query(
      `ALTER TABLE "leave_requests" DROP COLUMN "unpaid_days"`,
    );
    await queryRunner.query(
      `ALTER TABLE "leave_requests" DROP COLUMN "paid_days"`,
    );
    await queryRunner.query(
      `ALTER TABLE "leave_requests" DROP COLUMN "requested_days"`,
    );
    await queryRunner.query(
      `ALTER TABLE "leave_requests" DROP COLUMN "half_day_part"`,
    );
    await queryRunner.query(
      `ALTER TABLE "leave_requests" DROP COLUMN "is_half_day"`,
    );

    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN "employment_status"`,
    );
  }
}
