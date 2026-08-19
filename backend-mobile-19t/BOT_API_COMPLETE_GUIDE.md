# Bot API - Tài Liệu Đầy Đủ Cho Khách Hàng

## 📋 Tổng Quan

API Bot cho phép hệ thống bên ngoài:
- ✅ **Gửi tin nhắn** vào nhóm hoặc gửi DM cho user
- ✅ **Xem lịch sử** tin nhắn đã gửi
- ✅ **Sửa tin nhắn** đã gửi
- ✅ **Xóa tin nhắn** đã gửi

**Đặc điểm:**
- Không cần xác thực (public API)
- Rate limit: 100 requests/phút
- Tất cả tin nhắn đều có thể quản lý sau khi gửi

---

## 🔌 API Endpoints

### Base URL
```
https://your-domain.com/api/v1
```

---

## 1️⃣ Gửi Tin Nhắn

**Endpoint:** `POST /bot/messages`

**Mô tả:** Gửi tin nhắn vào nhóm hoặc gửi DM cho user

### Request Body

**Gửi vào nhóm:**
```json
{
  "bot_id": "uuid-của-bot",
  "conversation_id": "uuid-của-nhóm",
  "content": "Nội dung tin nhắn"
}
```

**Gửi DM cho user:**
```json
{
  "bot_id": "uuid-của-bot",
  "user_id": "uuid-của-user",
  "content": "Tin nhắn riêng"
}
```

**Gửi với metadata:**
```json
{
  "bot_id": "uuid-của-bot",
  "conversation_id": "uuid-của-nhóm",
  "content": "Tin nhắn",
  "external_message_id": "id-tùy-chỉnh",
  "metadata": {
    "source": "webhook",
    "order_id": "12345"
  }
}
```

### Response (201 Created)
```json
{
  "success": true,
  "conversation_id": "uuid",
  "message_id": "uuid-của-message",
  "created_at": "2024-05-26T10:30:00.000Z",
  "sender": {
    "id": "bot-uuid",
    "email": "bot@system.local",
    "name": "Bot Name"
  }
}
```

### Code Examples

**cURL:**
```bash
curl -X POST https://your-domain.com/api/v1/bot/messages \
  -H "Content-Type: application/json" \
  -d '{
    "bot_id": "12345678-1234-1234-1234-123456789012",
    "conversation_id": "87654321-4321-4321-4321-210987654321",
    "content": "Hello from bot!"
  }'
```

**JavaScript:**
```javascript
const response = await fetch('https://your-domain.com/api/v1/bot/messages', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    bot_id: '12345678-1234-1234-1234-123456789012',
    conversation_id: '87654321-4321-4321-4321-210987654321',
    content: 'Hello from JavaScript!'
  })
});
const data = await response.json();
console.log('Message ID:', data.message_id);
```

**Python:**
```python
import requests

response = requests.post(
    'https://your-domain.com/api/v1/bot/messages',
    json={
        'bot_id': '12345678-1234-1234-1234-123456789012',
        'conversation_id': '87654321-4321-4321-4321-210987654321',
        'content': 'Hello from Python!'
    }
)
data = response.json()
print('Message ID:', data['message_id'])
```

---

## 2️⃣ Xem Lịch Sử Tin Nhắn

**Endpoint:** `GET /bot/messages`

**Mô tả:** Lấy danh sách tin nhắn đã gửi (có phân trang)

### Query Parameters

| Tham số | Type | Bắt buộc | Mô tả |
|---------|------|----------|-------|
| `bot_id` | UUID | ✅ | ID của bot |
| `conversation_id` | UUID | ❌ | Lọc theo conversation |
| `page` | Number | ❌ | Số trang (mặc định: 1) |
| `limit` | Number | ❌ | Số tin/trang (mặc định: 20, max: 100) |

