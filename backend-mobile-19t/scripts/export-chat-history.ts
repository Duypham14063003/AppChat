import { config } from 'dotenv';
import { Client } from 'pg';
import * as path from 'node:path';
import { createDecipheriv } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';

config({ path: path.resolve(process.cwd(), '.env') });

type EncryptedEnvelope = {
  version: number;
  alg: string;
  key_id: string;
  nonce: string;
  ciphertext: string;
};

type RawMessageRow = {
  message_id: string;
  created_at: string;
  sender_name: string | null;
  sender_id: string;
  type: string;
  content: string | null;
  reply_to_id: string | null;
  edited_at: string | null;
  deleted_at: string | null;
  metadata: unknown;
};

type ExportMessage = {
  createdAt: string;
  senderName: string;
  senderId: string;
  type: string;
  content: string;
  replyToId: string | null;
  editedAt: string | null;
  deletedAt: string | null;
  imageDataUri: string | null;
  attachmentUrl: string | null;
};

function parseArgs() {
  const args = process.argv.slice(2);
  const options: Record<string, string | boolean> = {};

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (!arg.startsWith('--')) continue;

    const key = arg.slice(2);
    const next = args[i + 1];
    if (!next || next.startsWith('--')) {
      options[key] = true;
      continue;
    }

    options[key] = next;
    i += 1;
  }

  return {
    convId: String(options['conv-id'] || ''),
    since: String(options.since || ''),
    outDir: String(options['out-dir'] || 'exports/chat'),
    outBase: String(options['out-base'] || 'chat-export'),
    assetBaseUrl: String(options['asset-base-url'] || ''),
    excludeSystem: options['exclude-system'] !== false,
    excludeDeleted: options['exclude-deleted'] === true,
  };
}

function assertRequired(value: string, name: string) {
  if (!value.trim()) {
    throw new Error(`Missing required argument --${name}`);
  }
}

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

function getEncryptedEnvelope(
  metadata: Record<string, unknown> | null,
): EncryptedEnvelope | null {
  if (!metadata) return null;
  const raw = metadata.encrypted_content;
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;

  const envelope = raw as Record<string, unknown>;
  const version = Number(envelope.version);
  const alg = typeof envelope.alg === 'string' ? envelope.alg : '';
  const keyId = typeof envelope.key_id === 'string' ? envelope.key_id : '';
  const nonce = typeof envelope.nonce === 'string' ? envelope.nonce : '';
  const ciphertext =
    typeof envelope.ciphertext === 'string' ? envelope.ciphertext : '';

  if (!version || !alg || !keyId || !nonce || !ciphertext) return null;

  return {
    version,
    alg,
    key_id: keyId,
    nonce,
    ciphertext,
  };
}

function decryptEnvelope(
  envelope: EncryptedEnvelope,
  keyMaterial: Buffer,
  params: {
    messageId: string;
    convId: string;
    type: string;
  },
): string | null {
  try {
    const nonce = Buffer.from(envelope.nonce, 'base64');
    const payload = Buffer.from(envelope.ciphertext, 'base64');
    if (payload.length <= 16) return null;

    const authTag = payload.subarray(payload.length - 16);
    const ciphertext = payload.subarray(0, payload.length - 16);
    const decipher = createDecipheriv('aes-256-gcm', keyMaterial, nonce);
    decipher.setAAD(
      Buffer.from(
        `${params.messageId}|${params.convId}|${params.type}`,
        'utf8',
      ),
    );
    decipher.setAuthTag(authTag);

    return Buffer.concat([
      decipher.update(ciphertext),
      decipher.final(),
    ]).toString('utf8');
  } catch {
    return null;
  }
}

function fallbackContent(
  row: RawMessageRow,
  metadata: Record<string, unknown> | null,
): string {
  if (row.deleted_at) return '[Tin nhan da thu hoi]';
  if (row.content && row.content.trim()) return row.content.trim();
  if (row.type === 'system') return '[Tin nhan he thong]';

  const fileName =
    typeof metadata?.originalName === 'string' ? metadata.originalName : null;
  if (row.type === 'file') {
    return fileName ? `[File] ${fileName}` : '[File]';
  }
  if (row.type === 'image') return '[Hinh anh]';
  if (row.type === 'video') return '[Video]';
  if (row.type === 'audio' || row.type === 'voice') return '[Tin nhan thoai]';

  return '';
}

