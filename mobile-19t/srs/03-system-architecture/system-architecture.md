# 3. System Architecture

## 3.1 Architecture Overview

Hệ thống sử dụng kiến trúc **Modular Monolith** cho backend (NestJS) với khả năng tách microservice khi cần scale. Frontend là Flutter single codebase cho tất cả platforms.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CLIENT LAYER (Flutter)                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │   iOS    │ │ Android  │ │ Windows  │ │  macOS   │ │   Web    │ │
│  └─────┬────┘ └─────┬────┘ └─────┬────┘ └─────┬────┘ └─────┬────┘ │
│        └────────────┼────────────┼────────────┼────────────┘       │
│                     │  Drift (SQLite local cache)                   │
│                     │  Riverpod (State management)                  │
│                     │  go_router (Navigation)                       │
└─────────────────────┼───────────────────────────────────────────────┘
                      │ HTTPS (REST) + WSS (WebSocket)
┌─────────────────────▼───────────────────────────────────────────────┐
│                    API LAYER (NestJS)                                │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    API Gateway                                │   │
│  │  JWT Auth Guard · Rate Limiter · CORS · Helmet · Swagger     │   │
│  └──────────┬───────────┬───────────┬───────────┬───────────────┘   │
│  ┌──────────▼──┐ ┌──────▼──────┐ ┌──▼────────┐ ┌▼────────────┐    │
│  │ Auth Module │ │ Chat Module │ │ HR Module │ │ Task Module │    │
│  │             │ │ WS Gateway  │ │           │ │             │    │
│  └──────┬──────┘ └──────┬──────┘ └─────┬─────┘ └──────┬──────┘    │
│  ┌──────▼──────┐ ┌──────▼──────┐ ┌─────▼─────┐ ┌──────▼──────┐    │
│  │ AI Module  │ │Notif Module│ │Remind Mod │ │Profile Mod │    │
│  └─────────────┘ └─────────────┘ └───────────┘ └─────────────┘    │
└──────┬──────────────┬──────────────┬────────────────────────────────┘
       │              │              │
┌──────▼──────┐ ┌─────▼─────┐ ┌─────▼─────┐
│ PostgreSQL  │ │   Redis   │ │  BullMQ   │
│   16        │ │    7      │ │  Queues   │
│ (Primary DB)│ │(Pub/Sub + │ │(Job Queue)│
│             │ │  Cache)   │ │           │
└─────────────┘ └───────────┘ └───────────┘
```

## 3.2 Tech Stack

### 3.2.1 Frontend

| Component | Technology | Version | Vai trò |
|-----------|-----------|---------|---------|
| Framework | Flutter | 3.x (stable) | Cross-platform UI |
| Language | Dart | 3.x | Programming language |
| State Mgmt | Riverpod | 2.x | Reactive state management |
| Navigation | go_router | latest | Declarative routing + deep link |
| Local DB | Drift | 2.x | SQLite wrapper, offline cache |
| HTTP | Dio | 5.x | REST API client |
| WebSocket | web_socket_channel | latest | Real-time communication |
| Secure Storage | flutter_secure_storage | latest | JWT token storage |

### 3.2.2 Backend

| Component | Technology | Version | Vai trò |
|-----------|-----------|---------|---------|
| Framework | NestJS | 10.x | API + WebSocket server |
| Language | TypeScript | 5.x | Type-safe backend |
| ORM | TypeORM | 0.3.x | Database access + migrations |
| Auth | @nestjs/jwt + passport | latest | JWT authentication |
| WebSocket | @nestjs/websockets | latest | Real-time gateway |
| Queue | BullMQ | latest | Job queue (delivery, sync, reminder) |
| Cache | ioredis | latest | Redis client |
| Validation | class-validator | latest | DTO validation |

### 3.2.3 Infrastructure

| Component | Technology | Vai trò |
|-----------|-----------|---------|
| Database | PostgreSQL 16 | Primary data store (partitioned) |
| Cache/PubSub | Redis 7 | Pub/Sub + BullMQ + API cache |
| File Storage | Bunny.net | CDN + object storage |
| Voice/Video | Agora.io | Real-time communication (SFU) |
| Push Notification | Firebase FCM | Mobile + Web push |
| AI Providers | OpenAI / Anthropic / Custom | AI features |
| ERP | Odoo 17 (erp.19t.vn) | HR data, Projects, Auth source |

## 3.3 Deployment Topology

```
┌─────────────────────────────────────────────┐
│              Production Server               │
│  ┌─────────────┐  ┌─────────────────────┐   │
│  │  NestJS     │  │  PostgreSQL 16      │   │
│  │  (Docker)   │  │  (Docker/Native)    │   │
│  │  Port 3000  │  │  Port 5432          │   │
│  └─────────────┘  └─────────────────────┘   │
│  ┌─────────────┐  ┌─────────────────────┐   │
│  │  Redis 7    │  │  Nginx (Reverse     │   │
│  │  (Docker)   │  │  Proxy + SSL)       │   │
│  │  Port 6379  │  │  Port 443           │   │
│  └─────────────┘  └─────────────────────┘   │
└─────────────────────────────────────────────┘
```

### 3.3.1 Environments

| Environment | Mục đích | Database | API URL |
|-------------|----------|----------|---------|
| Development | Local dev | localhost:5432 | localhost:3000 |
| Staging | Team testing | staging DB | staging.api.19t.vn |
| Production | Live | production DB (103.97.126.78) | api.19t.vn |

## 3.4 Communication Protocols

| Giao thức | Sử dụng cho | Chi tiết |
|-----------|-------------|---------|
| HTTPS (REST) | CRUD operations, auth, HR, tasks | JSON payload, JWT Bearer auth |
| WSS (WebSocket) | Chat real-time, typing, presence | Persistent connection, JWT handshake |
| FCM | Push notification | Firebase Admin SDK từ backend |
| Agora SDK | Voice/Video media | Client ↔ Agora SFU, token từ backend |
| HTTP | Bunny.net upload | Multipart upload qua backend proxy |

