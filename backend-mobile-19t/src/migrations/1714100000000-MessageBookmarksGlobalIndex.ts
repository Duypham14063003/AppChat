import { MigrationInterface, QueryRunner } from 'typeorm';

export class MessageBookmarksGlobalIndex1714100000000 implements MigrationInterface {
  name = 'MessageBookmarksGlobalIndex1714100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `CREATE INDEX "IDX_message_bookmarks_user_marked_at_message_id" ON "message_bookmarks" ("user_id", "marked_at" DESC, "message_id" DESC)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX "IDX_message_bookmarks_user_marked_at_message_id"`,
    );
  }
}
