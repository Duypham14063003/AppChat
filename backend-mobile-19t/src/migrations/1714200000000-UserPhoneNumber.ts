import { MigrationInterface, QueryRunner } from 'typeorm';

export class UserPhoneNumber1714200000000 implements MigrationInterface {
  name = 'UserPhoneNumber1714200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users"
      ADD COLUMN "phone_number" varchar(30)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "users"
      DROP COLUMN "phone_number"
    `);
  }
}
