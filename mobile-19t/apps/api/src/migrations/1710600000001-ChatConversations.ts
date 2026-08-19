import { MigrationInterface, QueryRunner } from 'typeorm';

export class ChatConversations1710600000001 implements MigrationInterface {
  name = 'ChatConversations1710600000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "conversations" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "type" varchar(10) NOT NULL DEFAULT 'DIRECT',
        "name" varchar,
        "avatar_url" text,
        "created_by" uuid NOT NULL,
        "last_message_at" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_conversations" PRIMARY KEY ("id"),
        CONSTRAINT "FK_conversations_created_by" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL
      )
    `);

    await queryRunner.query(
      `CREATE INDEX "IDX_conversations_type" ON "conversations" ("type")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_conversations_last_message_at" ON "conversations" ("last_message_at" DESC NULLS LAST)`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "conversations"`);
  }
}
