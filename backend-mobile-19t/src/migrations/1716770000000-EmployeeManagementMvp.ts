import { MigrationInterface, QueryRunner } from 'typeorm';

export class EmployeeManagementMvp1716770000000 implements MigrationInterface {
  name = 'EmployeeManagementMvp1716770000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE "employee_profiles" (
      "user_id" uuid PRIMARY KEY REFERENCES "users"("id") ON DELETE CASCADE,
      "date_of_birth" date, "gender" varchar(20), "identity_number" varchar(50),
      "identity_issued_date" date, "identity_issued_place" varchar(255),
      "permanent_address" text, "current_address" text, "personal_phone" varchar(30),
      "personal_email" varchar(255), "emergency_contact_name" varchar(255),
      "emergency_contact_phone" varchar(30), "emergency_contact_relationship" varchar(100),
      "marital_status" varchar(30), "tax_code" varchar(50),
      "bank_account_number" varchar(100), "bank_name" varchar(255), "joined_at" date,
      "updated_by" uuid, "created_at" timestamptz NOT NULL DEFAULT now(),
      "updated_at" timestamptz NOT NULL DEFAULT now()
    )`);
    await queryRunner.query(`CREATE TABLE "employee_contracts" (
      "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "user_id" uuid NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
      "type" varchar(20) NOT NULL CHECK ("type" IN ('internship','probation','official','temporary')),
      "signed_date" date, "start_date" date NOT NULL, "end_date" date,
      "status" varchar(20) NOT NULL DEFAULT 'draft' CHECK ("status" IN ('draft','active','expired','terminated','renewed')),
      "notes" text, "renewed_from_id" uuid REFERENCES "employee_contracts"("id") ON DELETE SET NULL,
      "created_by" uuid NOT NULL, "updated_by" uuid,
      "created_at" timestamptz NOT NULL DEFAULT now(), "updated_at" timestamptz NOT NULL DEFAULT now(),
      CHECK ("end_date" IS NULL OR "end_date" >= "start_date")
    )`);
    await queryRunner.query(`CREATE INDEX "IDX_employee_contracts_user_start" ON "employee_contracts" ("user_id", "start_date")`);
    await queryRunner.query(`CREATE INDEX "IDX_employee_contracts_status_end" ON "employee_contracts" ("status", "end_date")`);
    await queryRunner.query(`CREATE TABLE "contract_reminder_events" (
      "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "contract_id" uuid NOT NULL REFERENCES "employee_contracts"("id") ON DELETE CASCADE,
      "threshold_days" integer NOT NULL, "reminder_date" date NOT NULL,
      "status" varchar(20) NOT NULL DEFAULT 'pending', "delivered_at" timestamptz,
      "created_at" timestamptz NOT NULL DEFAULT now()
    )`);
    await queryRunner.query(`CREATE UNIQUE INDEX "UQ_contract_reminder_event_key" ON "contract_reminder_events" ("contract_id", "threshold_days", "reminder_date")`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "contract_reminder_events"`);
    await queryRunner.query(`DROP TABLE "employee_contracts"`);
    await queryRunner.query(`DROP TABLE "employee_profiles"`);
  }
}
