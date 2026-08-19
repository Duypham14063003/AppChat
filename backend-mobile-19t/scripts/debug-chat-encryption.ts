import { config } from 'dotenv';
import { Client } from 'pg';
import * as path from 'node:path';
import { createDecipheriv } from 'node:crypto';

config({ path: path.resolve(process.cwd(), '.env') });

function parseMetadata(metadata: unknown): Record<string, unknown> | null {
  if (!metadata) return null;
  if (typeof metadata === 'string') {
    try {
      const parsed = JSON.parse(metadata) as unknown;
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
        ? (parsed as Record<string, unknown>)
        : null;
    } catch {
      return null;
    }
  }
  return typeof metadata === 'object' && !Array.isArray(metadata)
    ? (metadata as Record<string, unknown>)
    : null;
}

async function main() {
  const client = new Client({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || '5432'),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  await client.connect();

  try {
    const result = await client.query<{
      id: string;
      created_at: string;
      type: string;
      content: string | null;
      metadata: unknown;
      sender_name: string | null;
    }>(
      `SELECT m.id, m.created_at, m.type, m.content, m.metadata, u.name AS sender_name
       FROM messages m
       LEFT JOIN users u ON u.id = m.sender_id
       WHERE m.conv_id = $1
         AND m.created_at >= $2::timestamptz
         AND m.type = 'text'
         AND m.metadata IS NOT NULL
       ORDER BY m.created_at ASC
       LIMIT 10`,
      ['3015fbd4-b3c1-4f2c-8672-0ff9d21b6988', '2026-06-11T14:53:00+07:00'],
    );

    for (const row of result.rows) {
      const metadata = parseMetadata(row.metadata);
      const encrypted = metadata?.encrypted_content as
        | Record<string, unknown>
        | undefined;
      if (!encrypted) continue;

      const keyId = String(encrypted.key_id || '');
      const nonce = String(encrypted.nonce || '');
      const ciphertext = String(encrypted.ciphertext || '');

      const keyResult = await client.query<{ material: Buffer }>(
        `SELECT material
         FROM conversation_encryption_keys
         WHERE conv_id = $1 AND key_id = $2
         LIMIT 1`,
        ['3015fbd4-b3c1-4f2c-8672-0ff9d21b6988', keyId],
      );

      const key = keyResult.rows[0]?.material ?? null;
      let decrypted: string | null = null;
      let error: string | null = null;
      let matchedMode: string | null = null;

      try {
        if (!key) {
          error = 'missing-key';
        } else {
          const nonceBuf = Buffer.from(nonce, 'base64');
          const payload = Buffer.from(ciphertext, 'base64');
          const aadCandidates: Array<[string, Buffer | null]> = [
            ['none', null],
            ['id', Buffer.from(row.id, 'utf8')],
            [
              'conv_id',
              Buffer.from('3015fbd4-b3c1-4f2c-8672-0ff9d21b6988', 'utf8'),
            ],
            ['key_id', Buffer.from(keyId, 'utf8')],
            ['id:key_id', Buffer.from(`${row.id}:${keyId}`, 'utf8')],
            [
              'conv_id:key_id',
              Buffer.from(
                `3015fbd4-b3c1-4f2c-8672-0ff9d21b6988:${keyId}`,
                'utf8',
              ),
            ],
          ];
          const tagModes: Array<['tag-suffix' | 'tag-prefix', Buffer, Buffer]> =
            payload.length > 16
              ? [
                  [
                    'tag-suffix',
                    payload.subarray(0, payload.length - 16),
                    payload.subarray(payload.length - 16),
                  ],
                  [
                    'tag-prefix',
                    payload.subarray(16),
                    payload.subarray(0, 16),
                  ],
                ]
              : [];

          for (const [tagMode, cipherBuf, authTag] of tagModes) {
            for (const [aadName, aad] of aadCandidates) {
              try {
                const decipher = createDecipheriv('aes-256-gcm', key, nonceBuf);
                if (aad) decipher.setAAD(aad);
                decipher.setAuthTag(authTag);
                const candidate = Buffer.concat([
                  decipher.update(cipherBuf),
                  decipher.final(),
                ]).toString('utf8');
                decrypted = candidate;
                matchedMode = `${tagMode}|aad=${aadName}`;
                error = null;
                break;
              } catch (candidateErr) {
                error =
                  candidateErr instanceof Error
                    ? candidateErr.message
                    : String(candidateErr);
              }
            }
            if (decrypted) break;
          }
        }
      } catch (err) {
        error = err instanceof Error ? err.message : String(err);
      }

      console.log(
        JSON.stringify(
          {
            id: row.id,
            created_at: row.created_at,
            sender_name: row.sender_name,
            content: row.content,
            keyId,
            nonce_len: Buffer.from(nonce, 'base64').length,
            payload_len: Buffer.from(ciphertext, 'base64').length,
            key_len: key?.length ?? null,
            decrypted,
            matchedMode,
            error,
            metadata,
          },
          null,
          2,
        ),
      );
    }
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
