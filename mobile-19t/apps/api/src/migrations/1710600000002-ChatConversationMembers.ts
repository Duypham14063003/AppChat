import { MigrationInterface, QueryRunner } from 'typeorm';

export class ChatConversationMembers1710600000002 implements MigrationInterface {
  name = 'ChatConversationMembers1710600000002';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "conversation_members" (
        "conv_id" uuid NOT NULL,
        "user_id" uuid NOT NULL,
        "role" varchar(10) NOT NULL DEFAULT 'member',
        "last_read_message_id" uuid,
        "last_read_at" timestamptz,
        "is_muted" boolean NOT NULL DEFAULT false,
        "joined_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_conversation_members" PRIMARY KEY ("conv_id", "user_id"),
        CONSTRAINT "FK_conversation_members_conv" FOREIGN KEY ("conv_id") REFERENCES "conversations"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_conversation_members_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(
      `CREATE INDEX "IDX_conversation_members_user_id" ON "conversation_members" ("user_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_conversation_members_conv_id" ON "conversation_members" ("conv_id")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "conversation_members"`);
  }
}