### Response (200 OK)
```json
{
  "messages": [
    {
      "id": "msg-uuid-1",
      "conversation_id": "conv-uuid",
      "content": "Hello from bot!",
      "type": "text",
      "metadata": { "source": "webhook" },
      "created_at": "2024-05-26T10:30:00.000Z",
      "edited_at": null
    },
    {
      "id": "msg-uuid-2",
      "conversation_id": "conv-uuid",
      "content": "Updated message",
      "type": "text",
      "metadata": null,
      "created_at": "2024-05-26T10:25:00.000Z",
      "edited_at": "2024-05-26T10:26:00.000Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 45,
    "total_pages": 3
  }
}
```

### Code Examples

**cURL:**
```bash
# Lấy tất cả tin nhắn (page 1)
curl "https://your-domain.com/api/v1/bot/messages?bot_id=12345678-1234-1234-1234-123456789012&page=1&limit=20"

# Lọc theo conversation
curl "https://your-domain.com/api/v1/bot/messages?bot_id=12345678-1234-1234-1234-123456789012&conversation_id=87654321-4321-4321-4321-210987654321"
```

**JavaScript:**
```javascript
async function getBotMessages(botId, conversationId = null, page = 1) {
  const params = new URLSearchParams({
    bot_id: botId,
    page: page,
    limit: 20
  });

  if (conversationId) {
    params.append('conversation_id', conversationId);
  }

  const response = await fetch(`https://your-domain.com/api/v1/bot/messages?${params}`);
  const data = await response.json();

  console.log(`Tìm thấy ${data.pagination.total} tin nhắn`);
  return data;
}

// Sử dụng
const messages = await getBotMessages('bot-uuid', 'conv-uuid');
```

**Python:**
```python
def get_bot_messages(bot_id, conversation_id=None, page=1):
    params = {
        'bot_id': bot_id,
        'page': page,
        'limit': 20
    }
    if conversation_id:
        params['conversation_id'] = conversation_id

    response = requests.get(
        'https://your-domain.com/api/v1/bot/messages',
        params=params
    )
    data = response.json()
    print(f"Tổng: {data['pagination']['total']} tin nhắn")
    return data

# Sử dụng
messages = get_bot_messages('bot-uuid', 'conv-uuid')
```

---

## 3️⃣ Sửa Tin Nhắn

**Endpoint:** `PATCH /bot/messages`

**Mô tả:** Cập nhật nội dung tin nhắn đã gửi

### Request Body

```json
{
  "bot_id": "uuid-của-bot",
  "message_id": "uuid-của-message",
  "content": "Nội dung mới",
  "metadata": {
    "edited_reason": "fix typo"
  }
}
```

### Response (200 OK)
```json
{
  "success": true,
  "message_id": "uuid",
  "content": "Nội dung mới",
  "metadata": { "edited_reason": "fix typo" },
  "edited_at": "2024-05-26T11:00:00.000Z"
}
```

### Code Examples

**cURL:**
```bash
curl -X PATCH https://your-domain.com/api/v1/bot/messages \
  -H "Content-Type: application/json" \
  -d '{
    "bot_id": "12345678-1234-1234-1234-123456789012",
    "message_id": "abcdef12-3456-7890-abcd-ef1234567890",
    "content": "Nội dung đã sửa"
  }'
```

**JavaScript:**
```javascript
async function updateMessage(botId, messageId, newContent) {
  const response = await fetch('https://your-domain.com/api/v1/bot/messages', {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      bot_id: botId,
      message_id: messageId,
      content: newContent
    })
  });
  return await response.json();
}

// Sử dụng
await updateMessage('bot-uuid', 'msg-uuid', 'Nội dung mới');
```

**Python:**
```python
def update_message(bot_id, message_id, content):
    response = requests.patch(
        'https://your-domain.com/api/v1/bot/messages',
        json={
            'bot_id': bot_id,
            'message_id': message_id,
            'content': content
        }
    )
    return response.json()

