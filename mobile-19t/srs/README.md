# SRS — Nineteen Tech Internal App

> Software Requirements Specification theo chuẩn IEEE 830-1998 / IEEE 29148:2018

## Thông tin dự án

| Mục | Chi tiết |
|-----|---------|
| Tên dự án | Nineteen Tech Internal App |
| Phiên bản SRS | 1.0.0 |
| Ngày tạo | 2026-03-15 |
| Tác giả | Nineteen Tech Development Team |
| Trạng thái | Draft |
| Chuẩn áp dụng | IEEE 830-1998, IEEE 29148:2018 |

## Cấu trúc thư mục

```
srs/
├── README.md                          ← Bạn đang ở đây
├── 01-introduction/
│   └── introduction.md                ← Mục đích, phạm vi, định nghĩa, tài liệu tham chiếu
├── 02-overall-description/
│   └── overall-description.md         ← Tổng quan sản phẩm, user, ràng buộc
├── 03-system-architecture/
│   └── system-architecture.md         ← Kiến trúc hệ thống, tech stack, deployment
├── 04-functional-requirements/
│   ├── _index.md                      ← Tổng quan & quy ước đánh mã FR
│   ├── FR-AUTH/
│   │   └── fr-auth.md                 ← Authentication & Authorization
│   ├── FR-CHAT/
│   │   └── fr-chat.md                 ← Messaging (Telegram-like)
│   ├── FR-CALL/
│   │   └── fr-call.md                 ← Voice & Video Call (Agora)
│   ├── FR-HR/
│   │   └── fr-hr.md                   ← HR: Chấm công, nghỉ phép, tăng ca
│   ├── FR-TASK/
│   │   └── fr-task.md                 ← Projects & Tasks (Odoo sync)
│   ├── FR-PROFILE/
│   │   └── fr-profile.md              ← User Profile & Statistics
│   ├── FR-AI/
│   │   └── fr-ai.md                   ← AI Integration
│   ├── FR-NOTIFICATION/
│   │   └── fr-notification.md         ← Push Notification & In-app
│   └── FR-REMINDER/
│       └── fr-reminder.md             ← Reminder & Scheduling
├── 05-non-functional-requirements/
│   └── non-functional-requirements.md ← Performance, Security, Usability, Reliability
├── 06-data-requirements/
│   ├── database-schema.md             ← PostgreSQL schema, partition strategy
│   ├── data-dictionary.md             ← Định nghĩa từng field
│   └── data-flow.md                   ← Luồng dữ liệu end-to-end
├── 07-external-interfaces/
│   ├── api-specification.md           ← REST API & WebSocket contracts
│   ├── odoo-integration.md            ← Odoo ERP integration
│   └── third-party-services.md        ← Agora, Bunny.net, Firebase, AI providers
└── 08-appendices/
    ├── glossary.md                    ← Thuật ngữ
    ├── use-cases.md                   ← Use case diagrams & scenarios
    ├── traceability-matrix.md         ← FR → Design → Test mapping
    └── risk-matrix.md                 ← FMEA risk analysis
```

## Quy ước

- Mã yêu cầu: `[MODULE]-[TYPE]-[NUMBER]` (VD: `AUTH-FR-001`, `CHAT-FR-015`)
- Mức ưu tiên: `P0` (Must), `P1` (Should), `P2` (Could), `P3` (Won't this release)
- Trạng thái: `Draft` → `Review` → `Approved` → `Implemented` → `Verified`
- Ngôn ngữ yêu cầu: dùng cấu trúc EARS — "When [event], the system shall [response]"

## Lịch sử thay đổi

| Version | Ngày | Người thay đổi | Mô tả |
|---------|------|----------------|-------|
| 1.0.0 | 2026-03-15 | — | Khởi tạo SRS ban đầu |

