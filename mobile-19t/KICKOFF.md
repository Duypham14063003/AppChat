# Nineteen Tech Internal App — Kickoff & Progress Tracker

> File này ghi lại toàn bộ thông tin khởi đầu, quyết định kỹ thuật, và tiến độ triển khai.
> Cập nhật liên tục trong suốt quá trình phát triển.

---

## 1. Thông tin dự án

| Mục | Chi tiết |
|-----|---------|
| Tên dự án | Nineteen Tech Internal App |
| Công ty | Nineteen Tech (19T) — https://19t.vn |
| Quy mô | < 50 nhân viên |
| Ngày bắt đầu | 2026-03-__ *(điền ngày thực tế)* |
| Target MVP | 2026-__-__ *(ước tính 3-4 tuần sau ngày bắt đầu)* |
| Team size | __ dev *(điền số lượng)* |
| Repo URL | *(điền khi tạo repo)* |

---

## 2. Tài liệu tham chiếu

| Tài liệu | Đường dẫn |
|-----------|-----------|
| Brief gốc | `requirements/brief.md` |
| Brainstorm chi tiết | `requirements/brainstom.md` |
| SRS đầy đủ | `srs/README.md` |
| Mockup UI (Mobile) | `requirements/nineteen_tech_chat_mockup.html` |
| Mockup UI (Desktop) | `requirements/nineteen_tech_pc_app.html` |
| Third-party libraries | `requirements/third_party_libraries.html` |
| Risk matrix | `srs/08-appendices/risk-matrix.md` |

---

## 3. Quyết định kỹ thuật đã chốt

### 3.1 Tech Stack

| Layer | Quyết định | Lý do |
|-------|-----------|-------|
| Frontend | Flutter (single codebase) | Cross-platform: iOS, Android, Windows, macOS, Web |
| State Management | Riverpod | Reactive, code-gen, select() cho rebuild tối ưu |
| Local DB | Drift (SQLite) | Type-safe, reactive, hỗ trợ Desktop/Web (sqflite không) |
| Navigation | go_router | Official Flutter, deep link, web URL support |
| Backend | NestJS (TypeScript) | Modular, WebSocket built-in, ecosystem mạnh |
| ORM | TypeORM | Raw SQL cho partition queries chat (Prisma hạn chế) |
| Database | PostgreSQL 16 | Partition by quarter, FTS tsvector+GIN, unaccent tiếng Việt |
| Cache + PubSub | Redis 7 | Pub/Sub fan-out + BullMQ jobs + API cache (1 instance, 3 vai trò) |
| File Storage | Bunny.net | CDN + object storage, giá rẻ hơn S3 |
| Call | Agora.io (SFU) | Cross-platform, free 10K min/month, SDK Flutter có sẵn |
| Push Notification | Firebase FCM | Free tier đủ < 50 người, iOS + Android + Web |
| AI | OpenAI / Anthropic (configurable) | Gateway pattern, switch provider không đổi code |

### 3.2 Quyết định kiến trúc

| Quyết định | Chọn | Lý do |
|-----------|------|-------|
| Monorepo vs Separate repos | **Monorepo** | Team nhỏ, dễ share types, 1 repo quản lý |
| Encryption | **TLS only** (không E2E) | Internal app, E2E quá phức tạp, cản search/backup |
| WebSocket lib | **ws thuần** (không Socket.io) | Nhẹ hơn, Flutter dùng `web_socket_channel` |
| Odoo sync | **Batch** (BullMQ mỗi 15 phút) | Odoo down không ảnh hưởng UX, app là source of truth cho attendance |
| Message partition | **By time** (quarterly) | Hot/cold data rõ ràng, archive dễ, distribution đều |
| Chat pagination | **Cursor-based** (timestamp) | OFFSET là anti-pattern cho chat, cursor luôn O(1) |

### 3.3 Quyết định chưa chốt — CẦN QUYẾT ĐỊNH

