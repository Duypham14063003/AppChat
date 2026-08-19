import { MigrationInterface, QueryRunner } from 'typeorm';

export class MessageReminders1714000000000 implements MigrationInterface {
  name = 'MessageReminders1714000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "message_reminders" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "conv_id" uuid NOT NULL,
        "message_id" uuid NOT NULL,
        "creator_user_id" uuid NOT NULL,
        "scope" varchar(20) NOT NULL,
        "status" varchar(20) NOT NULL DEFAULT 'pending',
        "remind_at" timestamptz NOT NULL,
        "cancelled_at" timestamptz,
        "fired_at" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_message_reminders" PRIMARY KEY ("id"),
        CONSTRAINT "FK_message_reminders_conv" FOREIGN KEY ("conv_id")
          REFERENCES "conversations"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_message_reminders_creator" FOREIGN KEY ("creator_user_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(
      `CREATE INDEX "IDX_message_reminders_conv_message" ON "message_reminders" ("conv_id", "message_id")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_message_reminders_creator_status" ON "message_reminders" ("creator_user_id", "status")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_message_reminders_pending_fire" ON "message_reminders" ("status", "remind_at")`,
    );
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_message_reminders_pending_self"
      ON "message_reminders" ("creator_user_id", "message_id", "remind_at")
      WHERE "status" = 'pending' AND "scope" = 'self'
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_message_reminders_pending_everyone"
      ON "message_reminders" ("message_id", "remind_at")
      WHERE "status" = 'pending' AND "scope" = 'everyone'
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX "UQ_message_reminders_pending_everyone"`,
    );
    await queryRunner.query(`DROP INDEX "UQ_message_reminders_pending_self"`);
    await queryRunner.query(`DROP INDEX "IDX_message_reminders_pending_fire"`);
    await queryRunner.query(
      `DROP INDEX "IDX_message_reminders_creator_status"`,
    );
    await queryRunner.query(`DROP INDEX "IDX_message_reminders_conv_message"`);
    await queryRunner.query(`DROP TABLE "message_reminders"`);
  }
}
