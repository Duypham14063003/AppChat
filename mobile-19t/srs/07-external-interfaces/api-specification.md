# 7.1 API Specification

## 7.1.1 General Conventions

- Base URL: `https://api.19t.vn/api/v1`
- Format: JSON
- Auth: `Authorization: Bearer <access_token>` (trừ /auth/login, /auth/refresh)
- Error format:
  ```json
  {
    "statusCode": 400,
    "message": "Validation failed",
    "errors": [{"field": "email", "message": "Email is required"}]
  }
  ```

## 7.1.2 Auth Endpoints

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/auth/login` | Đăng nhập qua Odoo SSO | No |
| POST | `/auth/refresh` | Refresh access token | Refresh token |
| POST | `/auth/logout` | Logout device hiện tại | Yes |
| POST | `/auth/logout-all` | Logout tất cả devices | Yes |
| GET | `/auth/sessions` | Danh sách sessions | Yes |
| DELETE | `/auth/sessions/:id` | Xóa session cụ thể | Yes |

## 7.1.3 Chat Endpoints (REST)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/conversations` | Danh sách conversations (paginated) |
| POST | `/conversations` | Tạo conversation mới |
| GET | `/conversations/:id` | Chi tiết conversation |
| PATCH | `/conversations/:id` | Cập nhật (name, avatar) |
| GET | `/conversations/:id/messages` | Messages (cursor pagination) |
| GET | `/conversations/:id/members` | Danh sách members |
| POST | `/conversations/:id/members` | Thêm members |
| DELETE | `/conversations/:id/members/:userId` | Xóa member |
| GET | `/conversations/:id/pinned` | Tin nhắn đã ghim |
| GET | `/conversations/:id/media` | Media gallery |
| GET | `/search/messages` | Full-text search messages |

### Messages Pagination

```
GET /conversations/:id/messages?cursor=2026-03-15T10:00:00Z&limit=30&dir=before

Response:
{
  "messages": [...],
  "nextCursor": "2026-03-15T09:30:00Z",
  "hasMore": true
}
```

## 7.1.4 Chat WebSocket Events

| Event (Client → Server) | Payload | Description |
|--------------------------|---------|-------------|
| `send_message` | `{id, conv_id, type, content, reply_to_id, metadata}` | Gửi tin nhắn |
| `typing_start` | `{conv_id}` | Bắt đầu gõ |
| `typing_stop` | `{conv_id}` | Ngừng gõ |
| `mark_read` | `{conv_id, message_id}` | Đánh dấu đã đọc |
| `sync` | `{last_synced_at}` | Sync missed messages |

| Event (Server → Client) | Payload | Description |
|--------------------------|---------|-------------|
| `new_message` | `{message}` | Tin nhắn mới |
| `message_ack` | `{id, status}` | ACK: sent/delivered |
| `message_read` | `{conv_id, user_id, message_id}` | Read receipt |
| `typing` | `{conv_id, user_id}` | Typing indicator |
| `presence` | `{user_id, status}` | Online/offline |
| `sync_response` | `{messages: [...]}` | Missed messages |

## 7.1.5 HR Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/hr/attendance/checkin` | Checkin |
| POST | `/hr/attendance/checkout` | Checkout |
| GET | `/hr/attendance` | Lịch sử chấm công (filter by date range) |
| GET | `/hr/attendance/summary` | Tổng hợp công kỳ lương |
| POST | `/hr/leaves` | Tạo đơn nghỉ |
| GET | `/hr/leaves` | Danh sách đơn nghỉ |
| PATCH | `/hr/leaves/:id/approve` | Duyệt đơn (Manager) |
| PATCH | `/hr/leaves/:id/reject` | Từ chối đơn (Manager) |
| GET | `/hr/leaves/balance` | Số ngày phép còn lại |
| GET | `/hr/holidays` | Danh sách ngày lễ |

## 7.1.6 Task Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/projects` | Danh sách projects (from Odoo cache) |
| GET | `/projects/:id/tasks` | Tasks theo project |
| GET | `/tasks/my` | Tasks assigned cho user |
| GET | `/tasks/:id` | Chi tiết task |
| POST | `/tasks/:id/timesheet` | Log timesheet entry |
| POST | `/tasks/ai-log` | AI parse natural language → timesheet |

## 7.1.7 Call Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/calls/initiate` | Bắt đầu cuộc gọi |
| POST | `/calls/:id/accept` | Accept cuộc gọi |
| POST | `/calls/:id/reject` | Reject cuộc gọi |
| POST | `/calls/:id/end` | Kết thúc cuộc gọi |
| GET | `/calls/:id/token` | Refresh Agora token |

## 7.1.8 Other Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/users/me` | Profile hiện tại |
| PATCH | `/users/me` | Cập nhật profile (avatar) |
| GET | `/users/:id` | Profile người khác (public info) |
| GET | `/users` | Danh sách users (contacts) |
| POST | `/upload` | Upload file lên Bunny.net |
| GET | `/reminders` | Danh sách reminders |
| POST | `/reminders` | Tạo reminder |
| PATCH | `/reminders/:id` | Cập nhật reminder |
| DELETE | `/reminders/:id` | Xóa reminder |
| GET | `/notifications` | Notification center |
| PATCH | `/notifications/read-all` | Mark all as read |
| GET | `/app/version` | Check app version |
| GET | `/health` | Health check |

