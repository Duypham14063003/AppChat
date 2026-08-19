const { Client } = require('pg');

async function main() {
  const client = new Client({
    host: '103.97.126.78',
    port: 5432,
    user: 'app_19t',
    database: 'app_19t',
    password: 'tc9gzzt14m90cj3vlxx8',
  });

  await client.connect();

  console.log('Querying all evening reports submitted on 2026-05-26...');
  const res = await client.query(`
    SELECT dr.id, u.name, dr.report_role, dr.total_points_earned, dr.chat_message_id, dr.created_at
    FROM daily_reports dr
    JOIN users u ON dr.user_id = u.id
    WHERE dr.report_date = '2026-05-26' AND dr.report_type = 'evening'
    ORDER BY dr.created_at ASC
  `);
  console.log(res.rows);

  await client.end();
}

main().catch(err => console.error(err));
