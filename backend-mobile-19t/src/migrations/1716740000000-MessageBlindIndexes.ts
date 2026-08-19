import { MigrationInterface, QueryRunner } from 'typeorm';

export class MessageBlindIndexes1716740000000 implements MigrationInterface {
  name = 'MessageBlindIndexes1716740000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "message_blind_indexes" (
        "id" BIGSERIAL NOT NULL,
        "message_id" uuid NOT NULL,
        "conv_id" uuid NOT NULL,
        "token_hash" varchar(64) NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_message_blind_indexes" PRIMARY KEY ("id"),
        CONSTRAINT "FK_message_blind_indexes_conv"
          FOREIGN KEY ("conv_id") REFERENCES "conversations"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE INDEX "IDX_message_blind_indexes_conv_hash"
      ON "message_blind_indexes" ("conv_id", "token_hash")
    `);

    await queryRunner.query(`
      CREATE INDEX "IDX_message_blind_indexes_message"
      ON "message_blind_indexes" ("message_id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "public"."IDX_message_blind_indexes_message"`,
    );
    await queryRunner.query(
      `DROP INDEX IF EXISTS "public"."IDX_message_blind_indexes_conv_hash"`,
    );
    await queryRunner.query(`DROP TABLE "message_blind_indexes"`);
  }
}
