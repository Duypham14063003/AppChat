import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddOtTimeColumn1714500000000 implements MigrationInterface {
  name = 'AddOtTimeColumn1714500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "leave_requests" ADD COLUMN "ot_time" decimal(4, 1) DEFAULT 0`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "leave_requests" DROP COLUMN "ot_time"`,
    );
  }
}
