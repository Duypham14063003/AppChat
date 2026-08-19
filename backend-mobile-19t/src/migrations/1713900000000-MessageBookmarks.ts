import { MigrationInterface, QueryRunner } from 'typeorm';

export class MessageBookmarks1713900000000 implements MigrationInterface {
  name = 'MessageBookmarks1713900000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "message_bookmarks" (
        "user_id" uuid NOT NULL,
        "conv_id" uuid NOT NULL,
        "message_id" uuid NOT NULL,
        "marked_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_message_bookmarks" PRIMARY KEY ("user_id", "conv_id", "message_id"),
        CONSTRAINT "FK_message_bookmarks_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_message_bookmarks_conv" FOREIGN KEY ("conv_id")
          REFERENCES "conversations"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(
      `CREATE INDEX "IDX_message_bookmarks_user_conv_marked_at" ON "message_bookmarks" ("user_id", "conv_id", "marked_at" DESC)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX "IDX_message_bookmarks_user_conv_marked_at"`,
    );
    await queryRunner.query(`DROP TABLE "message_bookmarks"`);
  }
}
