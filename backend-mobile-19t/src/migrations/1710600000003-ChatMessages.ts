import { MigrationInterface, QueryRunner } from 'typeorm';

export class ChatMessages1710600000003 implements MigrationInterface {
  name = 'ChatMessages1710600000003';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Partitioned messages table
    await queryRunner.query(`
      CREATE TABLE "messages" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "conv_id" uuid NOT NULL,
        "sender_id" uuid NOT NULL,
        "type" varchar(20) NOT NULL DEFAULT 'text',
        "content" text,
        "reply_to_id" uuid,
        "forwarded_from_id" uuid,
        "forwarded_from_sender" varchar,
        "metadata" jsonb,
        "search_vector" tsvector GENERATED ALWAYS AS (to_tsvector('simple', coalesce("content", ''))) STORED,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "edited_at" timestamptz,
        "deleted_at" timestamptz,
        CONSTRAINT "PK_messages" PRIMARY KEY ("id", "created_at")
      ) PARTITION BY RANGE ("created_at")
    `);

    // Q1 2026 partition (Jan-Mar)
    await queryRunner.query(`
      CREATE TABLE "messages_2026_q1" PARTITION OF "messages"
        FOR VALUES FROM ('2026-01-01') TO ('2026-04-01')
    `);

    // Q2 2026 partition (Apr-Jun)
    await queryRunner.query(`
      CREATE TABLE "messages_2026_q2" PARTITION OF "messages"
        FOR VALUES FROM ('2026-04-01') TO ('2026-07-01')
    `);

    // Timeline index
    await queryRunner.query(`
      CREATE INDEX "IDX_messages_conv_timeline" ON "messages" ("conv_id", "created_at" DESC)
        WHERE "deleted_at" IS NULL
    `);

    // Full-text search index
    await queryRunner.query(
      `CREATE INDEX "IDX_messages_search_vector" ON "messages" USING GIN ("search_vector")`,
    );

    // Reply lookup index
    await queryRunner.query(`
      CREATE INDEX "IDX_messages_reply_to" ON "messages" ("reply_to_id")
        WHERE "reply_to_id" IS NOT NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "messages" CASCADE`);
  }
}