| # | Vấn đề | Options | Ghi chú |
|---|--------|---------|---------|
| D1 | Monorepo tool | Nx / Turborepo / None | Nx nếu muốn task caching, None nếu đơn giản |
| D2 | CI/CD platform | GitHub Actions / GitLab CI | Tùy repo host |
| D3 | Hosting server | VPS / Cloud (AWS/GCP) | VPS đơn giản cho < 50 users |
| D4 | Domain API | api.19t.vn / app-api.19t.vn | Cần setup DNS |
| D5 | iOS distribution | TestFlight / Ad-hoc | TestFlight cần Apple Developer account |
| D6 | Android distribution | APK direct / Play Store internal | APK direct nhanh hơn |
| D7 | Desktop distribution | Direct download / Auto-update | Auto-update tốt hơn nhưng phức tạp hơn |

---

## 4. Credentials & Config

> ⚠️ **KHÔNG commit file này nếu chứa secrets thật. Dùng .env cho production.**

### Development (local)

```env
# PostgreSQL (local Docker)
DB_HOST=localhost
DB_PORT=5432
DB_USER=app_19t
DB_NAME=app_19t_dev
DB_PASSWORD=local_dev_password

# Redis (local Docker)
REDIS_HOST=localhost
REDIS_PORT=6379

# NestJS
PORT=3000
JWT_ACCESS_SECRET=dev_access_secret_change_me
JWT_REFRESH_SECRET=dev_refresh_secret_change_me
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=30d
```

### Staging / Production

```env
# PostgreSQL (production — từ requirements/info.md)
DB_HOST=103.97.126.78
DB_PORT=5432
DB_USER=app_19t
DB_NAME=app_19t
DB_PASSWORD=********

# Odoo
ODOO_URL=https://erp.19t.vn
ODOO_DB=erp_oddo
ODOO_API_KEY=********
ODOO_SERVICE_USERNAME=meeting-service@19t.vn
ODOO_SERVICE_PASSWORD=********

# Firebase (cần tạo project)
FIREBASE_PROJECT_ID=
FIREBASE_SERVICE_ACCOUNT_KEY=

# Agora (cần tạo project)
AGORA_APP_ID=
AGORA_APP_CERTIFICATE=

# Bunny.net (cần tạo storage zone)
BUNNY_STORAGE_ZONE=
BUNNY_STORAGE_API_KEY=
BUNNY_CDN_URL=

# AI
AI_PROVIDER=openai
AI_BASE_URL=https://api.openai.com/v1
AI_API_KEY=
AI_MODEL=gpt-4o
```

---

## 5. Monorepo Structure (dự kiến)

```
nineteen-tech-app/
├── apps/
│   ├── api/                    ← NestJS backend
│   │   ├── src/
│   │   │   ├── modules/
│   │   │   │   ├── auth/
│   │   │   │   ├── chat/
│   │   │   │   ├── call/
│   │   │   │   ├── hr/
│   │   │   │   ├── task/
│   │   │   │   ├── profile/
│   │   │   │   ├── ai/
│   │   │   │   ├── notification/
│   │   │   │   └── reminder/
│   │   │   ├── common/         ← guards, filters, interceptors, pipes
│   │   │   ├── config/         ← env validation, config module
│   │   │   └── main.ts
│   │   ├── test/
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   └── mobile/                 ← Flutter app
│       ├── lib/
│       │   ├── core/
│       │   │   ├── theme/      ← AppColors, typography, brand tokens
│       │   │   ├── network/    ← Dio client, WebSocket manager
│       │   │   ├── storage/    ← Secure storage, Drift DB
│       │   │   ├── router/     ← go_router config
│       │   │   └── providers/  ← Riverpod global providers
│       │   ├── features/
│       │   │   ├── auth/
│       │   │   ├── chat/
│       │   │   ├── call/
│       │   │   ├── hr/
│       │   │   ├── task/
│       │   │   ├── profile/
│       │   │   └── settings/
│       │   ├── shared/         ← common widgets, utils
│       │   ├── main_dev.dart
│       │   ├── main_staging.dart
│       │   └── main_prod.dart
│       ├── test/
│       └── pubspec.yaml
│
├── docker-compose.yml          ← PostgreSQL + Redis (local dev)
├── docker-compose.prod.yml     ← Production config
├── .env.example
├── .gitignore
└── README.md
```

---

## 6. Lộ trình triển khai & Tiến độ

### Phase 1 — Nền tảng + MVP (4-6 tuần)

