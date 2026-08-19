# FR-REMINDER — Reminder & Scheduling

### REMIND-FR-001 — Tạo Reminder

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** When user tạo reminder, the system shall cho phép nhập: title, description, datetime, repeat (none/daily/weekly/monthly), liên kết tới task/conversation (optional).
- **Acceptance Criteria:**
  - Given user tạo reminder "Họp team" lúc 14:00, When đến 14:00, Then nhận push notification

### REMIND-FR-002 — Reminder Engine (BullMQ)

- **Priority:** P1 🟠 SHOULD
- **Actor:** System
- **Description:** The system shall dùng BullMQ delayed jobs để schedule reminder. Khi tạo reminder → schedule job với delay = (reminder_time - now). Job trigger → gửi FCM + in-app notification.

### REMIND-FR-003 — Task Deadline Reminder

- **Priority:** P1 🟠 SHOULD
- **Actor:** System
- **Description:** The system shall tự động tạo reminder cho task deadlines: 1 ngày trước, 1 giờ trước (configurable). User có thể tắt per task.

### REMIND-FR-004 — Checkin/Checkout Reminder

- **Priority:** P1 🟠 SHOULD
- **Actor:** System
- **Description:** The system shall nhắc user checkin vào giờ bắt đầu làm việc và checkout vào giờ kết thúc (config per user hoặc global).

### REMIND-FR-005 — Recurring Reminder

- **Priority:** P2 🟡 COULD
- **Actor:** Employee
- **Description:** When user tạo recurring reminder, the system shall tự động tạo lại reminder theo schedule (daily/weekly/monthly) cho đến khi user tắt.

### REMIND-FR-006 — Danh sách Reminders

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** The system shall hiển thị danh sách reminders: upcoming, completed, overdue. Cho phép edit/delete/snooze.

### REMIND-FR-007 — Snooze Reminder

- **Priority:** P2 🟡 COULD
- **Actor:** Employee
- **Description:** When reminder notification hiện, user shall có option Snooze (5 phút / 15 phút / 1 giờ / custom). The system shall reschedule BullMQ job.

### REMIND-FR-008 — Leave Request Reminder

- **Priority:** P2 🟡 COULD
- **Actor:** System
- **Description:** The system shall nhắc Manager khi có đơn nghỉ chưa duyệt quá 12 giờ.