function getAttachmentUrl(
  metadata: Record<string, unknown> | null,
): string | null {
  const url = typeof metadata?.url === 'string' ? metadata.url.trim() : '';
  return url || null;
}

function resolveLocalUploadPath(attachmentUrl: string): string | null {
  if (!attachmentUrl.startsWith('/uploads/')) return null;
  return path.join(process.cwd(), attachmentUrl.slice(1));
}

function mimeFromPath(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase();
  switch (ext) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    case '.svg':
      return 'image/svg+xml';
    default:
      return 'application/octet-stream';
  }
}

async function buildImageDataUri(
  attachmentUrl: string | null,
  assetBaseUrl: string,
): Promise<string | null> {
  if (!attachmentUrl) return null;
  const localPath = resolveLocalUploadPath(attachmentUrl);
  if (localPath && existsSync(localPath)) {
    const mime = mimeFromPath(localPath);
    if (!mime.startsWith('image/')) return null;
    const base64 = readFileSync(localPath).toString('base64');
    return `data:${mime};base64,${base64}`;
  }

  if (!assetBaseUrl) return null;

  const absoluteUrl = new URL(
    attachmentUrl,
    assetBaseUrl.endsWith('/') ? assetBaseUrl : `${assetBaseUrl}/`,
  ).toString();

  try {
    const response = await fetch(absoluteUrl);
    if (!response.ok) return null;
    const mime = response.headers.get('content-type') || 'application/octet-stream';
    if (!mime.startsWith('image/')) return null;
    const buffer = Buffer.from(await response.arrayBuffer());
    return `data:${mime};base64,${buffer.toString('base64')}`;
  } catch {
    return null;
  }
}

function csvEscape(value: unknown): string {
  const normalized =
    value == null ? '' : value instanceof Date ? value.toISOString() : String(value);
  return `"${normalized.replace(/"/g, '""')}"`;
}

function escapeXml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function wrapText(text: string, maxChars: number): string[] {
  const lines: string[] = [];
  const paragraphs = text.split(/\r?\n/);

  for (const paragraph of paragraphs) {
    const words = paragraph.split(/\s+/).filter(Boolean);
    if (words.length === 0) {
      lines.push('');
      continue;
    }

    let current = '';
    for (const word of words) {
      const candidate = current ? `${current} ${word}` : word;
      if (candidate.length <= maxChars) {
        current = candidate;
      } else {
        if (current) lines.push(current);
        if (word.length <= maxChars) {
          current = word;
        } else {
          for (let i = 0; i < word.length; i += maxChars) {
            lines.push(word.slice(i, i + maxChars));
          }
          current = '';
        }
      }
    }

    if (current) lines.push(current);
  }

  return lines.length > 0 ? lines : [''];
}

function formatLocalTimestamp(value: string): string {
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).format(new Date(value));
}

