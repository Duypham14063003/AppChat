import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreatePointPeriodHistoryTable1714600000000 implements MigrationInterface {
  name = 'CreatePointPeriodHistoryTable1714600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "point_period_history" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "period" varchar(7) NOT NULL,
        "points_earned" integer NOT NULL DEFAULT 0,
        "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_point_period_history" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_point_period_history_user_period" UNIQUE ("user_id", "period")
      )
    `);

    await queryRunner.query(`
      CREATE INDEX "IDX_point_period_history_user_id" ON "point_period_history" ("user_id")
    `);

    await queryRunner.query(`
      ALTER TABLE "point_period_history" 
      ADD CONSTRAINT "FK_point_period_history_user" 
      FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "point_period_history" DROP CONSTRAINT "FK_point_period_history_user"`);
    await queryRunner.query(`DROP INDEX "IDX_point_period_history_user_id"`);
    await queryRunner.query(`DROP TABLE "point_period_history"`);
  }
}
