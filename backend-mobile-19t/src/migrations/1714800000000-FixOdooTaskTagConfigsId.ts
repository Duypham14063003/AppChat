import { MigrationInterface, QueryRunner } from 'typeorm';

export class FixOdooTaskTagConfigsId1714800000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Xóa ràng buộc khóa chính cũ (thường là PK_odoo_task_tag_configs)
    await queryRunner.query(`
      ALTER TABLE "odoo_task_tag_configs" DROP CONSTRAINT IF EXISTS "PK_odoo_task_tag_configs";
    `);

    // 2. Xử lý cột "id " (có dấu cách) nếu tồn tại
    await queryRunner.query(`
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'odoo_task_tag_configs' AND column_name = 'id ') THEN
          ALTER TABLE "odoo_task_tag_configs" DROP COLUMN "id ";
        END IF;
      END $$;
    `);

    // 3. Xử lý cột "id" (không dấu cách) nếu tồn tại (vì nó đang là uuid)
    await queryRunner.query(`
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'odoo_task_tag_configs' AND column_name = 'id') THEN
          ALTER TABLE "odoo_task_tag_configs" DROP COLUMN "id";
        END IF;
      END $$;
    `);

    // 4. Tạo lại cột "id" với kiểu integer
    // Nếu bạn muốn nó tự động tăng, hãy dùng SERIAL hoặc GENERATED ALWAYS AS IDENTITY
    await queryRunner.query(`
      ALTER TABLE "odoo_task_tag_configs" ADD "id" integer NOT NULL;
    `);

    // 5. Thiết lập lại khóa chính
    await queryRunner.query(`
      ALTER TABLE "odoo_task_tag_configs" ADD CONSTRAINT "PK_odoo_task_tag_configs" PRIMARY KEY ("id");
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Không cần thực hiện gì đặc biệt ở đây vì "id" là tên cột mong muốn
  }
}
