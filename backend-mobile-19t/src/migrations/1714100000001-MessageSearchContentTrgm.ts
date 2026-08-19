import { MigrationInterface, QueryRunner } from 'typeorm';

export class MessageSearchContentTrgm1714100000001 implements MigrationInterface {
  name = 'MessageSearchContentTrgm1714100000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE INDEX "IDX_messages_content_trgm"
      ON "messages"
      USING GIN (coalesce("content", '') gin_trgm_ops)
      WHERE "deleted_at" IS NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "public"."IDX_messages_content_trgm"`);
  }
}
