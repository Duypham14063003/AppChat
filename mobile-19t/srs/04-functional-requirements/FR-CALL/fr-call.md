# FR-CALL — Voice & Video Call (Agora)

## CALL-FR-001 — Gọi thoại 1-1

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Precondition:** Cả 2 user đều có tài khoản active
- **Description:** When user bấm nút gọi thoại trong conversation, the system shall tạo Agora channel, gửi notification cho callee, và thiết lập voice call.
- **Flow:**
  1. Caller bấm call → `POST /calls/initiate {callee_id, type: "voice"}`
  2. NestJS tạo Agora token (channel = `call_{uuid}`)
  3. NestJS gửi FCM push cho callee (VoIP push cho iOS)
  4. Caller join Agora channel, hiện UI "Đang gọi..."
  5. Callee nhận notification → hiện incoming call screen
  6. Callee accept → join cùng Agora channel
  7. Media: Caller ↔ Agora SFU ↔ Callee
  8. Kết thúc → NestJS lưu call log
- **Acceptance Criteria:**
  - Given 2 users online, When A gọi B, Then B nhận incoming call notification trong 3 giây
  - Given B accept, When call connected, Then cả 2 nghe được tiếng nhau
  - Given B reject, When A thấy "Cuộc gọi bị từ chối"

## CALL-FR-002 — Gọi video 1-1

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** When user bấm nút gọi video, the system shall thiết lập video call với camera preview. User có thể toggle camera on/off trong cuộc gọi.
- **Acceptance Criteria:**
  - Given video call connected, When cả 2 bật camera, Then thấy video của nhau
  - Given đang video call, When user tắt camera, Then đối phương thấy avatar thay vì video

## CALL-FR-003 — Incoming Call Screen (Cross-platform)

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** The system shall hiển thị incoming call screen phù hợp từng platform.
- **Platform-specific:**

| Platform | Behavior |
|----------|----------|
| iOS (foreground) | In-app overlay call screen |
| iOS (background/killed) | VoIP Push + CallKit native call screen |
| Android (foreground) | In-app overlay call screen |
| Android (background) | Foreground Service + heads-up notification |
| Windows/macOS (foreground) | In-app overlay |
| Windows/macOS (minimized) | System toast notification |
| Web | Browser notification (chỉ khi tab active) |

## CALL-FR-004 — Call Controls

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** During call, the system shall cung cấp các controls:
  - Mute/Unmute microphone
  - Toggle speaker/earpiece (mobile)
  - Toggle camera on/off (video call)
  - Switch front/back camera (mobile)
  - End call
- **Acceptance Criteria:**
  - Given đang trong call, When mute mic, Then đối phương không nghe tiếng
  - Given đang video call, When switch camera, Then đối phương thấy camera mới

## CALL-FR-005 — Group Call

- **Priority:** P2 🟡 COULD
- **Actor:** Employee
- **Description:** When user bấm gọi nhóm trong group chat, the system shall tạo Agora channel cho tối đa 8 participants.
- **Acceptance Criteria:**
  - Given group chat 5 người, When A bấm group call, Then 4 người còn lại nhận notification
  - Given 4 người đã join, When người thứ 5 join, Then thấy grid layout 5 video/avatar

## CALL-FR-006 — Call Log

- **Priority:** P1 🟠 SHOULD
- **Actor:** System
- **Description:** The system shall lưu log mỗi cuộc gọi và hiển thị trong conversation.
- **Data lưu:** caller_id, callee_id(s), type (voice/video), started_at, ended_at, duration, status (completed/missed/rejected/no_answer)
- **Acceptance Criteria:**
  - Given cuộc gọi kết thúc, When xem conversation, Then thấy message "Cuộc gọi thoại - 5:32"
  - Given cuộc gọi nhỡ, When callee mở app, Then thấy "Cuộc gọi nhỡ" trong conversation

## CALL-FR-007 — Call Timeout

- **Priority:** P1 🟠 SHOULD
- **Actor:** System
- **Description:** When callee không trả lời trong 60 giây, the system shall tự động kết thúc cuộc gọi và ghi nhận "Không trả lời".

## CALL-FR-008 — Call While in Call

- **Priority:** P2 🟡 COULD
- **Actor:** Employee
- **Description:** When user đang trong cuộc gọi và nhận cuộc gọi mới, the system shall hiển thị notification "Đang có cuộc gọi khác" cho caller mới.

## CALL-FR-009 — Network Quality Indicator

- **Priority:** P2 🟡 COULD
- **Actor:** System
- **Description:** During call, the system shall hiển thị chất lượng mạng (tốt/trung bình/yếu) dựa trên Agora network quality callback.

## CALL-FR-010 — Permission Request

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** Before first call, the system shall request quyền microphone (voice) và camera (video). When user từ chối, the system shall hiển thị hướng dẫn bật quyền trong Settings.

## CALL-FR-011 — Call Ringtone

- **Priority:** P1 🟠 SHOULD
- **Actor:** System
- **Description:** The system shall phát ringtone khi có incoming call và ringback tone khi đang chờ callee trả lời. Ringtone tuân theo brand Nineteen Tech.

## CALL-FR-012 — Agora Token Refresh

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** Agora token có TTL. When token sắp hết hạn trong cuộc gọi, the system shall tự động request token mới từ backend và renew mà không ngắt cuộc gọi.

