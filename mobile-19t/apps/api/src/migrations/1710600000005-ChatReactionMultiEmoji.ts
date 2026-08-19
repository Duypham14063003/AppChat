import { MigrationInterface, QueryRunner } from 'typeorm';

export class ChatReactionMultiEmoji1710600000005 implements MigrationInterface {
  name = 'ChatReactionMultiEmoji1710600000005';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Drop old PK (message_id, user_id) to allow multi-reaction per user
    await queryRunner.query(
      `ALTER TABLE "message_reactions" DROP CONSTRAINT "PK_message_reactions"`,
    );

    // Add new composite PK including emoji
    await queryRunner.query(
      `ALTER TABLE "message_reactions" ADD CONSTRAINT "PK_message_reactions" PRIMARY KEY ("message_id", "user_id", "emoji")`,
    );

    // Index for fast lookup by message_id
    await queryRunner.query(
      `CREATE INDEX "idx_reactions_message_id" ON "message_reactions" ("message_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "idx_reactions_message_id"`);

    await queryRunner.query(
      `ALTER TABLE "message_reactions" DROP CONSTRAINT "PK_message_reactions"`,
    );

    // Restore old PK — may fail if duplicate (message_id, user_id) rows exist
    await queryRunner.query(
      `ALTER TABLE "message_reactions" ADD CONSTRAINT "PK_message_reactions" PRIMARY KEY ("message_id", "user_id")`,
    );
  }
}
