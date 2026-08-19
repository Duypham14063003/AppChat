import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddVoipTokenToUserSessions1716610000000 implements MigrationInterface {
  name = 'AddVoipTokenToUserSessions1716610000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "user_sessions"
      ADD COLUMN "voip_token" text
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "user_sessions"
      DROP COLUMN "voip_token"
    `);
  }
}
