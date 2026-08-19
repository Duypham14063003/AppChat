import { MigrationInterface, QueryRunner } from 'typeorm';

export class EmployeeBankQr1716800000000 implements MigrationInterface {
  name = 'EmployeeBankQr1716800000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "employee_profiles" ADD COLUMN "bank_code" varchar(20)`,
    );
    await queryRunner.query(
      `ALTER TABLE "employee_profiles" ADD COLUMN "bank_account_name" varchar(255)`,
    );
    await queryRunner.query(
      `ALTER TABLE "employee_profiles" ADD COLUMN "bank_qr_image_url" varchar(500)`,
    );
    await queryRunner.query(
      `ALTER TABLE "employee_profiles" ADD COLUMN "bank_qr_source" varchar(20)`,
    );
    await queryRunner.query(
      `ALTER TABLE "employee_profiles" ADD CONSTRAINT "CHK_employee_profiles_bank_qr_source" CHECK ("bank_qr_source" IS NULL OR "bank_qr_source" IN ('generated', 'uploaded'))`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "employee_profiles" DROP CONSTRAINT "CHK_employee_profiles_bank_qr_source"`,
    );
    await queryRunner.query(
      `ALTER TABLE "employee_profiles" DROP COLUMN "bank_qr_source"`,
    );
    await queryRunner.query(
      `ALTER TABLE "employee_profiles" DROP COLUMN "bank_qr_image_url"`,
    );
    await queryRunner.query(
      `ALTER TABLE "employee_profiles" DROP COLUMN "bank_account_name"`,
    );
    await queryRunner.query(
      `ALTER TABLE "employee_profiles" DROP COLUMN "bank_code"`,
    );
  }
}
