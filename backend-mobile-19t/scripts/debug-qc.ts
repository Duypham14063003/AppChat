import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module.js';
import { DataSource } from 'typeorm';

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);

  console.log('--- USER INFO ---');
  const user = await dataSource.query(`
    SELECT id, name, email, job_title, is_active 
    FROM users 
    WHERE name ILIKE '%Huỳnh Thị Minh Anh%'
  `);
  console.log(user);

  console.log('\n--- JOB TITLE MAPPINGS & INTERNAL ROLES ---');
  const mappings = await dataSource.query(`
    SELECT jtm.id, jtm.odoo_job_title, ir.name as internal_role_name, ir.multiplier
    FROM job_title_mappings jtm
    JOIN internal_roles ir ON jtm.internal_role_id = ir.id
  `);
  console.log(mappings);

  if (user.length > 0) {
    const userId = user[0].id;
    console.log(`\n--- DAILY REPORTS FOR USER ON 2026-05-26 ---`);
    const reports = await dataSource.query(`
      SELECT id, report_date, report_type, report_role, total_points_earned, created_at
      FROM daily_reports
      WHERE user_id = $1 AND report_date = '2026-05-26'
    `, [userId]);
    console.log(reports);

    if (reports.length > 0) {
      const reportId = reports[0].id;
      console.log(`\n--- DAILY REPORT ITEMS ---`);
      const items = await dataSource.query(`
        SELECT id, task_name, status, progress, qc_done, qc_miss, qc_fail, qc_note
        FROM daily_report_items
        WHERE report_id = $1
      `, [reportId]);
      console.log(items);

      console.log(`\n--- POINT TRANSACTIONS FOR THIS REPORT ---`);
      const txs = await dataSource.query(`
        SELECT id, points, type, source_type, source_ref_id, event_key, note, metadata
        FROM point_transactions
        WHERE user_id = $1 AND source_ref_id = $2
      `, [userId, reportId]);
      console.log(txs);
    }
  }

  await app.close();
}

main().catch((err) => {
  console.error('Debug script failed:', err);
  process.exit(1);
});
