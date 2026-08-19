import { MigrationInterface, QueryRunner } from 'typeorm';

export class EmployeeRewardsSystem1714300000000 implements MigrationInterface {
  name = 'EmployeeRewardsSystem1714300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "user_point_wallets" (
        "user_id" uuid NOT NULL,
        "balance" int NOT NULL DEFAULT 0,
        "lifetime_earned" int NOT NULL DEFAULT 0,
        "lifetime_spent" int NOT NULL DEFAULT 0,
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_user_point_wallets" PRIMARY KEY ("user_id"),
        CONSTRAINT "FK_user_point_wallets_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE TABLE "point_rules" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "code" varchar(100) NOT NULL,
        "name" varchar(150) NOT NULL,
        "description" text,
        "trigger_type" varchar(40) NOT NULL,
        "points" int NOT NULL,
        "is_active" boolean NOT NULL DEFAULT false,
        "created_by" uuid,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_point_rules" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_point_rules_code" UNIQUE ("code"),
        CONSTRAINT "FK_point_rules_created_by" FOREIGN KEY ("created_by")
          REFERENCES "users"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_point_rules_trigger_type" ON "point_rules" ("trigger_type")`,
    );

    await queryRunner.query(`
      CREATE TABLE "point_transactions" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "user_id" uuid NOT NULL,
        "rule_id" uuid,
        "created_by" uuid,
        "type" varchar(20) NOT NULL,
        "source_type" varchar(40) NOT NULL,
        "source_ref_id" varchar(100),
        "event_key" varchar(150),
        "points" int NOT NULL,
        "balance_after" int NOT NULL,
        "note" text,
        "metadata" jsonb,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_point_transactions" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_point_transactions_event_key" UNIQUE ("event_key"),
        CONSTRAINT "FK_point_transactions_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_point_transactions_rule" FOREIGN KEY ("rule_id")
          REFERENCES "point_rules"("id") ON DELETE SET NULL,
        CONSTRAINT "FK_point_transactions_created_by" FOREIGN KEY ("created_by")
          REFERENCES "users"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_point_transactions_user_created" ON "point_transactions" ("user_id", "created_at" DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_point_transactions_source_type" ON "point_transactions" ("source_type")`,
    );

    await queryRunner.query(`
      CREATE TABLE "reward_items" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "name" varchar(150) NOT NULL,
        "description" text,
        "image_url" text,
        "points_cost" int NOT NULL,
        "stock_total" int,
        "stock_remaining" int,
        "is_active" boolean NOT NULL DEFAULT true,
        "sort_order" int NOT NULL DEFAULT 0,
        "metadata" jsonb,
        "created_by" uuid,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_reward_items" PRIMARY KEY ("id"),
        CONSTRAINT "FK_reward_items_created_by" FOREIGN KEY ("created_by")
          REFERENCES "users"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_reward_items_active_sort" ON "reward_items" ("is_active", "sort_order")`,
    );

    await queryRunner.query(`
      CREATE TABLE "reward_redemptions" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "user_id" uuid NOT NULL,
        "reward_item_id" uuid NOT NULL,
        "quantity" int NOT NULL DEFAULT 1,
        "unit_points_cost" int NOT NULL,
        "total_points_cost" int NOT NULL,
        "status" varchar(20) NOT NULL DEFAULT 'pending',
        "requested_note" text,
        "processed_note" text,
        "processed_by" uuid,
        "processed_at" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_reward_redemptions" PRIMARY KEY ("id"),
        CONSTRAINT "FK_reward_redemptions_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_reward_redemptions_reward_item" FOREIGN KEY ("reward_item_id")
          REFERENCES "reward_items"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_reward_redemptions_processed_by" FOREIGN KEY ("processed_by")
          REFERENCES "users"("id") ON DELETE SET NULL
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_reward_redemptions_user_created" ON "reward_redemptions" ("user_id", "created_at" DESC)`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_reward_redemptions_status_created" ON "reward_redemptions" ("status", "created_at" DESC)`,
    );

    await queryRunner.query(`
      INSERT INTO "point_rules" ("code", "name", "description", "trigger_type", "points", "is_active")
      VALUES
        ('attendance-checkin-default', 'Attendance check-in reward', 'Default seeded rule for successful attendance check-in rewards.', 'attendance_checkin', 5, false),
        ('attendance-checkout-default', 'Attendance check-out reward', 'Default seeded rule for successful attendance check-out rewards.', 'attendance_checkout', 5, false),
        ('attendance-auto-checkout-default', 'Attendance auto-checkout reward', 'Default seeded rule for automatic checkout rewards.', 'attendance_auto_checkout', 1, false)
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX "IDX_reward_redemptions_status_created"`,
    );
    await queryRunner.query(`DROP INDEX "IDX_reward_redemptions_user_created"`);
    await queryRunner.query(`DROP TABLE "reward_redemptions"`);
    await queryRunner.query(`DROP INDEX "IDX_reward_items_active_sort"`);
    await queryRunner.query(`DROP TABLE "reward_items"`);
    await queryRunner.query(`DROP INDEX "IDX_point_transactions_source_type"`);
    await queryRunner.query(`DROP INDEX "IDX_point_transactions_user_created"`);
    await queryRunner.query(`DROP TABLE "point_transactions"`);
    await queryRunner.query(`DROP INDEX "IDX_point_rules_trigger_type"`);
    await queryRunner.query(`DROP TABLE "point_rules"`);
    await queryRunner.query(`DROP TABLE "user_point_wallets"`);
  }
}
