# 6.1 Database Schema

## 6.1.1 Entity Relationship Overview

```
users ──────────┬──── conversations (via conversation_members)
                │
                ├──── messages
                │       ├── message_reactions
                │       └── message_attachments
                │
                ├──── attendance
                ├──── leave_requests
                ├──── user_sessions
                ├──── reminders
                └──── folders
                        └── folder_conversations

conversations ──┬──── conversation_members
                ├──── pinned_messages
                └──── messages

bots ───────────┬──── bot_permissions
                └──── (posts messages)

holidays (standalone)
ai_configs (standalone)
roles ──── user_roles
call_logs ──── call_participants
```

## 6.1.2 Core Tables

### users

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK, DEFAULT gen_random_uuid() | |
| odoo_uid | integer | UNIQUE, NOT NULL | Odoo user ID |
| email | varchar(255) | UNIQUE, NOT NULL | |
| name | varchar(255) | NOT NULL | |
| avatar_url | text | | Bunny.net URL |
| department | varchar(100) | | Phòng ban (from Odoo) |
| job_title | varchar(100) | | Chức vụ (from Odoo) |
| is_active | boolean | DEFAULT true | |
| last_seen_at | timestamptz | | Online status |
| created_at | timestamptz | DEFAULT now() | |
| updated_at | timestamptz | DEFAULT now() | |

### conversations

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK | |
| type | varchar(20) | NOT NULL | DIRECT / GROUP / SAVED |
| name | varchar(255) | | Group name (null for DIRECT) |
| avatar_url | text | | Group avatar |
| created_by | uuid | FK → users | |
| last_message_at | timestamptz | | Để sort conversation list |
| created_at | timestamptz | DEFAULT now() | |

### messages (PARTITIONED BY RANGE created_at)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK (composite with created_at) | Client-generated UUID |
| conv_id | uuid | NOT NULL, FK → conversations | |
| sender_id | uuid | NOT NULL, FK → users | |
| type | varchar(20) | DEFAULT 'text' | text/image/file/voice/video/system/call_log |
| content | text | | Text content |
| reply_to_id | uuid | | FK → messages |
| forwarded_from_id | uuid | | Original message ID |
| forwarded_from_sender | varchar(255) | | Original sender name |
| metadata | jsonb | | Extra data (file_url, duration, etc.) |
| search_vector | tsvector | GENERATED STORED | FTS index |
| created_at | timestamptz | NOT NULL, DEFAULT now() | Partition key |
| edited_at | timestamptz | | |
| deleted_at | timestamptz | | Soft delete |

**Partition:** Mỗi quý (Q1, Q2, Q3, Q4) tạo 1 partition.

**Indexes:**
- `(conv_id, created_at DESC) WHERE deleted_at IS NULL` — timeline scroll
- `(conv_id, date_trunc('day', created_at))` — jump to date
- `(reply_to_id) WHERE reply_to_id IS NOT NULL` — reply lookup
- `GIN (search_vector)` — full-text search
- `GIN (unaccent(content) gin_trgm_ops) WHERE deleted_at IS NULL` — trigram

### conversation_members

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| conv_id | uuid | PK (composite), FK → conversations | |
| user_id | uuid | PK (composite), FK → users | |
| role | varchar(20) | DEFAULT 'member' | admin / member |
| last_read_message_id | uuid | | Unread tracking |
| last_read_at | timestamptz | | |
| is_muted | boolean | DEFAULT false | |
| joined_at | timestamptz | DEFAULT now() | |

### message_reactions

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| message_id | uuid | PK (composite) | |
| user_id | uuid | PK (composite) | |
| emoji | varchar(10) | NOT NULL | Unicode emoji |
| created_at | timestamptz | DEFAULT now() | |

### attendance

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK | |
| user_id | uuid | FK → users | |
| checkin_at | timestamptz | NOT NULL | |
| checkout_at | timestamptz | | |
| checkin_lat | decimal(10,7) | | GPS latitude |
| checkin_lng | decimal(10,7) | | GPS longitude |
| checkout_lat | decimal(10,7) | | |
| checkout_lng | decimal(10,7) | | |
| device_id | varchar(255) | | |
| total_hours | decimal(4,2) | | Calculated |
| ot_hours | decimal(4,2) | | Calculated |
| odoo_synced | boolean | DEFAULT false | |
| odoo_synced_at | timestamptz | | |
| created_at | timestamptz | DEFAULT now() | |

### leave_requests

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK | |
| user_id | uuid | FK → users | |
| type | varchar(30) | NOT NULL | annual/sick/personal |
| start_date | date | NOT NULL | |
| end_date | date | NOT NULL | |
| reason | text | | |
| status | varchar(20) | DEFAULT 'draft' | draft/submitted/approved/rejected |
| approved_by | uuid | FK → users | |
| approved_at | timestamptz | | |
| reject_reason | text | | |
| odoo_synced | boolean | DEFAULT false | |
| created_at | timestamptz | DEFAULT now() | |

### user_sessions

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK | |
| user_id | uuid | FK → users | |
| device_id | varchar(255) | | |
| device_name | varchar(255) | | "iPhone 15", "Windows PC" |
| refresh_token_hash | varchar(255) | NOT NULL | bcrypt hash |
| fcm_token | text | | Firebase token |
| last_used_at | timestamptz | | |
| last_ip | varchar(45) | | |
| expires_at | timestamptz | NOT NULL | |
| created_at | timestamptz | DEFAULT now() | |

### call_logs

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | uuid | PK | |
| conv_id | uuid | FK → conversations | |
| caller_id | uuid | FK → users | |
| type | varchar(10) | NOT NULL | voice / video |
| status | varchar(20) | | completed/missed/rejected/no_answer |
| started_at | timestamptz | | |
| ended_at | timestamptz | | |
| duration_seconds | integer | | |
| agora_channel | varchar(255) | | |
| created_at | timestamptz | DEFAULT now() | |

