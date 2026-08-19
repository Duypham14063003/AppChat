# FR-AUTH — Authentication & Authorization

## AUTH-FR-001 — Đăng nhập qua Odoo SSO

- **Priority:** P0 🔴 MUST
- **Actor:** Employee, Manager, Admin
- **Precondition:** User có tài khoản Odoo tại erp.19t.vn
- **Description:** When user nhập email và password, the system shall xác thực qua Odoo API và cấp JWT token pair (access + refresh).
- **Flow:**
  1. Flutter gửi `POST /auth/login` với `{email, password}`
  2. NestJS gọi Odoo `POST /web/session/authenticate`
  3. Odoo trả về `session_id` + `uid` + user info
  4. NestJS tạo/cập nhật user record trong PostgreSQL
  5. NestJS issue JWT access token (15 phút) + refresh token (30 ngày)
  6. Flutter lưu tokens vào `flutter_secure_storage`
- **Acceptance Criteria:**
  - Given user có tài khoản Odoo hợp lệ, When nhập đúng email/password, Then nhận được JWT tokens và vào màn hình chính
  - Given user nhập sai password, When submit, Then hiển thị lỗi "Email hoặc mật khẩu không đúng"
  - Given Odoo server không phản hồi, When login, Then hiển thị lỗi "Không thể kết nối hệ thống, vui lòng thử lại"

## AUTH-FR-002 — JWT Access Token Refresh

- **Priority:** P0 🔴 MUST
- **Actor:** System (automatic)
- **Precondition:** User đã đăng nhập, access token hết hạn
- **Description:** When access token hết hạn (15 phút), the system shall tự động dùng refresh token để lấy access token mới mà không yêu cầu user đăng nhập lại.
- **Acceptance Criteria:**
  - Given access token hết hạn và refresh token còn hợp lệ, When gọi API, Then tự động refresh và retry request
  - Given refresh token cũng hết hạn (30 ngày), When gọi API, Then redirect về màn hình login

## AUTH-FR-003 — Refresh Token Rotation

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** When refresh token được sử dụng, the system shall issue refresh token mới và invalidate token cũ. When token cũ bị sử dụng lại, the system shall logout tất cả sessions của user đó (detect token theft).
- **Acceptance Criteria:**
  - Given refresh token A được dùng, When refresh, Then nhận token B mới và token A bị vô hiệu
  - Given token A đã bị vô hiệu, When ai đó dùng lại token A, Then tất cả sessions bị logout

## AUTH-FR-004 — Multi-device Session Management

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Description:** The system shall cho phép user đăng nhập trên nhiều thiết bị đồng thời. Mỗi device có refresh token riêng. Logout một device không ảnh hưởng device khác.
- **Acceptance Criteria:**
  - Given user đăng nhập trên iPhone và Windows, When logout trên iPhone, Then Windows vẫn hoạt động bình thường
  - Given user đăng nhập trên 3 devices, When xem danh sách sessions, Then thấy đủ 3 devices với thông tin (device name, last active, IP)

## AUTH-FR-005 — Logout

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Description:** When user chọn Logout, the system shall xóa refresh token khỏi server, xóa tokens local, và ngắt WebSocket connection.
- **Acceptance Criteria:**
  - Given user đang online, When logout, Then WebSocket bị ngắt, tokens bị xóa, redirect về login screen

## AUTH-FR-006 — Logout All Devices

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee, Admin
- **Description:** When user chọn "Logout tất cả thiết bị", the system shall invalidate tất cả refresh tokens của user đó.
- **Acceptance Criteria:**
  - Given user có 3 sessions, When logout all, Then cả 3 devices đều bị redirect về login

## AUTH-FR-007 — Role-based Access Control (RBAC)

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** The system shall phân quyền theo 3 roles: Admin, Manager, Employee.
- **Permission Matrix:**

| Action | Admin | Manager | Employee |
|--------|-------|---------|----------|
| Quản lý users/roles | ✅ | ❌ | ❌ |
| Quản lý bots | ✅ | ❌ | ❌ |
| Quản lý system settings | ✅ | ❌ | ❌ |
| Duyệt đơn nghỉ phép | ✅ | ✅ (team) | ❌ |
| Xem attendance team | ✅ | ✅ (team) | ❌ |
| Xem attendance cá nhân | ✅ | ✅ | ✅ |
| Tạo group chat | ✅ | ✅ | ✅ |
| Chat cá nhân | ✅ | ✅ | ✅ |
| Checkin/checkout | ✅ | ✅ | ✅ |

## AUTH-FR-008 — Token Storage Security

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** The system shall lưu JWT tokens an toàn theo từng platform.
- **Platform-specific:**
  - iOS: Keychain
  - Android: Keystore
  - Windows/macOS: Encrypted file via `flutter_secure_storage`
  - Web: httpOnly cookie (không dùng localStorage)

## AUTH-FR-009 — Auto-login on App Start

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** When app khởi động và có valid refresh token, the system shall tự động refresh access token và vào màn hình chính mà không yêu cầu nhập lại credentials.

## AUTH-FR-010 — WebSocket Authentication

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** When Flutter mở WebSocket connection, the system shall gửi JWT access token trong handshake. NestJS WS Gateway shall verify token trước khi accept connection.
- **Acceptance Criteria:**
  - Given valid JWT, When connect WebSocket, Then connection established
  - Given invalid/expired JWT, When connect WebSocket, Then connection rejected với error code

## AUTH-FR-011 — Account Deactivation

- **Priority:** P1 🟠 SHOULD
- **Actor:** Admin
- **Description:** When Admin deactivate một user, the system shall invalidate tất cả sessions, ngắt WebSocket, và block login cho user đó.

## AUTH-FR-012 — Login Rate Limiting

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** The system shall giới hạn tối đa 5 lần login thất bại trong 15 phút per IP. Sau đó block 30 phút.

