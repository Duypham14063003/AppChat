import { MigrationInterface, QueryRunner } from 'typeorm';

export class ConversationEncryptionKeys1714400000000
  implements MigrationInterface
{
  name = 'ConversationEncryptionKeys1714400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "conversation_encryption_keys" (
        "conv_id" uuid NOT NULL,
        "key_id" varchar(255) NOT NULL,
        "alg" varchar(50) NOT NULL DEFAULT 'AES-256-GCM',
        "version" integer NOT NULL DEFAULT 1,
        "material" bytea NOT NULL,
        "is_active" boolean NOT NULL DEFAULT true,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_conversation_encryption_keys" PRIMARY KEY ("conv_id", "key_id"),
        CONSTRAINT "FK_conversation_encryption_keys_conv" FOREIGN KEY ("conv_id") REFERENCES "conversations"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE UNIQUE INDEX "IDX_conversation_encryption_keys_active"
      ON "conversation_encryption_keys" ("conv_id")
      WHERE "is_active" = true
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "conversation_encryption_keys"`);
  }
}
