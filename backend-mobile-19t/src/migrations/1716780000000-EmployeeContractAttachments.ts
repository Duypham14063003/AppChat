import { MigrationInterface, QueryRunner } from 'typeorm';

export class EmployeeContractAttachments1716780000000 implements MigrationInterface {
  name = 'EmployeeContractAttachments1716780000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "employee_contracts" ADD "attachment_url" varchar(500)`);
    await queryRunner.query(`ALTER TABLE "employee_contracts" ADD "attachment_name" varchar(255)`);
    await queryRunner.query(`ALTER TABLE "employee_contracts" ADD "attachment_mime_type" varchar(100)`);
    await queryRunner.query(`ALTER TABLE "employee_contracts" ADD "attachment_size" integer`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "employee_contracts" DROP COLUMN "attachment_size"`);
    await queryRunner.query(`ALTER TABLE "employee_contracts" DROP COLUMN "attachment_mime_type"`);
    await queryRunner.query(`ALTER TABLE "employee_contracts" DROP COLUMN "attachment_name"`);
    await queryRunner.query(`ALTER TABLE "employee_contracts" DROP COLUMN "attachment_url"`);
  }
}
