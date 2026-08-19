import { MigrationInterface, QueryRunner } from 'typeorm';

export class Attendance1710700000001 implements MigrationInterface {
  name = 'Attendance1710700000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "attendance" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "user_id" uuid NOT NULL,
        "checkin_at" timestamptz NOT NULL,
        "checkout_at" timestamptz,
        "checkin_lat" decimal(10,7),
        "checkin_lng" decimal(10,7),
        "checkout_lat" decimal(10,7),
        "checkout_lng" decimal(10,7),
        "device_id" varchar(255),
        "total_hours" decimal(4,2),
        "ot_hours" decimal(4,2),
        "odoo_synced" boolean NOT NULL DEFAULT false,
        "odoo_synced_at" timestamptz,
        "created_at" timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT "PK_attendance" PRIMARY KEY ("id"),
        CONSTRAINT "FK_attendance_user" FOREIGN KEY ("user_id")
          REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(
      `CREATE INDEX "IDX_attendance_user_checkin" ON "attendance" ("user_id", "checkin_at" DESC)`,
    );

    await queryRunner.query(
      `CREATE INDEX "IDX_attendance_odoo_synced" ON "attendance" ("odoo_synced") WHERE "odoo_synced" = false`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "attendance"`);
  }
}
