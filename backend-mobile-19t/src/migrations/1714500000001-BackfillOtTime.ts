import { MigrationInterface, QueryRunner } from 'typeorm';

export class BackfillOtTime1714500000001 implements MigrationInterface {
  name = 'BackfillOtTime1714500000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Logic: (end_date - start_date + 1) * hours_per_day
    // hours_per_day = (end_time - start_time) in hours
    await queryRunner.query(`
      UPDATE "leave_requests"
      SET "ot_time" = ROUND(
        CAST(
          (CAST("end_date" AS date) - CAST("start_date" AS date) + 1) * 
          (EXTRACT(EPOCH FROM (CAST("end_time" AS time) - CAST("start_time" AS time))) / 3600)
        AS numeric), 
        1
      )
      WHERE "type" = 'ot' 
        AND "start_time" IS NOT NULL 
        AND "end_time" IS NOT NULL
        AND ("ot_time" IS NULL OR "ot_time" = 0);
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // No easy way to revert backfill without losing manually entered data, 
    // but we can reset the calculated ones if needed. 
    // For safety, we do nothing or just leave it.
  }
}