| # | Task | Ước tính | Bắt đầu | Hoàn thành | Status |
|---|------|----------|---------|------------|--------|
| 0.1 | Tạo monorepo + Docker Compose | 0.5 ngày | | | ⬜ Todo |
| 0.2 | NestJS project scaffold | 0.5 ngày | | | ⬜ Todo |
| 0.3 | Flutter project scaffold + flavors | 0.5 ngày | | | ⬜ Todo |
| 0.4 | Git repo + branch strategy | 0.5 ngày | | | ⬜ Todo |
| 1.1 | NestJS: Odoo SSO auth endpoint | 1 ngày | | | ⬜ Todo |
| 1.2 | NestJS: JWT access + refresh + rotation | 1.5 ngày | | | ⬜ Todo |
| 1.3 | NestJS: Auth guards + RBAC | 1 ngày | | | ⬜ Todo |
| 1.4 | NestJS: User sessions (multi-device) | 0.5 ngày | | | ⬜ Todo |
| 1.5 | Flutter: Login screen + secure storage | 1 ngày | | | ⬜ Todo |
| 1.6 | Flutter: Dio interceptor (auto refresh) | 0.5 ngày | | | ⬜ Todo |
| 1.7 | Flutter: Auto-login on start | 0.5 ngày | | | ⬜ Todo |
| 2.1 | DB: TypeORM entities + migrations (core) | 1 ngày | | | ⬜ Todo |
| 2.2 | DB: Messages partition setup | 0.5 ngày | | | ⬜ Todo |
| 2.3 | NestJS: WebSocket Gateway + JWT handshake | 1 ngày | | | ⬜ Todo |
| 2.4 | NestJS: Redis Pub/Sub setup | 0.5 ngày | | | ⬜ Todo |
| 2.5 | Flutter: WebSocket manager (connect/reconnect) | 1 ngày | | | ⬜ Todo |
| 2.6 | Flutter: Drift local DB schema | 1 ngày | | | ⬜ Todo |
| 3.1 | NestJS: Send message (WS → DB → Redis) | 1.5 ngày | | | ⬜ Todo |
| 3.2 | NestJS: Conversation CRUD + pagination | 1 ngày | | | ⬜ Todo |
| 3.3 | NestJS: Message status (sent/delivered/read) | 1 ngày | | | ⬜ Todo |
| 3.4 | NestJS: BullMQ + FCM push (offline) | 1 ngày | | | ⬜ Todo |
| 3.5 | Flutter: Chat list screen | 1.5 ngày | | | ⬜ Todo |
| 3.6 | Flutter: Chat screen (bubbles + optimistic UI) | 2 ngày | | | ⬜ Todo |
| 3.7 | Flutter: Offline queue + reconnect sync | 1.5 ngày | | | ⬜ Todo |
| 3.8 | Flutter: Unread count + badge | 0.5 ngày | | | ⬜ Todo |
| 4.1 | NestJS: Firebase Admin + FCM send | 0.5 ngày | | | ⬜ Todo |
| 4.2 | NestJS: FCM token management | 0.5 ngày | | | ⬜ Todo |
| 4.3 | Flutter: firebase_messaging setup | 1 ngày | | | ⬜ Todo |
| 4.4 | Flutter: Tap notification → navigate | 0.5 ngày | | | ⬜ Todo |
| T.1 | Tests: Auth integration tests | 1 ngày | | | ⬜ Todo |
| T.2 | Tests: Chat WebSocket tests | 1 ngày | | | ⬜ Todo |

### Phase 2 — Chat đầy đủ + Call (4-6 tuần)