function renderSvg(messages: ExportMessage[], title: string): string {
  const width = 1400;
  const padding = 40;
  const headerHeight = 100;
  const bubblePadding = 18;
  const lineHeight = 24;
  const maxChars = 70;
  const bubbleWidth = width - padding * 2;
  let cursorY = headerHeight;
  const chunks: string[] = [];

  for (const message of messages) {
    const textLines = wrapText(message.content || '[Trong]', maxChars);
    const bubbleHeight = 56 + textLines.length * lineHeight + bubblePadding;
    const sender = escapeXml(message.senderName);
    const meta = escapeXml(
      `${formatLocalTimestamp(message.createdAt)} • ${message.type}`,
    );

    chunks.push(
      `<rect x="${padding}" y="${cursorY}" rx="18" ry="18" width="${bubbleWidth}" height="${bubbleHeight}" fill="#f7f4ee" stroke="#d7c7ae" stroke-width="1.5" />`,
    );
    chunks.push(
      `<text x="${padding + 20}" y="${cursorY + 30}" font-family="Arial, sans-serif" font-size="22" font-weight="700" fill="#5c3d1e">${sender}</text>`,
    );
    chunks.push(
      `<text x="${padding + 20}" y="${cursorY + 58}" font-family="Arial, sans-serif" font-size="15" fill="#8a6f4a">${meta}</text>`,
    );

    textLines.forEach((line, index) => {
      const y = cursorY + 94 + index * lineHeight;
      chunks.push(
        `<text x="${padding + 20}" y="${y}" font-family="Arial, sans-serif" font-size="20" fill="#1f1f1f">${escapeXml(line)}</text>`,
      );
    });

    cursorY += bubbleHeight + 18;
  }

  const height = cursorY + padding;
  return [
    `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">`,
    `<rect width="100%" height="100%" fill="#efe6d7" />`,
    `<text x="${padding}" y="50" font-family="Arial, sans-serif" font-size="30" font-weight="700" fill="#2d2418">${escapeXml(title)}</text>`,
    `<text x="${padding}" y="82" font-family="Arial, sans-serif" font-size="16" fill="#6a5a45">Tong so tin nhan: ${messages.length}</text>`,
    ...chunks,
    `</svg>`,
  ].join('\n');
}

function renderHtml(messages: ExportMessage[], title: string): string {
  const cards = messages
    .map((message) => {
      const meta = escapeXml(
        `${formatLocalTimestamp(message.createdAt)} • ${message.type}`,
      );
      const sender = escapeXml(message.senderName);
      const content = escapeXml(message.content || '[Trong]');
      const imageBlock = message.imageDataUri
        ? `<div class="image-wrap"><img src="${message.imageDataUri}" alt="chat image" /></div>`
        : '';
      const attachmentBlock =
        !message.imageDataUri && message.attachmentUrl
          ? `<div class="attachment">Tep dinh kem: ${escapeXml(message.attachmentUrl)}</div>`
          : '';

      return `
        <section class="card">
          <div class="sender">${sender}</div>
          <div class="meta">${meta}</div>
          ${imageBlock}
          <div class="content">${content.replace(/\n/g, '<br />')}</div>
          ${attachmentBlock}
        </section>
      `;
    })
    .join('\n');

  return `<!DOCTYPE html>
<html lang="vi">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${escapeXml(title)}</title>
    <style>
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: Arial, sans-serif;
        background: #efe6d7;
        color: #1f1f1f;
      }
      .page {
        width: 1400px;
        margin: 0 auto;
        padding: 40px;
      }
      h1 {
        margin: 0 0 8px;
        font-size: 30px;
        color: #2d2418;
      }
      .summary {
        margin-bottom: 24px;
        color: #6a5a45;
        font-size: 16px;
      }
      .card {
        background: #f7f4ee;
        border: 1.5px solid #d7c7ae;
        border-radius: 18px;
        padding: 18px 20px;
        margin-bottom: 18px;
      }
      .sender {
        font-size: 22px;
        font-weight: 700;
        color: #5c3d1e;
      }
      .meta {
        margin-top: 6px;
        font-size: 15px;
        color: #8a6f4a;
      }
      .image-wrap {
        margin-top: 14px;
      }
      .image-wrap img {
        display: block;
        max-width: 100%;
        max-height: 900px;
        border-radius: 14px;
        border: 1px solid #dbcdb5;
      }
      .content {
        margin-top: 14px;
        font-size: 20px;
        line-height: 1.45;
        word-break: break-word;
      }
      .attachment {
        margin-top: 12px;
        font-size: 16px;
        color: #6a5a45;
      }
    </style>
  </head>
  <body>
    <main class="page">
      <h1>${escapeXml(title)}</h1>
      <div class="summary">Tong so tin nhan: ${messages.length}</div>
      ${cards}
    </main>
  </body>
</html>`;
}

