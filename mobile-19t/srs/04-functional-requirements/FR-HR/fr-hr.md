# FR-HR — Human Resources

## Phần 1: Chấm công (Attendance)

### HR-FR-001 — Checkin

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Precondition:** User đã đăng nhập, GPS enabled
- **Description:** When user bấm Checkin, the system shall ghi nhận timestamp + GPS coordinates + device_id. Lưu local trước (Drift), sau đó sync lên server.
- **Flow:**
  1. User bấm "Checkin" trên app
  2. Flutter capture: `{timestamp (UTC), gps_lat, gps_lng, device_id}`
  3. Lưu vào Drift local DB (status=pending_sync)
  4. POST `/hr/attendance/checkin` → NestJS validate
  5. NestJS: validate GPS hợp lệ, timestamp không quá 24h cũ, chưa checkin hôm nay
  6. INSERT PostgreSQL attendance table
  7. BullMQ job: batch sync lên Odoo (mỗi 15 phút)
- **Acceptance Criteria:**
  - Given user ở văn phòng, When bấm Checkin, Then ghi nhận thành công với thời gian chính xác
  - Given user đã checkin hôm nay, When bấm Checkin lần 2, Then hiển thị lỗi "Bạn đã checkin hôm nay"
  - Given user offline, When bấm Checkin, Then lưu local và sync khi có mạng (dùng original_timestamp)

### HR-FR-002 — Checkout

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Precondition:** User đã checkin hôm nay
- **Description:** When user bấm Checkout, the system shall ghi nhận thời gian checkout và tính tổng giờ làm việc.
- **Acceptance Criteria:**
  - Given user đã checkin lúc 8:00, When checkout lúc 17:30, Then tổng giờ = 9.5h
  - Given user chưa checkin, When bấm Checkout, Then hiển thị lỗi "Bạn chưa checkin hôm nay"

### HR-FR-003 — Geofencing (Optional)

- **Priority:** P2 🟡 COULD
- **Actor:** System
- **Description:** When user vào vùng geofence văn phòng (bán kính config), the system shall gợi ý checkin. Admin config tọa độ + bán kính.

### HR-FR-004 — Tính giờ tăng ca (OT)

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** The system shall tự động tính OT dựa trên công thức:
  ```
  OT_hours = max(0, total_worked - standard_hours_per_day)
  OT_pay = hourly_rate × OT_hours × 1.5
  ```
  `standard_hours` config theo phòng ban (mặc định 8h).
- **Acceptance Criteria:**
  - Given standard = 8h, When user làm 10h, Then OT = 2h × 1.5 = 3h quy đổi

### HR-FR-005 — Lịch sử chấm công

- **Priority:** P0 🔴 MUST
- **Actor:** Employee, Manager
- **Description:** The system shall hiển thị lịch sử chấm công dạng calendar + list. Employee xem của mình, Manager xem team.
- **Data hiển thị:** Ngày, checkin time, checkout time, tổng giờ, OT, status (đúng giờ/trễ/OT/vắng)

## Phần 2: Nghỉ phép (Leave)

### HR-FR-006 — Tạo đơn xin nghỉ

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Description:** When user tạo đơn nghỉ, the system shall yêu cầu: loại nghỉ (phép năm/ốm/việc riêng), ngày bắt đầu, ngày kết thúc, lý do.
- **Flow:** Draft → Submit → Push notification cho Manager

### HR-FR-007 — Duyệt/Từ chối đơn nghỉ

- **Priority:** P0 🔴 MUST
- **Actor:** Manager
- **Description:** When Manager nhận đơn, the system shall cho phép Approve hoặc Reject kèm ghi chú. Kết quả push notification cho Employee.
- **Acceptance Criteria:**
  - Given Manager approve, When duyệt, Then Employee nhận notification + balance phép giảm + sync Odoo
  - Given Manager reject, When từ chối, Then Employee nhận notification kèm lý do

### HR-FR-008 — Balance phép năm

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** The system shall hiển thị số ngày phép còn lại real-time. Tự động trừ khi đơn được duyệt.

### HR-FR-009 — Escalation khi Manager vắng

- **Priority:** P2 🟡 COULD
- **Actor:** System
- **Description:** When đơn chưa được duyệt sau 24h, the system shall escalate lên Admin hoặc Manager cấp trên.

## Phần 3: Kỳ lương & Config

### HR-FR-010 — Config kỳ lương

- **Priority:** P0 🔴 MUST
- **Actor:** Admin
- **Description:** Admin shall config: ngày bắt đầu kỳ lương (VD: ngày 1 hoặc ngày 20), số ngày công tiêu chuẩn/tháng.

### HR-FR-011 — Bảng tổng hợp công

- **Priority:** P1 🟠 SHOULD
- **Actor:** Manager, Admin
- **Description:** The system shall tạo bảng tổng hợp công theo kỳ lương: tổng ngày công, OT, nghỉ phép, vắng. Export được.

### HR-FR-012 — Ngày lễ Việt Nam

- **Priority:** P1 🟠 SHOULD
- **Actor:** Admin
- **Description:** The system shall có table ngày lễ (quốc gia + công ty). Admin có thể thêm custom holidays. Ngày lễ ảnh hưởng tính công chuẩn và OT rate.

### HR-FR-013 — Sync Odoo (Batch)

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** The system shall batch sync attendance data lên Odoo mỗi 15 phút qua BullMQ job. App là source of truth cho attendance, Odoo là destination.
- **Acceptance Criteria:**
  - Given Odoo available, When sync job chạy, Then data attendance được push lên Odoo
  - Given Odoo down, When sync job chạy, Then retry với exponential backoff, không mất data

### HR-FR-014 — Anti-cheat Validation

- **Priority:** P1 🟠 SHOULD
- **Actor:** System
- **Description:** Server shall validate: GPS coordinates hợp lệ (trong phạm vi cho phép), timestamp không quá 24h cũ, không checkin 2 lần cùng ngày, device_id khớp với user.

