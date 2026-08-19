import { MigrationInterface, QueryRunner } from 'typeorm';

export class InternalRoleMappingSystem1714900000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Create internal_roles table
    await queryRunner.query(`
      CREATE TABLE "internal_roles" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "name" varchar(100) NOT NULL,
        "multiplier" decimal(5,2) NOT NULL DEFAULT '1.00',
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_internal_roles" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_internal_roles_name" UNIQUE ("name")
      )
    `);

    // 2. Create job_title_mappings table
    await queryRunner.query(`
      CREATE TABLE "job_title_mappings" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "odoo_job_title" varchar(255) NOT NULL,
        "internal_role_id" uuid NOT NULL,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        "updated_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_job_title_mappings" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_job_title_mappings_odoo_job_title" UNIQUE ("odoo_job_title"),
        CONSTRAINT "FK_job_title_mappings_internal_role" FOREIGN KEY ("internal_role_id") 
          REFERENCES "internal_roles"("id") ON DELETE CASCADE
      )
    `);

    // 3. Migrate data from job_title_multipliers if it exists
    const hasLegacyTable = await queryRunner.hasTable('job_title_multipliers');
    if (hasLegacyTable) {
      // Insert existing multipliers into internal_roles
      await queryRunner.query(`
        INSERT INTO "internal_roles" ("name", "multiplier")
        SELECT "job_title", "multiplier" FROM "job_title_multipliers"
        ON CONFLICT ("name") DO NOTHING
      `);

      // Create initial mappings
      await queryRunner.query(`
        INSERT INTO "job_title_mappings" ("odoo_job_title", "internal_role_id")
        SELECT jtm."job_title", ir."id"
        FROM "job_title_multipliers" jtm
        JOIN "internal_roles" ir ON ir."name" = jtm."job_title"
        ON CONFLICT ("odoo_job_title") DO NOTHING
      `);
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "job_title_mappings"`);
    await queryRunner.query(`DROP TABLE "internal_roles"`);
  }
}
