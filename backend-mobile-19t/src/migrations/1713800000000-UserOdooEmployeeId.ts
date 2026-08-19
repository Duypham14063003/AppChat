import { MigrationInterface, QueryRunner } from 'typeorm';

export class UserOdooEmployeeId1713800000000 implements MigrationInterface {
  name = 'UserOdooEmployeeId1713800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN "odoo_employee_id" integer
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "IDX_users_odoo_employee_id"
      ON "users" ("odoo_employee_id")
      WHERE "odoo_employee_id" IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "IDX_users_odoo_employee_id"`);
    await queryRunner.query(`
      ALTER TABLE "users"
      DROP COLUMN "odoo_employee_id"
    `);
  }
}
