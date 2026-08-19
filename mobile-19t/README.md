# Nineteen Tech Internal App

Internal communication and HR management app for Nineteen Tech (19T).

## Tech Stack

| Layer              | Technology                        |
| ------------------ | --------------------------------- |
| Backend            | NestJS (TypeScript)               |
| Frontend           | Flutter (cross-platform)          |
| Database           | PostgreSQL 16                     |
| Cache / PubSub     | Redis 7                           |
| File Storage       | Bunny.net                         |
| Calls              | Agora.io                          |
| Push Notifications | Firebase FCM                      |
| AI                 | OpenAI / Anthropic (configurable) |

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- [Node.js](https://nodejs.org/) 20+ (for NestJS backend)
- [Flutter](https://flutter.dev/docs/get-started/install) 3.x (for mobile/desktop app)

## Local Development Setup

1. Copy environment variables:

   ```bash
   cp apps/api/.env.example apps/api/.env
   ```

   Mặc định đã có sẵn giá trị cho local dev, không cần sửa gì.

2. Start local services (PostgreSQL + Redis):

   ```bash
   docker compose up -d
   ```

3. Verify services are running:
   ```bash
   docker exec app_19t_postgres pg_isready -U app_19t
   docker exec app_19t_redis redis-cli ping
   ```

### Chạy NestJS API

```bash
cd apps/api
npm install
npm run start:dev
```

- API: `http://localhost:3000/api/v1`
- Swagger docs: `http://localhost:3000/api/docs`
- Health check: `GET /api/v1/health`

### Chạy Flutter app

```bash
cd apps/mobile
flutter pub get

# Dev environment
flutter run -t lib/main_dev.dart --dart-define-from-file=config/dev.json
flutter run -t lib/main_dev.dart --dart-define-from-file=config/dev.json -d chrome

# Staging
flutter run -t lib/main_staging.dart --dart-define-from-file=config/staging.json

# Production
flutter run -t lib/main_prod.dart --dart-define-from-file=config/prod.json
```

Build web (thêm `--no-tree-shake-icons` nếu path chứa Unicode):

```bash
flutter build web --no-tree-shake-icons
```

## Chạy Tests

### NestJS e2e tests

Yêu cầu Docker đang chạy (PostgreSQL + Redis phải sẵn sàng).

```bash
cd apps/api

# Chạy tất cả e2e tests
npm run test:e2e

# Chạy riêng auth tests
npx jest --config ./test/jest-e2e.json test/auth.e2e-spec.ts
```

### NestJS unit tests

```bash
cd apps/api
npm test
```

### Flutter analyze

```bash
cd apps/mobile
flutter analyze
```

## Project Structure

```
├── apps/
│   ├── api/                    # NestJS 11 backend
│   │   ├── src/
│   │   │   ├── config/         # ConfigModule + Joi validation
│   │   │   ├── modules/
│   │   │   │   ├── auth/       # Odoo SSO, JWT, RBAC, sessions
│   │   │   │   ├── chat/       # WebSocket gateway, messaging, conversations
│   │   │   │   ├── notification/ # Firebase FCM push notifications
│   │   │   │   ├── call/       # (placeholder)
│   │   │   │   ├── hr/         # (placeholder)
│   │   │   │   ├── task/       # (placeholder)
│   │   │   │   └── ...
│   │   │   └── main.ts
│   │   └── test/               # e2e tests
│   └── mobile/                 # Flutter cross-platform app
│       ├── lib/
│       │   ├── core/           # theme, router, config, network
│       │   ├── features/       # auth, chat, call, hr, task, profile, settings
│       │   └── shared/         # common widgets, utilities
│       └── config/             # dev.json, staging.json, prod.json
├── docker-compose.yml
└── README.md
```

## Biến môi trường

Xem `apps/api/.env.example` để biết đầy đủ. Các biến bắt buộc cho local dev:

| Biến                 | Mặc định           | Mô tả                    |
| -------------------- | ------------------ | ------------------------ |
| `DB_HOST`            | localhost          | PostgreSQL host          |
| `DB_PORT`            | 5432               | PostgreSQL port          |
| `DB_USER`            | app_19t            | PostgreSQL user          |
| `DB_NAME`            | app_19t_dev        | Database name            |
| `DB_PASSWORD`        | local_dev_password | PostgreSQL password      |
| `REDIS_HOST`         | localhost          | Redis host               |
| `REDIS_PORT`         | 6379               | Redis port               |
| `PORT`               | 3000               | NestJS port              |
| `JWT_ACCESS_SECRET`  | _(bắt buộc)_       | Secret cho access token  |
| `JWT_REFRESH_SECRET` | _(bắt buộc)_       | Secret cho refresh token |

## Chat Module Setup

Chat module (FR-CHAT Phase 1) đã được implement. Dưới đây là các bước cần thực hiện để hoàn tất.

### 1. Chạy database migrations

```bash
cd apps/api
npx typeorm migration:run -d data-source.ts
```

Migrations sẽ tạo: `conversations`, `conversation_members`, `messages` (partitioned), `message_reactions`, cùng với indexes và extensions (`unaccent`, `pg_trgm`).

### 2. Drift code generation (Flutter)

Drift cần chạy `build_runner` để generate các file `.g.dart`:

```bash
cd apps/mobile
dart run build_runner build --delete-conflicting-outputs
```

Cần chạy lại mỗi khi thay đổi Drift tables hoặc DAOs.

### 3. Firebase Push Notifications

Code đã implement đầy đủ (PushNotificationService, FCM token management, notification tap handler). Cần setup Firebase project config:

1. Tạo Firebase project tại [Firebase Console](https://console.firebase.google.com/)
2. Thêm Android app → download `google-services.json` → đặt vào `apps/mobile/android/app/`
3. Thêm iOS app → download `GoogleService-Info.plist` → đặt vào `apps/mobile/ios/Runner/`
4. Lấy Service Account Key (JSON) → set vào `apps/api/.env`:
   ```
   FIREBASE_PROJECT_ID=your-project-id
   FIREBASE_SERVICE_ACCOUNT_KEY={"type":"service_account",...}
   ```

Dependencies (`firebase_core`, `firebase_messaging`) đã có trong pubspec.yaml. Firebase.initializeApp() đã được gọi trong tất cả entry points. `PushNotificationService` đã implement đầy đủ tại `lib/core/notifications/push_notification_service.dart`.

Nếu chưa setup Firebase, chat vẫn hoạt động bình thường — chỉ push notification cho offline users bị disable.

### 4. Partition management

Messages table sử dụng quarterly partitions. Hiện tại đã tạo Q1 2026 và Q2 2026. Cần tạo partition mới trước mỗi quý:

```sql
-- Q3 2026
CREATE TABLE messages_2026_q3 PARTITION OF messages
  FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');

-- Q4 2026
CREATE TABLE messages_2026_q4 PARTITION OF messages
  FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');
```

### 5. WebSocket endpoint

WebSocket endpoint: `ws://localhost:3000/ws`

Auth flow:

1. Client connect → server chờ auth message trong 5 giây
2. Client gửi: `{ "event": "auth", "data": { "token": "<jwt>" } }`
3. Server trả: `{ "event": "auth_success", "data": { "userId": "..." } }`

### 6. REST API endpoints mới

| Method  | Path                                 | Mô tả                        |
| ------- | ------------------------------------ | ---------------------------- |
| `POST`  | `/api/v1/conversations`              | Tạo direct conversation      |
| `GET`   | `/api/v1/conversations`              | Danh sách conversations      |
| `GET`   | `/api/v1/conversations/:id`          | Chi tiết conversation        |
| `GET`   | `/api/v1/conversations/:id/messages` | Messages (cursor pagination) |
| `PATCH` | `/api/v1/auth/sessions/fcm-token`    | Cập nhật FCM token           |
| `GET`   | `/api/v1/search/messages`            | Search (501 — Phase 2)       |

### 7. Verification checklist (manual)

Sau khi setup xong, cần verify:

- [ ] Migration chạy thành công: `npx typeorm migration:run -d data-source.ts`
- [ ] WebSocket connect + auth + heartbeat hoạt động
- [ ] Gửi tin nhắn end-to-end: Flutter → WS → DB → Redis → recipient
- [ ] Offline queue: gửi khi offline, nhận khi reconnect
- [ ] Push notification: offline user nhận FCM (hoặc skip nếu chưa config Firebase)
- [ ] Cursor pagination: infinite scroll load older messages
- [ ] Unread count: badge cập nhật khi có tin nhắn mới, reset khi đọc
- [ ] `cd apps/api && npm run lint && npm run build` — no errors
- [ ] `cd apps/mobile && flutter analyze` — no errors
