## 1. Monorepo Folder Structure

- [x] 1.1 Create `apps/api/.gitkeep` placeholder for NestJS backend
- [x] 1.2 Create `apps/mobile/.gitkeep` placeholder for Flutter app

## 2. Environment Configuration

- [x] 2.1 Create `.env.example` with local dev defaults (PostgreSQL, Redis, NestJS) and production placeholders (Odoo, Firebase, Agora, Bunny.net, AI)
- [x] 2.2 Create `.gitignore` covering Node.js, Flutter/Dart, Docker, IDE files, `.env`, and `requirements/info.md`

## 3. Docker Compose

- [x] 3.1 Create `docker-compose.yml` with PostgreSQL 16 service (port 5432, named volume, env vars from `.env`)
- [x] 3.2 Add Redis 7 service to `docker-compose.yml` (port 6379, named volume)
- [x] 3.3 Verify `docker compose up -d` starts both services and they accept connections

## 4. Documentation

- [x] 4.1 Create root `README.md` with project overview, tech stack, prerequisites, and local setup instructions

