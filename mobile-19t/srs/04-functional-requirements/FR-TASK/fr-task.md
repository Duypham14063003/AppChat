# FR-TASK — Projects & Tasks

### TASK-FR-001 — Pull Projects từ Odoo

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** The system shall pull danh sách projects từ Odoo API định kỳ (BullMQ cron mỗi 15 phút). Cache trong Redis 5-15 phút. Odoo là source of truth.
- **Acceptance Criteria:**
  - Given Odoo có 10 projects, When sync, Then app hiển thị đủ 10 projects
  - Given Odoo thêm project mới, When sync tiếp theo, Then project mới xuất hiện trong app

### TASK-FR-002 — Pull Tasks từ Odoo

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** The system shall pull tasks theo project từ Odoo. Hiển thị: task name, assignee, status, deadline, priority, description.

### TASK-FR-003 — Hiển thị Kanban Board

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** The system shall hiển thị tasks dạng Kanban board với các cột: Backlog → In Progress → Review → Done. Drag-and-drop để đổi status (sync ngược Odoo).

### TASK-FR-004 — Hiển thị List View

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Description:** The system shall hiển thị tasks dạng list với sort/filter theo: status, priority, deadline, assignee.

### TASK-FR-005 — Task Detail View

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Description:** When user tap vào task, the system shall hiển thị chi tiết: description, subtasks, comments, attachments, timesheet entries, activity log.

### TASK-FR-006 — AI Log Task (Natural Language)

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** When user gõ/nói tự nhiên (VD: "Hôm nay làm xong API login, mất 3 tiếng"), the system shall dùng AI parse thành timesheet entry → confirm với user → push lên Odoo.
- **Flow:**
  1. User nhập text tự nhiên hoặc voice-to-text
  2. Gửi tới AI Gateway → parse ra: task_name, hours, date, project
  3. Hiển thị preview cho user confirm/edit
  4. User confirm → POST timesheet entry lên Odoo
- **Acceptance Criteria:**
  - Given user nói "Làm UI chat 4 tiếng", When AI parse, Then tạo entry: task="UI chat", hours=4, date=today
  - Given AI parse sai, When user edit, Then cho phép sửa trước khi submit

### TASK-FR-007 — Timesheet Entry Manual

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Description:** When user tạo timesheet entry thủ công, the system shall cho phép chọn: project, task, hours, date, description. Sync lên Odoo.

### TASK-FR-008 — Task Notifications

- **Priority:** P1 🟠 SHOULD
- **Actor:** System
- **Description:** The system shall gửi notification khi: task được assign, deadline sắp tới (1 ngày trước), task status thay đổi.

### TASK-FR-009 — Task Search & Filter

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** The system shall cho phép search task theo tên và filter theo: project, status, assignee, deadline range.

### TASK-FR-010 — My Tasks Dashboard

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Description:** The system shall hiển thị dashboard "Tasks của tôi" với: tasks đang làm, overdue tasks, upcoming deadlines, tổng giờ log tuần này.

### TASK-FR-011 — Task Timeline (Gantt nhẹ)

- **Priority:** P2 🟡 COULD
- **Actor:** Manager
- **Description:** The system shall hiển thị timeline view cho project với các task bars theo thời gian. Read-only, data từ Odoo.

### TASK-FR-012 — AI Task Suggestion

- **Priority:** P2 🟡 COULD
- **Actor:** System
- **Description:** The system shall dùng AI suggest task dựa trên lịch sử: "Bạn thường làm code review vào thứ 5, muốn log không?"

