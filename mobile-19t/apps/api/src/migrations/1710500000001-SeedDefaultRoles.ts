import { MigrationInterface, QueryRunner } from 'typeorm';

export class SeedDefaultRoles1710500000001 implements MigrationInterface {
  name = 'SeedDefaultRoles1710500000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      INSERT INTO "roles" ("name", "description") VALUES
        ('admin', 'Full system access'),
        ('manager', 'Team management, approve leaves, view team data'),
        ('employee', 'Personal data access and chat')
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DELETE FROM "roles" WHERE "name" IN ('admin', 'manager', 'employee')`,
    );
  }
}