# Sử dụng
update_message('bot-uuid', 'msg-uuid', 'Nội dung đã cập nhật')
```

---

## 4️⃣ Xóa Tin Nhắn

**Endpoint:** `DELETE /bot/messages`

**Mô tả:** Xóa tin nhắn (soft delete - không xóa hẳn)

### Request Body

```json
{
  "bot_id": "uuid-của-bot",
  "message_id": "uuid-của-message"
}
```

### Response (200 OK)
```json
{
  "success": true,
  "message_id": "uuid",
  "deleted_at": "2024-05-26T11:05:00.000Z"
}
```

### Code Examples

**cURL:**
```bash
curl -X DELETE https://your-domain.com/api/v1/bot/messages \
  -H "Content-Type: application/json" \
  -d '{
    "bot_id": "12345678-1234-1234-1234-123456789012",
    "message_id": "abcdef12-3456-7890-abcd-ef1234567890"
  }'
```

**JavaScript:**
```javascript
async function deleteMessage(botId, messageId) {
  const response = await fetch('https://your-domain.com/api/v1/bot/messages', {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      bot_id: botId,
      message_id: messageId
    })
  });
  return await response.json();
}

// Sử dụng
await deleteMessage('bot-uuid', 'msg-uuid');
```

**Python:**
```python
def delete_message(bot_id, message_id):
    response = requests.delete(
        'https://your-domain.com/api/v1/bot/messages',
        json={
            'bot_id': bot_id,
            'message_id': message_id
        }
    )
    return response.json()

# Sử dụng
delete_message('bot-uuid', 'msg-uuid')
```

---

## ⚠️ Xử Lý Lỗi

### 400 Bad Request
```json
{
  "statusCode": 400,
  "message": "Must provide either conversation_id or user_id",
  "error": "Bad Request"
}
```

**Nguyên nhân:**
- Thiếu cả conversation_id và user_id khi gửi tin nhắn
- Cung cấp cả 2 tham số
- Cố sửa tin nhắn đã bị xóa
- Nội dung quá dài (>5000 ký tự)

### 403 Forbidden
```json
{
  "statusCode": 403,
  "message": "Bot is not active",
  "error": "Forbidden"
}
```

**Nguyên nhân:** Bot đã bị vô hiệu hóa

### 404 Not Found
```json
{
  "statusCode": 404,
  "message": "Message not found or not owned by this bot",
  "error": "Not Found"
}
```

**Nguyên nhân:**
- Bot ID không tồn tại
- Message ID không tồn tại
- Message không thuộc về bot này

### 429 Too Many Requests
```json
{
  "statusCode": 429,
  "message": "ThrottlerException: Too Many Requests"
}
```

**Nguyên nhân:** Vượt quá 100 requests/phút

**Giải pháp:** Chờ 1 phút và thử lại

---

## 🎯 Use Cases Thực Tế

### 1. Gửi và Tự Động Sửa Lỗi

```javascript
// Gửi tin nhắn
const result = await fetch('https://your-domain.com/api/v1/bot/messages', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    bot_id: BOT_ID,
    conversation_id: CONV_ID,
    content: 'Đơn hàng #12345 đã đưuọc xác nhận' // Có typo
  })
});

const { message_id } = await result.json();

// Phát hiện lỗi, sửa lại
await fetch('https://your-domain.com/api/v1/bot/messages', {
  method: 'PATCH',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    bot_id: BOT_ID,
    message_id: message_id,
    content: 'Đơn hàng #12345 đã được xác nhận' // Đã sửa
  })
});
```

### 2. Dashboard Hiển Thị Lịch Sử

```python
import requests

def show_message_history(bot_id, conversation_id=None):
    """Hiển thị lịch sử tin nhắn với pagination"""
    page = 1

    while True:
        params = {
            'bot_id': bot_id,
            'page': page,
            'limit': 50
        }
        if conversation_id:
            params['conversation_id'] = conversation_id

        response = requests.get(
            'https://your-domain.com/api/v1/bot/messages',
            params=params
        )
        data = response.json()

        # Hiển thị messages
        for msg in data['messages']:
            print(f"[{msg['created_at']}] {msg['content']}")
            if msg['edited_at']:
                print(f"  → Đã sửa lúc {msg['edited_at']}")

        # Hết trang
        if page >= data['pagination']['total_pages']:
            break
        page += 1

