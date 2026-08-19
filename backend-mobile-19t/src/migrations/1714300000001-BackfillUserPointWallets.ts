import { MigrationInterface, QueryRunner } from 'typeorm';

export class BackfillUserPointWallets1714300000001 implements MigrationInterface {
  name = 'BackfillUserPointWallets1714300000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      INSERT INTO "user_point_wallets" (
        "user_id",
        "balance",
        "lifetime_earned",
        "lifetime_spent"
      )
      SELECT
        u."id",
        0,
        0,
        0
      FROM "users" u
      ON CONFLICT ("user_id") DO NOTHING
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DELETE FROM "user_point_wallets"
      WHERE "balance" = 0
        AND "lifetime_earned" = 0
        AND "lifetime_spent" = 0
        AND "user_id" IN (SELECT "id" FROM "users")
    `);
  }
}