| # | Task | Ước tính | Status |
|---|------|----------|--------|
| 5.1 | Group chat (create, manage, fan-out) | 2 ngày | ⬜ Todo |
| 5.2 | Gửi ảnh (upload Bunny.net + thumbnail) | 1.5 ngày | ⬜ Todo |
| 5.3 | Gửi file đính kèm | 1 ngày | ⬜ Todo |
| 5.4 | Voice message (record + upload + waveform) | 2 ngày | ⬜ Todo |
| 5.5 | Reply tin nhắn (swipe to reply) | 1 ngày | ⬜ Todo |
| 5.6 | Reaction (emoji picker + long press) | 1 ngày | ⬜ Todo |
| 5.7 | Ghim tin nhắn | 0.5 ngày | ⬜ Todo |
| 5.8 | Xóa / Chỉnh sửa tin nhắn | 1 ngày | ⬜ Todo |
| 5.9 | Typing indicator | 0.5 ngày | ⬜ Todo |
| 5.10 | Online/Offline status | 0.5 ngày | ⬜ Todo |
| 5.11 | Full-text search (server FTS) | 1.5 ngày | ⬜ Todo |
| 6.1 | Agora: Token generation (NestJS) | 0.5 ngày | ⬜ Todo |
| 6.2 | Agora: Voice call 1-1 | 2 ngày | ⬜ Todo |
| 6.3 | Agora: Video call 1-1 | 1 ngày | ⬜ Todo |
| 6.4 | Incoming call screen (per platform) | 2 ngày | ⬜ Todo |
| 6.5 | Call controls (mute, speaker, camera) | 1 ngày | ⬜ Todo |
| 6.6 | Call log trong conversation | 0.5 ngày | ⬜ Todo |

### Phase 3 — HR + Task + AI (3-4 tuần)

| # | Task | Ước tính | Status |
|---|------|----------|--------|
| 7.1 | HR: Checkin/Checkout (GPS + local + server) | 2 ngày | ⬜ Todo |
| 7.2 | HR: OT calculation | 1 ngày | ⬜ Todo |
| 7.3 | HR: Leave request workflow | 2 ngày | ⬜ Todo |
| 7.4 | HR: Attendance history + summary | 1.5 ngày | ⬜ Todo |
| 7.5 | HR: Odoo batch sync (BullMQ) | 1.5 ngày | ⬜ Todo |
| 8.1 | Task: Pull projects/tasks từ Odoo | 1.5 ngày | ⬜ Todo |
| 8.2 | Task: Kanban board + List view | 2 ngày | ⬜ Todo |
| 8.3 | Task: AI log task (natural language) | 2 ngày | ⬜ Todo |
| 8.4 | Task: Manual timesheet entry | 1 ngày | ⬜ Todo |
| 9.1 | Profile: User profile + stats | 1.5 ngày | ⬜ Todo |
| 9.2 | AI: Gateway config (admin settings) | 1 ngày | ⬜ Todo |

### Phase 4 — Polish (liên tục)

| # | Task | Ước tính | Status |
|---|------|----------|--------|
| 10.1 | Bot framework | 2 ngày | ⬜ Todo |
| 10.2 | Reminder engine (BullMQ delayed) | 1.5 ngày | ⬜ Todo |
| 10.3 | Notification center | 1 ngày | ⬜ Todo |
| 10.4 | Saved messages + Folders | 1.5 ngày | ⬜ Todo |
| 10.5 | Desktop layout (3-column) | 2 ngày | ⬜ Todo |
| 10.6 | App update mechanism | 1 ngày | ⬜ Todo |
| 10.7 | Load testing (k6/Artillery) | 1 ngày | ⬜ Todo |

---

## 7. Checklist trước khi code

- [ ] Tạo Git repo
- [ ] Setup Docker Compose (PostgreSQL + Redis) chạy local
- [ ] Tạo Firebase project → lấy credentials
- [ ] Tạo Agora project → lấy App ID + Certificate
- [ ] Tạo Bunny.net storage zone → lấy API key
- [ ] Setup domain DNS (api.19t.vn → server IP)
- [ ] Tạo Apple Developer account (nếu cần TestFlight)
- [ ] Verify Odoo API accessible (test curl tới erp.19t.vn)
- [ ] Chốt các quyết định D1-D7 ở mục 3.3

---

## 8. Log ghi chú hàng ngày

> Ghi lại quyết định, vấn đề gặp phải, thay đổi so với plan.

### 2026-03-__

```
- Bắt đầu dự án
- ...
```

<!--
Template cho mỗi ngày:

### 2026-MM-DD
```
- Làm gì hôm nay:
- Vấn đề gặp phải:
- Quyết định thay đổi:
- Ngày mai làm gì:
```
-->