async function main() {
  const options = parseArgs();
  assertRequired(options.convId, 'conv-id');
  assertRequired(options.since, 'since');

  mkdirSync(options.outDir, { recursive: true });

  const client = new Client({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || '5432'),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  });

  await client.connect();

  try {
    const sql = `
      SELECT
        m.id AS message_id,
        m.created_at,
        COALESCE(u.name, '[Unknown]') AS sender_name,
        m.sender_id,
        m.type,
        m.content,
        m.reply_to_id,
        m.edited_at,
        m.deleted_at,
        m.metadata
      FROM messages m
      LEFT JOIN users u ON u.id = m.sender_id
      WHERE m.conv_id = $1
        AND m.created_at >= $2::timestamptz
        ${options.excludeSystem ? `AND m.type <> 'system'` : ''}
        ${options.excludeDeleted ? `AND m.deleted_at IS NULL` : ''}
      ORDER BY m.created_at ASC, m.id ASC
    `;

    const result = await client.query<RawMessageRow>(sql, [
      options.convId,
      options.since,
    ]);

    const keyCache = new Map<string, Buffer | null>();
    const messages: ExportMessage[] = [];

    for (const row of result.rows) {
      const metadata = parseMetadata(row.metadata);
      const envelope = getEncryptedEnvelope(metadata);
      let content = fallbackContent(row, metadata);
      const attachmentUrl = getAttachmentUrl(metadata);
      const imageDataUri =
        row.type === 'image'
          ? await buildImageDataUri(attachmentUrl, options.assetBaseUrl)
          : null;

      if (envelope && !row.deleted_at) {
        const cacheKey = `${options.convId}:${envelope.key_id}`;
        if (!keyCache.has(cacheKey)) {
          const keyResult = await client.query<{
            material: Buffer;
          }>(
            `SELECT material
             FROM conversation_encryption_keys
             WHERE conv_id = $1 AND key_id = $2
             LIMIT 1`,
            [options.convId, envelope.key_id],
          );
          keyCache.set(cacheKey, keyResult.rows[0]?.material ?? null);
        }

        const material = keyCache.get(cacheKey);
        const decrypted = material
          ? decryptEnvelope(envelope, material, {
              messageId: row.message_id,
              convId: options.convId,
              type: row.type,
            })
          : null;
        if (decrypted && decrypted.trim()) {
          content = decrypted.trim();
        } else if (!content) {
          content = '[Khong giai ma duoc noi dung]';
        }
      }

      messages.push({
        createdAt: row.created_at,
        senderName: row.sender_name || '[Unknown]',
        senderId: row.sender_id,
        type: row.type,
        content,
        replyToId: row.reply_to_id,
        editedAt: row.edited_at,
        deletedAt: row.deleted_at,
        imageDataUri,
        attachmentUrl,
      });
    }

    const csvLines = [
      [
        'created_at',
        'sender_name',
        'sender_id',
        'type',
        'content',
        'reply_to_id',
        'edited_at',
        'deleted_at',
      ].join(','),
      ...messages.map((message) =>
        [
          csvEscape(message.createdAt),
          csvEscape(message.senderName),
          csvEscape(message.senderId),
          csvEscape(message.type),
          csvEscape(message.content),
          csvEscape(message.replyToId),
          csvEscape(message.editedAt),
          csvEscape(message.deletedAt),
        ].join(','),
      ),
    ];

    const title = `Chat export ${options.convId} tu ${options.since}`;
    const csvPath = path.join(options.outDir, `${options.outBase}.csv`);
    const svgPath = path.join(options.outDir, `${options.outBase}.svg`);
    const htmlPath = path.join(options.outDir, `${options.outBase}.html`);

    writeFileSync(csvPath, `${csvLines.join('\n')}\n`, 'utf8');
    writeFileSync(svgPath, renderSvg(messages, title), 'utf8');
    writeFileSync(htmlPath, renderHtml(messages, title), 'utf8');

    console.log(`Exported ${messages.length} messages`);
    console.log(`CSV: ${csvPath}`);
    console.log(`SVG: ${svgPath}`);
    console.log(`HTML: ${htmlPath}`);
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
