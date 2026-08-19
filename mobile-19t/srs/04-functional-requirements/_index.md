# 4. Functional Requirements — Index

## 4.1 Quy ước đánh mã

```
[MODULE]-FR-[NUMBER]

MODULE:
  AUTH    — Authentication & Authorization
  CHAT    — Messaging
  CALL    — Voice & Video Call
  HR      — Human Resources
  TASK    — Projects & Tasks
  PROF    — Profile
  AI      — AI Integration
  NOTIF   — Notification
  REMIND  — Reminder

NUMBER: 3 chữ số, bắt đầu từ 001

Ví dụ: CHAT-FR-001, HR-FR-015
```

## 4.2 Mức ưu tiên

| Mức | Ký hiệu | Ý nghĩa | Phase |
|-----|----------|---------|-------|
| P0 | 🔴 MUST | Bắt buộc có trong MVP | Phase 1 |
| P1 | 🟠 SHOULD | Cần có trong bản đầy đủ | Phase 2 |
| P2 | 🟡 COULD | Nice-to-have | Phase 3-4 |
| P3 | ⚪ WON'T | Không làm trong release này | Backlog |

## 4.3 Template yêu cầu

Mỗi yêu cầu chức năng tuân theo format:

```
### [MÃ] — [Tên ngắn]

- **Priority:** P0/P1/P2/P3
- **Module:** [Module name]
- **Actor:** [User class]
- **Precondition:** [Điều kiện trước]
- **Description (EARS):** When [trigger], the system shall [behavior]
- **Acceptance Criteria:**
  - Given [context], When [action], Then [expected result]
- **Notes:** [Ghi chú bổ sung]
```

## 4.4 Tổng quan số lượng FR theo module

| Module | File | Số FR (ước tính) | Phase chính |
|--------|------|-------------------|-------------|
| AUTH | `FR-AUTH/fr-auth.md` | ~12 | Phase 1 |
| CHAT | `FR-CHAT/fr-chat.md` | ~35 | Phase 1-2 |
| CALL | `FR-CALL/fr-call.md` | ~15 | Phase 2 |
| HR | `FR-HR/fr-hr.md` | ~20 | Phase 3 |
| TASK | `FR-TASK/fr-task.md` | ~12 | Phase 3 |
| PROFILE | `FR-PROFILE/fr-profile.md` | ~8 | Phase 3 |
| AI | `FR-AI/fr-ai.md` | ~10 | Phase 3-4 |
| NOTIFICATION | `FR-NOTIFICATION/fr-notification.md` | ~10 | Phase 1-2 |
| REMINDER | `FR-REMINDER/fr-reminder.md` | ~8 | Phase 4 |
| **Tổng** | | **~130** | |

## 4.5 Dependency Map giữa các module

```
AUTH ──────► tất cả module (prerequisite)
CHAT ──────► NOTIFICATION (tin nhắn mới)
CHAT ──────► AI (tóm tắt, smart reply)
CALL ──────► NOTIFICATION (incoming call)
CALL ──────► CHAT (call log trong conversation)
HR ────────► NOTIFICATION (đơn mới, duyệt/từ chối)
HR ────────► REMINDER (nhắc checkin/checkout)
TASK ──────► NOTIFICATION (task deadline)
TASK ──────► AI (log task tự nhiên)
TASK ──────► REMINDER (deadline reminder)
PROFILE ───► AUTH + CHAT + HR + TASK (aggregate data)
```

