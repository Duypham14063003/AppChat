# Bot Messaging API

## Muc dich

API nay cho phep he thong ben ngoai gui thong bao vao mot group chat trong app ma khong can dang nhap JWT hoac ket noi WebSocket.

Server se gui tin nhan bang system bot:

- Email: `bot@system.local`
- Ten hien thi: `System Bot`

## Dieu kien truoc khi dung

1. Backend da cau hinh bien moi truong `BOT_API_KEY`
2. Bot `bot@system.local` da duoc add vao group can nhan thong bao
3. Ben ngoai biet `conversation_id` cua group do

Neu bot chua nam trong group, API se tra ve `403 Forbidden`.

## Endpoint

- Method: `POST`
- URL: `/api/v1/bot/messages`
- Auth: Header `x-api-key`
- Content-Type: `application/json`

## Headers

```http
x-api-key: <shared-secret>
Content-Type: application/json
```

## Request body

```json
{
  "conversation_id": "6998761a-f0db-4dfd-8d95-ecc23cfae783",
  "content": "Thong bao tu he thong web ngoai",
  "external_message_id": "550e8400-e29b-41d4-a716-446655440000",
  "metadata": {
    "source": "partner-web",
    "severity": "info"
  }
}
```

## Field mo ta

- `conversation_id`: UUID cua group can gui
- `content`: noi dung text can gui
- `external_message_id`: UUID tuy chon do he thong ngoai tu sinh de retry idempotent
- `metadata`: object tuy chon de luu them context

## Success response

```json
{
  "success": true,
  "conversation_id": "6998761a-f0db-4dfd-8d95-ecc23cfae783",
  "message_id": "550e8400-e29b-41d4-a716-446655440000",
  "created_at": "2026-06-04T12:00:00.000Z",
  "sender": {
    "id": "00000000-0000-0000-0000-000000000001",
    "email": "bot@system.local",
    "name": "System Bot"
  }
}
```

## Error responses

### 401 Unauthorized

Sai hoac thieu `x-api-key`

```json
{
  "statusCode": 401,
  "message": "Invalid x-api-key",
  "error": "Unauthorized"
}
```

### 403 Forbidden

Bot chua la thanh vien cua group

```json
{
  "statusCode": 403,
  "message": "Bot user is not a member of the target conversation",
  "error": "Forbidden"
}
```

### 400 Bad Request

Sai format body, thieu field, content qua dai, `conversation_id` khong phai UUID, `external_message_id` khong phai UUID.

### 503 Service Unavailable

Backend chua cau hinh `BOT_API_KEY`

## Vi du curl

```bash
curl -X POST "https://your-domain.example/api/v1/bot/messages" \
  -H "x-api-key: your-shared-secret" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": "6998761a-f0db-4dfd-8d95-ecc23cfae783",
    "content": "Thong bao tu doi tac",
    "external_message_id": "550e8400-e29b-41d4-a716-446655440000",
    "metadata": {
      "source": "partner-web",
      "event_type": "deployment_finished"
    }
  }'
```

## Khuyen nghi cho ben ngoai

1. Luon tu sinh `external_message_id` dang UUID cho moi thong bao
2. Khi retry cung 1 thong bao, dung lai cung `external_message_id`
3. Khong de lo `x-api-key` tren frontend; chi goi API nay tu backend server
4. Luu lai `message_id` tra ve neu can doi soat

## Khuyen nghi van hanh noi bo

1. Tao `BOT_API_KEY` dai, kho doan
2. Chi cap cho cac he thong doi tac can thiet
3. Neu lo key, rotate key va cap lai cho doi tac
4. Add bot vao dung group can gui, khong add tran lan
