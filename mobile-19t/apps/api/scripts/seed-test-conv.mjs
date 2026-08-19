/**
 * Seed a test conversation for WS smoke testing.
 * Usage: node scripts/seed-test-conv.mjs
 *
 * Connects to Postgres using the same env vars as the API,
 * creates a second test user (if needed), creates a DIRECT conversation,
 * and prints the CONV_ID to use with ws-smoke-test.mjs.
 */

import pg from 'pg';
import { randomUUID } from 'crypto';
import { config } from 'dotenv';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
config({ path: resolve(__dirname, '../../../.env') });

const { Client } = pg;

const client = new Client({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

const YOUR_USER_ID = 'c51fdfb3-e1fa-46e2-a8f7-55d6fd992ce8';

async function main() {
  await client.connect();

  // Check if test user exists
  const TEST_USER_ID = '00000000-0000-4000-8000-000000000099';
  const existing = await client.query('SELECT id FROM users WHERE id = $1', [TEST_USER_ID]);

  if (existing.rows.length === 0) {
    await client.query(
      `INSERT INTO users (id, odoo_uid, email, name, is_active, created_at, updated_at)
       VALUES ($1, 99999, 'test-bot@19t.vn', 'Test Bot', true, NOW(), NOW())`,
      [TEST_USER_ID],
    );
    console.log('[SEED] Created test user:', TEST_USER_ID);
  } else {
    console.log('[SEED] Test user already exists:', TEST_USER_ID);
  }

  // Check if direct conversation already exists
  const existingConv = await client.query(
    `SELECT c.id FROM conversations c
     INNER JOIN conversation_members m1 ON m1.conv_id = c.id AND m1.user_id = $1
     INNER JOIN conversation_members m2 ON m2.conv_id = c.id AND m2.user_id = $2
     WHERE c.type = 'DIRECT'`,
    [YOUR_USER_ID, TEST_USER_ID],
  );

  let convId;
  if (existingConv.rows.length > 0) {
    convId = existingConv.rows[0].id;
    console.log('[SEED] Conversation already exists:', convId);
  } else {
    convId = randomUUID();
    await client.query(
      `INSERT INTO conversations (id, type, created_by, created_at)
       VALUES ($1, 'DIRECT', $2, NOW())`,
      [convId, YOUR_USER_ID],
    );
    await client.query(
      `INSERT INTO conversation_members (conv_id, user_id, role, joined_at)
       VALUES ($1, $2, 'admin', NOW()), ($1, $3, 'member', NOW())`,
      [convId, YOUR_USER_ID, TEST_USER_ID],
    );
    console.log('[SEED] Created conversation:', convId);
  }

  console.log('\n--- Use this to test send_message ---');
  console.log(`$env:CONV_ID="${convId}"; node scripts/ws-smoke-test.mjs <TOKEN>`);

  await client.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
