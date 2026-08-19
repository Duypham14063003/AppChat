import { MigrationInterface, QueryRunner } from 'typeorm';

export class ChatMessageReactions1710600000004 implements MigrationInterface {
  name = 'ChatMessageReactions1710600000004';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "message_reactions" (
        "message_id" uuid NOT NULL,
        "user_id" uuid NOT NULL,
        "emoji" varchar(10) NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_message_reactions" PRIMARY KEY ("message_id", "user_id"),
        CONSTRAINT "FK_message_reactions_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "message_reactions"`);
  }
}
