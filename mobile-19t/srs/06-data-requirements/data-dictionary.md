# 6.2 Data Dictionary

## users

| Field | Type | Null | Description |
|-------|------|------|-------------|
| id | uuid | NO | Primary key, auto-generated |
| odoo_uid | integer | NO | Odoo user ID, dùng để map với Odoo |
| email | varchar(255) | NO | Email đăng nhập (unique) |
| name | varchar(255) | NO | Họ tên đầy đủ |
| avatar_url | text | YES | URL ảnh đại diện trên Bunny.net |
| department | varchar(100) | YES | Phòng ban, sync từ Odoo |
| job_title | varchar(100) | YES | Chức vụ, sync từ Odoo |
| is_active | boolean | NO | false = tài khoản bị deactivate |
| last_seen_at | timestamptz | YES | Lần cuối online, dùng cho presence |
| created_at | timestamptz | NO | Thời điểm tạo record |
| updated_at | timestamptz | NO | Thời điểm cập nhật cuối |

## conversations

| Field | Type | Null | Description |
|-------|------|------|-------------|
| id | uuid | NO | Primary key |
| type | varchar(20) | NO | DIRECT: chat 1-1, GROUP: nhóm, SAVED: tin đã lưu |
| name | varchar(255) | YES | Tên group (null cho DIRECT) |
| avatar_url | text | YES | Avatar group |
| created_by | uuid | YES | User tạo group |
| last_message_at | timestamptz | YES | Timestamp tin nhắn cuối, dùng sort danh sách |

## messages

| Field | Type | Null | Description |
|-------|------|------|-------------|
| id | uuid | NO | Client-generated UUID (idempotency key) |
| conv_id | uuid | NO | Conversation chứa tin nhắn |
| sender_id | uuid | NO | Người gửi |
| type | varchar(20) | NO | text/image/file/voice/video/system/call_log |
| content | text | YES | Nội dung text (null cho media-only) |
| reply_to_id | uuid | YES | ID tin nhắn được reply |
| forwarded_from_id | uuid | YES | ID tin nhắn gốc khi forward |
| metadata | jsonb | YES | Data bổ sung theo type (xem bảng dưới) |
| search_vector | tsvector | NO | Auto-generated, dùng cho FTS |
| created_at | timestamptz | NO | Partition key, thời điểm tạo (UTC) |
| edited_at | timestamptz | YES | Thời điểm edit (null nếu chưa edit) |
| deleted_at | timestamptz | YES | Soft delete timestamp |

### messages.metadata theo type

| type | metadata schema |
|------|----------------|
| text | `null` hoặc `{}` |
| image | `{"url": "...", "thumbnail_url": "...", "width": 1920, "height": 1080, "size_bytes": 524288}` |
| file | `{"url": "...", "filename": "report.pdf", "mime_type": "application/pdf", "size_bytes": 1048576}` |
| voice | `{"url": "...", "duration_ms": 15000, "waveform": [0.1, 0.5, 0.8, ...]}` |
| video | `{"url": "...", "thumbnail_url": "...", "duration_ms": 30000, "width": 1280, "height": 720}` |
| system | `{"event": "member_joined", "target_user_id": "..."}` |
| call_log | `{"call_id": "...", "type": "voice", "duration_seconds": 332, "status": "completed"}` |

## attendance

| Field | Type | Null | Description |
|-------|------|------|-------------|
| id | uuid | NO | Primary key |
| user_id | uuid | NO | Nhân viên |
| checkin_at | timestamptz | NO | Thời điểm checkin (UTC) |
| checkout_at | timestamptz | YES | Thời điểm checkout (null nếu chưa checkout) |
| checkin_lat | decimal(10,7) | YES | Vĩ độ GPS khi checkin |
| checkin_lng | decimal(10,7) | YES | Kinh độ GPS khi checkin |
| total_hours | decimal(4,2) | YES | Tổng giờ làm = checkout - checkin |
| ot_hours | decimal(4,2) | YES | Giờ tăng ca = max(0, total - standard) |
| odoo_synced | boolean | NO | Đã sync lên Odoo chưa |

## leave_requests

| Field | Type | Null | Description |
|-------|------|------|-------------|
| id | uuid | NO | Primary key |
| user_id | uuid | NO | Người xin nghỉ |
| type | varchar(30) | NO | annual: phép năm, sick: ốm, personal: việc riêng |
| start_date | date | NO | Ngày bắt đầu nghỉ |
| end_date | date | NO | Ngày kết thúc nghỉ |
| reason | text | YES | Lý do xin nghỉ |
| status | varchar(20) | NO | draft → submitted → approved/rejected |
| approved_by | uuid | YES | Manager duyệt |
| reject_reason | text | YES | Lý do từ chối (nếu rejected) |

## user_sessions

| Field | Type | Null | Description |
|-------|------|------|-------------|
| id | uuid | NO | Primary key |
| user_id | uuid | NO | User sở hữu session |
| device_id | varchar(255) | YES | Unique device identifier |
| device_name | varchar(255) | YES | Tên hiển thị: "iPhone 15 Pro", "Windows PC" |
| refresh_token_hash | varchar(255) | NO | bcrypt hash của refresh token |
| fcm_token | text | YES | Firebase Cloud Messaging token |
| expires_at | timestamptz | NO | Thời điểm refresh token hết hạn |

## Quy ước chung

- Tất cả timestamp: `timestamptz` (UTC), không dùng `timestamp without time zone`
- Tất cả ID: `uuid`, generated bởi `gen_random_uuid()` (server) hoặc client (messages)
- Soft delete: dùng `deleted_at` thay vì xóa thật
- Audit fields: `created_at`, `updated_at` trên mọi table

