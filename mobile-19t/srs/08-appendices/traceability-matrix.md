# 8.3 Traceability Matrix

## FR → Phase → Priority → Test Coverage

### AUTH Module

| Req ID | Tên | Priority | Phase | Test Type | Status |
|--------|-----|----------|-------|-----------|--------|
| AUTH-FR-001 | Đăng nhập Odoo SSO | P0 | 1 | Integration | Draft |
| AUTH-FR-002 | JWT Access Token Refresh | P0 | 1 | Unit + Integration | Draft |
| AUTH-FR-003 | Refresh Token Rotation | P0 | 1 | Unit + Integration | Draft |
| AUTH-FR-004 | Multi-device Session | P0 | 1 | Integration | Draft |
| AUTH-FR-005 | Logout | P0 | 1 | Integration | Draft |
| AUTH-FR-006 | Logout All Devices | P1 | 2 | Integration | Draft |
| AUTH-FR-007 | RBAC | P0 | 1 | Unit + Integration | Draft |
| AUTH-FR-008 | Token Storage Security | P0 | 1 | Manual | Draft |
| AUTH-FR-009 | Auto-login | P0 | 1 | Widget | Draft |
| AUTH-FR-010 | WebSocket Auth | P0 | 1 | Integration | Draft |
| AUTH-FR-011 | Account Deactivation | P1 | 2 | Integration | Draft |
| AUTH-FR-012 | Login Rate Limiting | P0 | 1 | Integration | Draft |

### CHAT Module

| Req ID | Tên | Priority | Phase | Test Type | Status |
|--------|-----|----------|-------|-----------|--------|
| CHAT-FR-001 | Gửi tin nhắn text (DM) | P0 | 1 | Unit + Integration + WS | Draft |
| CHAT-FR-002 | Gửi tin nhắn Group | P0 | 1 | Integration + WS | Draft |
| CHAT-FR-003 | Tạo Conversation (Direct) | P0 | 1 | Integration | Draft |
| CHAT-FR-004 | Tạo Group Chat | P1 | 2 | Integration | Draft |
| CHAT-FR-005 | Quản lý Group | P1 | 2 | Integration | Draft |
| CHAT-FR-006 | Gửi ảnh | P0 | 1 | Integration | Draft |
| CHAT-FR-007 | Gửi file | P1 | 2 | Integration | Draft |
| CHAT-FR-008 | Gửi voice message | P1 | 2 | Integration | Draft |
| CHAT-FR-010 | Reply tin nhắn | P1 | 2 | Unit + WS | Draft |
| CHAT-FR-012 | Reaction | P1 | 2 | Unit + WS | Draft |
| CHAT-FR-013 | Ghim tin nhắn | P1 | 2 | Integration | Draft |
| CHAT-FR-018 | Tìm kiếm Local | P0 | 1 | Unit | Draft |
| CHAT-FR-021 | Message Status | P0 | 1 | WS | Draft |
| CHAT-FR-024 | Unread Count | P0 | 1 | Unit | Draft |
| CHAT-FR-029 | Offline Queue | P0 | 1 | Unit + Integration | Draft |
| CHAT-FR-030 | Reconnect Sync | P0 | 1 | WS | Draft |
| CHAT-FR-031 | Infinite Scroll | P0 | 1 | Integration | Draft |
| CHAT-FR-035 | Rate Limiting | P0 | 1 | Integration | Draft |

### HR Module

| Req ID | Tên | Priority | Phase | Test Type | Status |
|--------|-----|----------|-------|-----------|--------|
| HR-FR-001 | Checkin | P0 | 3 | Unit + Integration | Draft |
| HR-FR-002 | Checkout | P0 | 3 | Unit + Integration | Draft |
| HR-FR-004 | Tính OT | P0 | 3 | Unit (100% coverage) | Draft |
| HR-FR-005 | Lịch sử chấm công | P0 | 3 | Integration | Draft |
| HR-FR-006 | Tạo đơn nghỉ | P0 | 3 | Integration | Draft |
| HR-FR-007 | Duyệt/Từ chối đơn | P0 | 3 | Integration | Draft |
| HR-FR-010 | Config kỳ lương | P0 | 3 | Unit | Draft |
| HR-FR-013 | Sync Odoo | P0 | 3 | Integration | Draft |

### CALL Module

| Req ID | Tên | Priority | Phase | Test Type | Status |
|--------|-----|----------|-------|-----------|--------|
| CALL-FR-001 | Gọi thoại 1-1 | P1 | 2 | Manual + Integration | Draft |
| CALL-FR-002 | Gọi video 1-1 | P1 | 2 | Manual | Draft |
| CALL-FR-003 | Incoming Call Screen | P0 | 2 | Manual (per platform) | Draft |
| CALL-FR-010 | Permission Request | P0 | 2 | Manual | Draft |
| CALL-FR-012 | Agora Token Refresh | P0 | 2 | Integration | Draft |

### NFR Traceability

| Req ID | Tên | Test Method |
|--------|-----|-------------|
| NFR-PERF-001 | API Response Time | Load test (k6/Artillery) |
| NFR-PERF-002 | DB Performance | EXPLAIN ANALYZE + benchmark |
| NFR-PERF-003 | Concurrent Users | Load test (50 WS connections) |
| NFR-PERF-004 | Flutter Performance | DevTools profiling |
| NFR-SEC-001 | Transport Security | SSL Labs test |
| NFR-SEC-002 | Auth Security | Penetration test |
| NFR-SEC-004 | API Security | OWASP checklist |
| NFR-REL-001 | Uptime | Monitoring (UptimeRobot) |
| NFR-REL-002 | Data Durability | Backup restore test |

## Test Priority Order

1. HR calculation unit tests (100% coverage) — sai = ảnh hưởng lương
2. Auth integration tests — sai = không vào được app
3. Chat WebSocket tests — sai = core feature broken
4. API integration tests (Supertest)
5. Flutter widget tests
6. Load tests (trước release)

