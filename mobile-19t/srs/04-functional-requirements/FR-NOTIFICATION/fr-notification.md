# FR-NOTIFICATION — Push Notification & In-app

### NOTIF-FR-001 — FCM Push Notification (Offline)

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** When user offline và có event quan trọng (tin nhắn mới, cuộc gọi, đơn được duyệt), the system shall gửi FCM push notification.
- **Platform behavior:**
  - iOS: APNs via FCM, badge count update
  - Android: FCM notification channel
  - Web: Web Push API via FCM
  - Desktop: Không dùng FCM, dùng WebSocket + system notification

### NOTIF-FR-002 — In-app Notification (Online)

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** When user online, the system shall deliver notification qua WebSocket. Hiển thị toast/banner trong app. Không gửi FCM push khi user đang active.

### NOTIF-FR-003 — Notification Center

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** The system shall cung cấp Notification Center lưu lịch sử tất cả notifications. Phân loại: Chat, HR, Task, System. Mark as read/unread.

### NOTIF-FR-004 — Notification Preferences

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** User shall config notification preferences:
  - Bật/tắt theo loại: chat, call, HR, task, reminder
  - Quiet hours: không gửi push từ 22:00 - 7:00 (config)
  - Mute specific conversations

### NOTIF-FR-005 — Notification Events

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** Danh sách events trigger notification:

| Event | Notification | Channel |
|-------|-------------|---------|
| Tin nhắn mới (DM) | "{sender}: {preview}" | Push + In-app |
| Tin nhắn mới (Group) | "{group} - {sender}: {preview}" | Push + In-app |
| Mention (@user) | "{sender} đã nhắc bạn trong {group}" | Push + In-app |
| Incoming call | Full-screen call UI | VoIP Push (iOS) / FCM (Android) |
| Missed call | "Cuộc gọi nhỡ từ {caller}" | Push + In-app |
| Đơn nghỉ mới (Manager) | "{employee} xin nghỉ {dates}" | Push + In-app |
| Đơn được duyệt/từ chối | "Đơn nghỉ đã được {action}" | Push + In-app |
| Task assigned | "Bạn được assign task {name}" | Push + In-app |
| Task deadline sắp tới | "Task {name} deadline trong 1 ngày" | Push + In-app |
| Reminder | "{reminder_title}" | Push + In-app |
| System update | "Phiên bản mới {version} available" | In-app only |

### NOTIF-FR-006 — FCM Token Management

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** The system shall lưu FCM token per device. When token refresh, the system shall update. When user logout, the system shall xóa token.

### NOTIF-FR-007 — Notification Grouping

- **Priority:** P2 🟡 COULD
- **Actor:** System
- **Description:** When có nhiều notifications từ cùng conversation, the system shall group thành 1 notification: "{sender} gửi 5 tin nhắn mới".

### NOTIF-FR-008 — Desktop System Notification

- **Priority:** P1 🟠 SHOULD
- **Actor:** System
- **Description:** On Windows/macOS, the system shall hiển thị system notification (toast) khi app minimized. Click notification → focus app + navigate tới conversation.

### NOTIF-FR-009 — Badge Count Sync

- **Priority:** P1 🟠 SHOULD
- **Actor:** System
- **Description:** The system shall sync unread count lên app icon badge (iOS/Android) và taskbar badge (macOS). Reset khi user đọc.

### NOTIF-FR-010 — Notification Sound

- **Priority:** P1 🟠 SHOULD
- **Actor:** System
- **Description:** The system shall phát sound khi nhận notification (configurable). Sound khác nhau cho: message, call, HR. Tuân theo brand Nineteen Tech.

