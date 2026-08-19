import { MigrationInterface, QueryRunner } from 'typeorm';

export class LeaveRequestOtTimes1710700000004 implements MigrationInterface {
  name = 'LeaveRequestOtTimes1710700000004';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "leave_requests" ADD COLUMN "start_time" varchar(5)`,
    );
    await queryRunner.query(
      `ALTER TABLE "leave_requests" ADD COLUMN "end_time" varchar(5)`,
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
