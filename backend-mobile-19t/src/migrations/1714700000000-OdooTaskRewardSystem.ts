import { MigrationInterface, QueryRunner } from 'typeorm';

export class OdooTaskRewardSystem1714700000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. odoo_task_tag_configs
    await queryRunner.query(`
      CREATE TABLE "odoo_task_tag_configs" (
        "id" integer NOT NULL,
        "tag_name" varchar(100) NOT NULL,
        "base_points" integer NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_odoo_task_tag_configs" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "IDX_odoo_task_tag_configs_tag_name" ON "odoo_task_tag_configs" ("tag_name")`,
    );

    // 2. job_title_multipliers
    await queryRunner.query(`
      CREATE TABLE "job_title_multipliers" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "job_title" varchar(100) NOT NULL,
        "multiplier" decimal(5,2) NOT NULL DEFAULT '1.00',
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_job_title_multipliers" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "IDX_job_title_multipliers_job_title" ON "job_title_multipliers" ("job_title")`,
    );

    // 3. odoo_task_reward_logs
    await queryRunner.query(`
      CREATE TABLE "odoo_task_reward_logs" (
        "task_id" integer NOT NULL,
        "user_id" uuid NOT NULL,
        "points" integer NOT NULL,
        "is_miss" boolean NOT NULL DEFAULT false,
        "rewarded_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_odoo_task_reward_logs" PRIMARY KEY ("task_id")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "IDX_odoo_task_reward_logs_user_id" ON "odoo_task_reward_logs" ("user_id")`,
    );
    await queryRunner.query(`
      ALTER TABLE "odoo_task_reward_logs" 
      ADD CONSTRAINT "FK_odoo_task_reward_logs_user" 
      FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "odoo_task_reward_logs" DROP CONSTRAINT "FK_odoo_task_reward_logs_user"`,
    );
    await queryRunner.query(`DROP INDEX "IDX_odoo_task_reward_logs_user_id"`);
    await queryRunner.query(`DROP TABLE "odoo_task_reward_logs"`);
    await queryRunner.query(`DROP INDEX "IDX_job_title_multipliers_job_title"`);
    await queryRunner.query(`DROP TABLE "job_title_multipliers"`);
    await queryRunner.query(`DROP INDEX "IDX_odoo_task_tag_configs_tag_name"`);
    await queryRunner.query(`DROP TABLE "odoo_task_tag_configs"`);
  }
}
