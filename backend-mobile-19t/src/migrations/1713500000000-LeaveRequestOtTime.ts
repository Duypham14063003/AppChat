import { MigrationInterface, QueryRunner } from 'typeorm';

export class LeaveRequestOtTime1713500000000 implements MigrationInterface {
  name = 'LeaveRequestOtTime1713500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "leave_requests" ADD COLUMN "start_time" time`,
    );
    await queryRunner.query(
      `ALTER TABLE "leave_requests" ADD COLUMN "end_time" time`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "leave_requests" DROP COLUMN "end_time"`,
    );
    await queryRunner.query(
      `ALTER TABLE "leave_requests" DROP COLUMN "start_time"`,
    );
  }
}
