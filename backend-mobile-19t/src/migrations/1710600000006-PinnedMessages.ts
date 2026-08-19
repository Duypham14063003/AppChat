import { MigrationInterface, QueryRunner } from 'typeorm';

export class PinnedMessages1710600000006 implements MigrationInterface {
  name = 'PinnedMessages1710600000006';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "pinned_messages" (
        "conv_id" uuid NOT NULL,
        "message_id" uuid NOT NULL,
        "pinned_by" uuid NOT NULL,
        "pinned_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_pinned_messages" PRIMARY KEY ("conv_id", "message_id"),
        CONSTRAINT "FK_pinned_messages_conv" FOREIGN KEY ("conv_id")
          REFERENCES "conversations"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_pinned_messages_user" FOREIGN KEY ("pinned_by")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(
      `CREATE INDEX "idx_pinned_messages_conv_at" ON "pinned_messages" ("conv_id", "pinned_at" DESC)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "idx_pinned_messages_conv_at"`);
    await queryRunner.query(`DROP TABLE "pinned_messages"`);
  }
}
