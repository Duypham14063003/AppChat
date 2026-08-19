# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Monorepo for "Nineteen Tech Internal App" — a Slack/Teams-like tool for a Vietnamese company (<50 employees). Two apps: NestJS API backend and Flutter mobile/web frontend.

### Git Remotes
- `origin` → `https://github.com/paulnguyendev/mobile-19t.git` (monorepo)
- `backend-api` → `https://github.com/paulnguyendev/backend-mobile-19t.git` (backend only, use `git subtree push/pull --prefix=apps/api backend-api main`)

### Environment Variables
- `.env` and `.env.example` live in `apps/api/` (not repo root). Copy `apps/api/.env.example` → `apps/api/.env` for local dev.

## Commands

### Infrastructure (root)
```bash
docker compose up -d        # start PostgreSQL + Redis
```

### API (`cd apps/api`)
```bash
npm run start:dev           # dev server with watch
npm run build               # production build
npm run lint                # ESLint --fix
npm test                    # unit tests (Jest)
npm run test:e2e            # e2e tests (requires Docker)
npm run migration:run       # run TypeORM migrations
npm run migration:revert    # revert last migration
```

### Mobile (`cd apps/mobile`)
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # Drift + Riverpod codegen (run after model changes)
flutter analyze                                           # lint

# Run by environment
flutter run -t lib/main_dev.dart --dart-define-from-file=config/dev.json
flutter run -t lib/main_dev.dart --dart-define-from-file=config/dev_web.json -d chrome
flutter run -t lib/main_staging.dart --dart-define-from-file=config/staging.json
flutter run -t lib/main_prod.dart --dart-define-from-file=config/prod.json

flutter build web --no-tree-shake-icons
```

## Architecture

### Backend (`apps/api/src/`)
- `modules/` — feature modules: `auth`, `chat`, `notification` (implemented); `call`, `hr`, `task`, `ai`, `profile`, `reminder` (placeholders)
- `common/` — guards, filters, interceptors, pipes
- `config/` — Joi-validated env config
- `migrations/` — TypeORM migrations

Key patterns:
- **WebSocket auth:** Raw `ws` (no Socket.io). Client sends `{ event: "auth", data: { token } }` within 5s of connecting. `ConnectionManagerService` manages connections.
- **Chat fan-out:** `ChatGateway` → `ChatService` → PostgreSQL + Redis Pub/Sub → other connected clients. Offline users get FCM push via BullMQ.
- **Link preview:** `POST /chat/link-preview` fetches Open Graph metadata via `open-graph-scraper`. Redis cache (24h TTL), rate limit 10/min/user, SSRF protection (block private IPs). Preview stored in `message.metadata.linkPreview`.
- **Messages table:** PostgreSQL range-partitioned by quarter (Q1/Q2 2026 partitions exist). FTS via `tsvector`/`unaccent`.
- **Odoo sync:** BullMQ job every 15 minutes. Odoo is source of truth for HR/task data; app is source of truth for attendance.
- **JWT:** Access tokens 15m, refresh tokens 30d.

### Frontend (`apps/mobile/lib/`)
- `core/` — config, database (Drift/SQLite), network (Dio), notifications, providers, router, storage, theme
- `features/` — `auth`, `chat` (implemented); `call`, `hr`, `task`, `profile`, `settings` (stubs)
- `shared/` — common widgets/utils

Key patterns:
- **State:** Riverpod 2 with code generation (`riverpod_annotation`). Features use `AsyncNotifier` providers.
- **Routing:** `go_router` with a `ShellRoute` wrapping authenticated routes. Auth redirect in router's `redirect` callback watches `authNotifierProvider`.
- **Data:** Feature-level repositories + Riverpod providers. Chat has `offline_queue_service.dart` for offline support.
- **Multi-env:** Three entry points (`main_dev/staging/prod.dart`) with `config/*.json` passed via `--dart-define-from-file`.
- **Codegen:** Drift (local DB) and Riverpod providers both use `build_runner`. Run after any model or provider changes.
- **Drift schema:** Version 5. `LocalConversations` includes `unreadMentionCount`.
- **Mentions:** `@user` and `@all` in group chat. Mention entities stored in `message.metadata.mentions` as `[{offset, length, user_id, name}]`. `@all` uses `user_id: "all"`. Mentions override mute for push notifications. `MessageInputBar` shows autocomplete overlay on `@` in group chats. `MessageBubble` renders mentions in gold (`AppColors.gold`). `ConversationTile` shows `@` badge when `unreadMentionCount > 0`.
