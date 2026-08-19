import { MigrationInterface, QueryRunner } from 'typeorm';

export class WfhQuotaSystem1716720000000 implements MigrationInterface {
  name = 'WfhQuotaSystem1716720000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "company_wfh_yearly_configs" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "year" integer NOT NULL,
        "allocated_days" numeric(4,1) NOT NULL DEFAULT '0',
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_company_wfh_yearly_configs" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "IDX_company_wfh_yearly_configs_year"
      ON "company_wfh_yearly_configs" ("year")
    `);

    await queryRunner.query(`
      CREATE TABLE "yearly_wfh_balances" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "year" integer NOT NULL,
        "allocated_days" numeric(4,1) NOT NULL DEFAULT '0',
        "used_days" numeric(4,1) NOT NULL DEFAULT '0',
        "is_override" boolean NOT NULL DEFAULT false,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        CONSTRAINT "PK_yearly_wfh_balances" PRIMARY KEY ("id"),
        CONSTRAINT "FK_yearly_wfh_balances_user"
          FOREIGN KEY ("user_id") REFERENCES "users"("id")
          ON DELETE CASCADE ON UPDATE NO ACTION
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "IDX_yearly_wfh_balances_user_year"
      ON "yearly_wfh_balances" ("user_id", "year")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DROP INDEX IF EXISTS "IDX_yearly_wfh_balances_user_year"`,
    );
    await queryRunner.query(`DROP TABLE "yearly_wfh_balances"`);
    await queryRunner.query(
      `DROP INDEX IF EXISTS "IDX_company_wfh_yearly_configs_year"`,
    );
    await queryRunner.query(`DROP TABLE "company_wfh_yearly_configs"`);
  }
}
