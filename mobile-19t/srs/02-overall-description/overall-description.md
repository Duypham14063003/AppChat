# 2. Overall Description

## 2.1 Product Perspective

Nineteen Tech Internal App là hệ thống **độc lập** nhưng tích hợp sâu với Odoo ERP hiện có. App không thay thế Odoo mà bổ sung các chức năng Odoo không có (chat, call) và cung cấp UX tốt hơn cho các chức năng HR/Task trên mobile.

### 2.1.1 System Context

```
┌──────────────────────────────────────────────────────┐
│                  External Systems                     │
│  ┌─────────┐  ┌─────────┐  ┌───────┐  ┌──────────┐ │
│  │  Odoo   │  │  Agora  │  │Bunny  │  │ Firebase │ │
│  │  ERP    │  │  .io    │  │ .net  │  │   FCM    │ │
│  └────┬────┘  └────┬────┘  └───┬───┘  └────┬─────┘ │
└───────┼────────────┼───────────┼────────────┼────────┘
        │            │           │            │
┌───────▼────────────▼───────────▼────────────▼────────┐
│              NestJS Backend (API Gateway)              │
│         PostgreSQL  ·  Redis  ·  BullMQ               │
└───────────────────────┬──────────────────────────────┘
                        │ REST + WebSocket
┌───────────────────────▼──────────────────────────────┐
│           Flutter App (Cross-platform)                │
│     iOS · Android · Windows · macOS · Web             │
└──────────────────────────────────────────────────────┘
```

### 2.1.2 Quan hệ với Odoo

| Dữ liệu | Source of Truth | Hướng sync |
|----------|----------------|------------|
| User accounts | Odoo | Odoo → App (auth) |
| Employee profiles | Odoo | Odoo → App (read) |
| Attendance (checkin/out) | App | App → Odoo (write) |
| Leave requests | App | App → Odoo (write) |
| Projects & Tasks | Odoo | Odoo → App (read) |
| Timesheets | App (AI log) | App → Odoo (write) |
| Chat messages | App | App only (không sync Odoo) |
| Call logs | App | App only |

## 2.2 Product Functions (High-level)

1. **AUTH** — Xác thực qua Odoo SSO, quản lý session multi-device
2. **CHAT** — Nhắn tin real-time cá nhân/nhóm, file, voice, emoji, bot, ghim, folder
3. **CALL** — Gọi thoại/video 1-1 và nhóm, cross-platform
4. **HR** — Chấm công GPS, xin nghỉ phép, tăng ca, kỳ lương
5. **TASK** — Xem task/project từ Odoo, AI log timesheet
6. **PROFILE** — Thống kê cá nhân tổng hợp
7. **AI** — Gateway AI linh hoạt, tóm tắt chat, smart reply, log task
8. **NOTIFICATION** — Push (FCM) + in-app + notification center
9. **REMINDER** — Nhắc hẹn deadline, task, sự kiện

## 2.3 User Classes and Characteristics

| User Class | Số lượng | Đặc điểm | Quyền |
|------------|----------|-----------|-------|
| Admin | 1-3 | Quản trị hệ thống, IT | Full access, quản lý user/bot/settings |
| Manager | 3-8 | Trưởng phòng/nhóm | Duyệt đơn, xem data team, quản lý group |
| Employee | 30-40 | Nhân viên | Chat, HR cá nhân, xem task, profile |
| Bot | N/A | Automated accounts | Post vào channels được chỉ định |

**Quy mô:** < 50 người, tất cả là nhân viên nội bộ 19T.

## 2.4 Operating Environment

| Platform | Phiên bản tối thiểu |
|----------|---------------------|
| iOS | 15.0+ |
| Android | API 24 (Android 7.0)+ |
| Windows | Windows 10 (64-bit)+ |
| macOS | 12.0 (Monterey)+ |
| Web | Chrome 90+, Firefox 90+, Safari 15+, Edge 90+ |

## 2.5 Design and Implementation Constraints

| Ràng buộc | Chi tiết |
|-----------|---------|
| Ngôn ngữ FE | Dart / Flutter |
| Ngôn ngữ BE | TypeScript / NestJS |
| Database | PostgreSQL 16 |
| Auth | Phải tích hợp Odoo SSO, không tạo hệ thống user riêng |
| Storage | Bunny.net (đã có account) |
| Call | Agora.io SDK |
| Push | Firebase Cloud Messaging |
| Quy mô | Thiết kế cho < 50 users, nhưng kiến trúc phải scale được tới 200+ |
| Ngôn ngữ UI | Tiếng Việt (primary), English (secondary) |
| Brand | Tuân thủ brand identity Nineteen Tech (gold #C9A84C, dark theme) |

## 2.6 Assumptions and Dependencies

**Assumptions:**
- Nhân viên đều có smartphone hoặc máy tính cá nhân
- Văn phòng có WiFi ổn định
- Odoo ERP (erp.19t.vn) hoạt động ổn định, API available
- Team dev có kinh nghiệm Flutter và NestJS

**Dependencies:**
- Odoo API availability — nếu Odoo down, auth mới và HR sync bị ảnh hưởng
- Agora.io service — call feature phụ thuộc hoàn toàn
- Bunny.net — file storage phụ thuộc hoàn toàn
- Firebase — push notification phụ thuộc hoàn toàn
- Internet connection — chat real-time cần mạng (có offline queue cho text)

