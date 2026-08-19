# 6.3 Data Flow

## 6.3.1 Chat Message Flow (End-to-end)

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Sender  │    │  NestJS  │    │PostgreSQL│    │  Redis   │    │Recipient │
│ (Flutter)│    │WS Gateway│    │          │    │ Pub/Sub  │    │ (Flutter)│
└────┬─────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘
     │               │               │               │               │
     │ 1. send_msg   │               │               │               │
     │──────────────>│               │               │               │
     │               │ 2. INSERT     │               │               │
     │               │──────────────>│               │               │
     │               │               │ 3. OK         │               │
     │               │<──────────────│               │               │
     │               │ 4. PUBLISH    │               │               │
     │               │──────────────────────────────>│               │
     │ 5. ACK (sent) │               │               │               │
     │<──────────────│               │               │               │
     │               │               │               │ 6. SUBSCRIBE  │
     │               │               │               │──────────────>│
     │               │               │               │               │
     │               │  7. If offline: BullMQ → FCM push             │
     │               │──────────────────────────────────────────────>│
```

## 6.3.2 Auth Flow

```
Flutter App          NestJS              Odoo ERP
    │                  │                    │
    │ POST /auth/login │                    │
    │ {email, password}│                    │
    │─────────────────>│                    │
    │                  │ POST /web/session/ │
    │                  │ authenticate       │
    │                  │───────────────────>│
    │                  │ {session_id, uid}  │
    │                  │<───────────────────│
    │                  │                    │
    │                  │ Upsert user in DB  │
    │                  │ Issue JWT pair     │
    │                  │                    │
    │ {access_token,   │                    │
    │  refresh_token}  │                    │
    │<─────────────────│                    │
    │                  │                    │
    │ Store in secure  │                    │
    │ storage          │                    │
```

## 6.3.3 HR Attendance Flow

```
Flutter App          NestJS              PostgreSQL         Odoo ERP
    │                  │                    │                  │
    │ Bấm Checkin      │                    │                  │
    │ (capture GPS +   │                    │                  │
    │  timestamp)      │                    │                  │
    │                  │                    │                  │
    │ Lưu Drift local  │                    │                  │
    │ (pending_sync)   │                    │                  │
    │                  │                    │                  │
    │ POST /hr/checkin │                    │                  │
    │─────────────────>│                    │                  │
    │                  │ Validate GPS,      │                  │
    │                  │ timestamp, dup     │                  │
    │                  │ INSERT attendance  │                  │
    │                  │───────────────────>│                  │
    │                  │                    │                  │
    │ 200 OK           │                    │                  │
    │<─────────────────│                    │                  │
    │                  │                    │                  │
    │ Update Drift     │  [BullMQ cron 15m] │                  │
    │ (synced)         │  Batch sync ──────────────────────────>│
    │                  │                    │                  │
```

## 6.3.4 Call Flow (Agora)

```
Caller (Flutter)     NestJS              Agora SFU          Callee (Flutter)
    │                  │                    │                  │
    │ POST /calls/     │                    │                  │
    │ initiate         │                    │                  │
    │─────────────────>│                    │                  │
    │                  │ Generate Agora     │                  │
    │                  │ token              │                  │
    │                  │                    │                  │
    │                  │ FCM push to callee │                  │
    │                  │─────────────────────────────────────>│
    │                  │                    │                  │
    │ {agora_token,    │                    │                  │
    │  channel_name}   │                    │                  │
    │<─────────────────│                    │                  │
    │                  │                    │                  │
    │ Join channel     │                    │                  │
    │──────────────────────────────────────>│                  │
    │                  │                    │  Callee accepts  │
    │                  │                    │  Join channel    │
    │                  │                    │<─────────────────│
    │                  │                    │                  │
    │ Audio/Video ←────────────────────────────────────────── │
    │ (via Agora SFU)  │                    │                  │
```

## 6.3.5 AI Log Task Flow

```
Flutter App          NestJS              AI Provider         Odoo ERP
    │                  │                    │                  │
    │ "Làm UI chat     │                    │                  │
    │  4 tiếng"        │                    │                  │
    │─────────────────>│                    │                  │
    │                  │ POST /completions  │                  │
    │                  │ {prompt + context} │                  │
    │                  │───────────────────>│                  │
    │                  │ {task, hours, date}│                  │
    │                  │<───────────────────│                  │
    │                  │                    │                  │
    │ Preview entry    │                    │                  │
    │ {task: "UI chat",│                    │                  │
    │  hours: 4,       │                    │                  │
    │  date: today}    │                    │                  │
    │<─────────────────│                    │                  │
    │                  │                    │                  │
    │ User confirms    │                    │                  │
    │─────────────────>│                    │                  │
    │                  │ POST timesheet     │                  │
    │                  │ entry to Odoo      │                  │
    │                  │─────────────────────────────────────>│
    │                  │                    │                  │
    │ ✅ Logged!       │                    │                  │
    │<─────────────────│                    │                  │
```

## 6.3.6 Notification Flow

```
Event Source         NestJS              Redis/BullMQ        Recipient
    │                  │                    │                  │
    │ Event trigger    │                    │                  │
    │ (new msg, call,  │                    │                  │
    │  HR action)      │                    │                  │
    │─────────────────>│                    │                  │
    │                  │ Check user online? │                  │
    │                  │───────────────────>│                  │
    │                  │                    │                  │
    │                  │ [Online]           │                  │
    │                  │ WebSocket push ────────────────────>│
    │                  │                    │                  │
    │                  │ [Offline]          │                  │
    │                  │ BullMQ → FCM ──────────────────────>│
    │                  │                    │                  │
    │                  │ Save to            │                  │
    │                  │ notification_center│                  │
    │                  │ (DB)               │                  │
```

