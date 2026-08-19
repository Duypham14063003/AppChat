import { MigrationInterface, QueryRunner } from 'typeorm';

export class PrepopulateYearlyBalances1715000000001 implements MigrationInterface {
  name = 'PrepopulateYearlyBalances1715000000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // We target the current year 2026
    const currentYear = 2026;

    // Insert records for all active official employees who don't have a balance record yet for the current year.
    // We use ON CONFLICT DO NOTHING to ensure we don't overwrite existing migrated data.
    await queryRunner.query(`
      INSERT INTO "yearly_leave_balances" (user_id, "year", allocated_days, used_paid_days)
      SELECT 
        id as user_id, 
        ${currentYear} as year, 
        12.0 as allocated_days, 
        0.0 as used_paid_days
      FROM "users"
      WHERE is_active = true 
        AND employment_status = 'official'
      ON CONFLICT (user_id, "year") DO NOTHING
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // No specific down action needed as this only populates missing data.
    // Deleting records blindly might remove valid user data created since migration.
  }
}