# Sử dụng
show_message_history('bot-uuid', 'conv-uuid')
```

### 3. Xóa Tin Nhắn Cũ

```javascript
async function deleteOldMessages(botId, daysOld = 30) {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - daysOld);

  let page = 1;
  let deletedCount = 0;

  while (true) {
    // Lấy messages
    const params = new URLSearchParams({
      bot_id: botId,
      page: page,
      limit: 100
    });

    const response = await fetch(
      `https://your-domain.com/api/v1/bot/messages?${params}`
    );
    const data = await response.json();

    // Xóa messages cũ
    for (const msg of data.messages) {
      const msgDate = new Date(msg.created_at);
      if (msgDate < cutoffDate) {
        await fetch('https://your-domain.com/api/v1/bot/messages', {
          method: 'DELETE',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            bot_id: botId,
            message_id: msg.id
          })
        });
        deletedCount++;
      }
    }

    if (page >= data.pagination.total_pages) break;
    page++;
  }

  console.log(`Đã xóa ${deletedCount} tin nhắn cũ`);
}

// Xóa tin nhắn cũ hơn 30 ngày
await deleteOldMessages('bot-uuid', 30);
```

### 4. Webhook + Auto-correct

```javascript
const express = require('express');
const app = express();

app.post('/webhook/order', async (req, res) => {
  const { orderId, status } = req.body;

  // Gửi thông báo
  const result = await fetch('https://your-domain.com/api/v1/bot/messages', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      bot_id: process.env.BOT_ID,
      conversation_id: process.env.SALES_CHANNEL,
      content: `Đơn hàng #${orderId}: ${status}`,
      metadata: {
        order_id: orderId,
        webhook_time: new Date().toISOString()
      }
    })
  });

  const { message_id } = await result.json();

  // Lưu message_id để có thể sửa/xóa sau
  // await db.saveMessageId(orderId, message_id);

  res.json({ success: true, message_id });
});

app.listen(3000);
```

---

## 📊 Tổng Kết API

| Endpoint | Method | Mục đích | Rate Limit |
|----------|--------|----------|------------|
| `/bot/messages` | POST | Gửi tin nhắn | 100/phút |
| `/bot/messages` | GET | Xem lịch sử | 100/phút |
| `/bot/messages` | PATCH | Sửa tin nhắn | 100/phút |
| `/bot/messages` | DELETE | Xóa tin nhắn | 100/phút |

---

## 🔐 Best Practices

### ✅ Nên Làm

1. **Lưu message_id sau khi gửi**
   ```javascript
   const { message_id } = await sendMessage(...);
   await db.save({ orderId, messageId: message_id });
   ```

2. **Implement retry cho rate limit**
   ```javascript
   async function sendWithRetry(payload) {
     try {
       return await sendMessage(payload);
     } catch (error) {
       if (error.status === 429) {
         await sleep(60000); // Chờ 1 phút
         return await sendMessage(payload);
       }
       throw error;
     }
   }
   ```

3. **Validate trước khi gửi**
   ```javascript
   if (content.length > 5000) {
     throw new Error('Content quá dài');
   }
   ```

4. **Log tất cả operations**
   ```javascript
   console.log(`[${new Date().toISOString()}] Sent message:`, message_id);
   ```

### ❌ Không Nên

1. ❌ Không gọi API từ browser (client-side)
2. ❌ Không hardcode bot_id trong code
3. ❌ Không spam tin nhắn
4. ❌ Không bỏ qua error handling
5. ❌ Không xóa tin nhắn quan trọng không có backup

---

## 📞 Liên Hệ

**Cần bot_id?** Liên hệ admin để tạo bot mới

**Cần conversation_id?** Yêu cầu admin cung cấp

**Gặp vấn đề?** Liên hệ: [Your Support Email]

---

**Version:** 1.1.0
**Last Updated:** June 2026
