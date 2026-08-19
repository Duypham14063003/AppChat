import { MigrationInterface, QueryRunner } from 'typeorm';

export class SeedInternalRoleMapping1714910000000 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Tạo các Role nội bộ chuẩn
    await queryRunner.query(`
      INSERT INTO "internal_roles" ("name", "multiplier") VALUES
      ('QC', 1.50),
      ('Developer', 1.20),
      ('Project Manager', 1.30),
      ('Designer', 1.10),
      ('Management', 1.00)
      ON CONFLICT ("name") DO NOTHING
    `);

    // 2. Ánh xạ các chức danh Odoo hiện có vào Role tương ứng
    // Lấy ID của các role vừa tạo
    const roles = await queryRunner.query(`SELECT id, name FROM internal_roles`);
    const roleMap = new Map(roles.map((r: any) => [r.name, r.id]));

    const mappings = [
      { odoo: 'QC', internal: 'QC' },
      { odoo: 'Fullstack Developer', internal: 'Developer' },
      { odoo: 'Project Manager', internal: 'Project Manager' },
      { odoo: 'UX/UI Designer', internal: 'Designer' },
      { odoo: 'CEO', internal: 'Management' },
    ];

    for (const m of mappings) {
      const roleId = roleMap.get(m.internal);
      if (roleId) {
        await queryRunner.query(`
          INSERT INTO "job_title_mappings" ("odoo_job_title", "internal_role_id")
          VALUES ('${m.odoo}', '${roleId}')
          ON CONFLICT ("odoo_job_title") DO NOTHING
        `);
      }
    }
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Trong môi trường production thường không xóa dữ liệu seed, 
    // nhưng nếu cần bạn có thể xóa theo ID hoặc tên.
    await queryRunner.query(`DELETE FROM "job_title_mappings"`);
    await queryRunner.query(`DELETE FROM "internal_roles"`);
  }
}
