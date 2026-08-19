import { MigrationInterface, QueryRunner } from 'typeorm';

export class YearlyLeaveBalance1715000000000 implements MigrationInterface {
  name = 'YearlyLeaveBalance1715000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Create the new table
    await queryRunner.query(`
      CREATE TABLE "yearly_leave_balances" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "year" integer NOT NULL,
        "allocated_days" numeric(4,1) NOT NULL DEFAULT '12.0',
        "used_paid_days" numeric(4,1) NOT NULL DEFAULT '0.0',
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_yearly_leave_balances" PRIMARY KEY ("id")
      )
    `);

    // 2. Add index
    await queryRunner.query(`
      CREATE UNIQUE INDEX "IDX_yearly_leave_balances_user_year" 
      ON "yearly_leave_balances" ("user_id", "year")
    `);

    // 3. Add foreign key
    await queryRunner.query(`
      ALTER TABLE "yearly_leave_balances" 
      ADD CONSTRAINT "FK_yearly_leave_balances_user" 
      FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
    `);

    // 4. Data Migration: Aggregate monthly usage into yearly usage
    // We only migrate official employees as they are the ones eligible for paid leave in the current system.
    await queryRunner.query(`
      INSERT INTO "yearly_leave_balances" (user_id, year, used_paid_days, allocated_days)
      SELECT 
        user_id, 
        year, 
        SUM(used_paid_days) as used_paid_days,
        12.0 as allocated_days
      FROM monthly_leave_balances
      GROUP BY user_id, year
      ON CONFLICT (user_id, year) DO UPDATE SET
        used_paid_days = EXCLUDED.used_paid_days
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "yearly_leave_balances" DROP CONSTRAINT "FK_yearly_leave_balances_user"`);
    await queryRunner.query(`DROP INDEX "IDX_yearly_leave_balances_user_year"`);
    await queryRunner.query(`DROP TABLE "yearly_leave_balances"`);
  }
}
