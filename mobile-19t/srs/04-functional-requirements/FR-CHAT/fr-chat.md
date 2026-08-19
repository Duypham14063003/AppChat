# FR-CHAT — Messaging (Telegram-like)

## Phần 1: Core Messaging

### CHAT-FR-001 — Gửi tin nhắn text (Direct Message)

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Precondition:** User đã đăng nhập, có WebSocket connection
- **Description:** When user gõ tin nhắn và bấm gửi, the system shall gửi qua WebSocket, lưu vào PostgreSQL, và deliver cho recipient real-time.
- **Flow:**
  1. User gõ text → bấm Send
  2. Flutter: tạo UUID cho message, hiển thị bubble ngay (Optimistic UI, status=pending)
  3. Flutter: emit WS event `send_message {id, conv_id, content, type: "text"}`
  4. NestJS: validate → INSERT PostgreSQL → Redis Pub/Sub publish
  5. NestJS: ACK back to sender → status=sent
  6. Recipient online: WS push → hiển thị bubble
  7. Recipient offline: BullMQ → FCM push notification
- **Acceptance Criteria:**
  - Given 2 users online, When A gửi tin, Then B nhận trong < 500ms
  - Given B offline, When A gửi tin, Then B nhận FCM push notification
  - Given mất mạng, When A gửi tin, Then bubble hiện status "Đang gửi..." và retry khi có mạng

### CHAT-FR-002 — Gửi tin nhắn trong Group Chat

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Description:** When user gửi tin trong group, the system shall fan-out tới tất cả members qua Redis Pub/Sub.
- **Acceptance Criteria:**
  - Given group 10 người, When A gửi tin, Then 9 người còn lại nhận trong < 1 giây

### CHAT-FR-003 — Tạo Conversation (Direct)

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Description:** When user chọn một contact để chat, the system shall tạo conversation type DIRECT nếu chưa tồn tại, hoặc mở conversation hiện có.

### CHAT-FR-004 — Tạo Group Chat

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** When user tạo group mới, the system shall cho phép đặt tên, chọn avatar, và thêm members (tối thiểu 2, tối đa 200).
- **Acceptance Criteria:**
  - Given user tạo group "Dev Team" với 5 members, When tạo xong, Then tất cả 5 members thấy group trong danh sách

### CHAT-FR-005 — Quản lý Group (Admin)

- **Priority:** P1 🟠 SHOULD
- **Actor:** Group creator / Admin
- **Description:** Group admin shall có quyền: đổi tên, đổi avatar, thêm/xóa member, set admin khác, xóa group.

## Phần 2: Message Types

### CHAT-FR-006 — Gửi ảnh

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Description:** When user chọn ảnh từ gallery/camera, the system shall upload lên Bunny.net và gửi message type "image" kèm URL + thumbnail.
- **Acceptance Criteria:**
  - Given user chọn ảnh 5MB, When gửi, Then hiện progress bar upload, sau đó hiện ảnh trong chat
  - Given recipient nhận ảnh, When tap, Then mở full-screen với pinch-to-zoom

### CHAT-FR-007 — Gửi file đính kèm

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** When user chọn file (PDF, DOC, ZIP...), the system shall upload Bunny.net và gửi message type "file" kèm URL, filename, size. Max file size: 50MB.

### CHAT-FR-008 — Gửi voice message

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** When user giữ nút mic, the system shall record audio. Khi thả, upload Bunny.net và gửi message type "voice" kèm URL + duration + waveform data.
- **Acceptance Criteria:**
  - Given user giữ mic 10 giây, When thả, Then gửi voice message với waveform hiển thị
  - Given recipient nhận voice, When tap play, Then phát audio với progress indicator

### CHAT-FR-009 — Gửi video

- **Priority:** P2 🟡 COULD
- **Actor:** Employee
- **Description:** When user chọn video, the system shall upload Bunny.net, tạo thumbnail, và gửi message type "video". Max duration: 5 phút, max size: 100MB.

## Phần 3: Message Interactions

### CHAT-FR-010 — Reply tin nhắn

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** When user swipe phải trên bubble hoặc long-press → Reply, the system shall tạo message với `reply_to_id` và hiển thị snippet tin nhắn gốc.
- **Acceptance Criteria:**
  - Given user reply tin nhắn, When gửi, Then bubble hiện snippet tin gốc phía trên
  - Given user tap vào snippet, When tap, Then scroll tới tin nhắn gốc và highlight 2 giây

### CHAT-FR-011 — Forward tin nhắn

- **Priority:** P2 🟡 COULD
- **Actor:** Employee
- **Description:** When user chọn Forward, the system shall cho phép chọn conversation đích và gửi message với `forwarded_from` info.

### CHAT-FR-012 — Reaction (Emoji)

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** When user long-press bubble → chọn emoji, the system shall lưu reaction và hiển thị dưới bubble. Mỗi user chỉ 1 reaction per message (thay đổi được).

### CHAT-FR-013 — Ghim tin nhắn

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee (group admin cho group)
- **Description:** When user ghim tin nhắn, the system shall hiển thị pinned bar ở đầu conversation. Tối đa 5 tin ghim per conversation.

### CHAT-FR-014 — Xóa tin nhắn

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee (chỉ tin của mình)
- **Description:** When user xóa tin nhắn, the system shall soft-delete (set deleted_at). Hiển thị "Tin nhắn đã bị xóa" cho recipients. Xóa trong vòng 24h kể từ khi gửi.

### CHAT-FR-015 — Chỉnh sửa tin nhắn

- **Priority:** P2 🟡 COULD
- **Actor:** Employee (chỉ tin của mình)
- **Description:** When user edit tin nhắn, the system shall cập nhật content và hiển thị label "đã chỉnh sửa". Chỉ edit trong vòng 24h.



## Phần 4: Organization & Search

### CHAT-FR-016 — Tin nhắn đã lưu (Saved Messages)

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** The system shall cung cấp conversation đặc biệt type SAVED cho mỗi user. When user chọn "Lưu tin nhắn", the system shall copy message vào Saved Messages.

### CHAT-FR-017 — Phân loại thư mục (Folders)

- **Priority:** P2 🟡 COULD
- **Actor:** Employee
- **Description:** When user tạo folder, the system shall cho phép kéo conversations vào folder để phân loại. Mỗi user có folder riêng, không ảnh hưởng user khác.

### CHAT-FR-018 — Tìm kiếm tin nhắn (Local)

- **Priority:** P0 🔴 MUST
- **Actor:** Employee
- **Description:** When user gõ từ khóa trong search bar, the system shall tìm kiếm trong Drift local cache (7 ngày gần nhất) và trả kết quả tức thì (< 300ms).

### CHAT-FR-019 — Tìm kiếm tin nhắn (Server - Full History)

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** When user chọn "Tìm tất cả", the system shall gọi API search PostgreSQL FTS (tsvector + GIN + unaccent) trên toàn bộ lịch sử. Trả kết quả < 100ms với snippet highlight.

### CHAT-FR-020 — Tìm kiếm trong conversation

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** When user bấm search icon trong conversation, the system shall tìm kiếm chỉ trong conversation đó. Hỗ trợ navigate qua từng kết quả (lên/xuống).

## Phần 5: Status & Presence

### CHAT-FR-021 — Message Status (Sent/Delivered/Read)

- **Priority:** P0 🔴 MUST
- **Actor:** System
- **Description:** The system shall track trạng thái: ⏳ Pending → ✓ Sent → ✓✓ Delivered → ✓✓ (xanh) Read.

### CHAT-FR-022 — Typing Indicator

- **Priority:** P1 🟠 SHOULD
- **Description:** When user đang gõ, the system shall gửi WS event "typing". Hiển thị "Đang nhập..." cho recipients. Không lưu DB.

### CHAT-FR-023 — Online/Offline Status

- **Priority:** P1 🟠 SHOULD
- **Description:** The system shall hiển thị online (green dot) / offline (grey) / last seen timestamp.

### CHAT-FR-024 — Unread Count Badge

- **Priority:** P0 🔴 MUST
- **Description:** The system shall hiển thị số tin chưa đọc trên mỗi conversation và tổng unread trên app icon.

## Phần 6: Advanced Features

### CHAT-FR-025 — Bot Framework

- **Priority:** P2 🟡 COULD
- **Description:** Admin tạo bot với webhook URL, trigger bởi `/command` hoặc keyword. Bot chỉ post vào channels được chỉ định.

### CHAT-FR-026 — Emoji Picker

- **Priority:** P1 🟠 SHOULD
- **Description:** Emoji picker panel với categories, recently used, search. Unicode emoji chuẩn.

### CHAT-FR-027 — Link Preview

- **Priority:** P2 🟡 COULD
- **Description:** When tin nhắn chứa URL, the system shall fetch Open Graph metadata và hiển thị preview card.

### CHAT-FR-028 — Conversation Mute

- **Priority:** P1 🟠 SHOULD
- **Description:** When mute, không gửi push notification cho conversation đó. Vẫn hiện unread badge.

### CHAT-FR-029 — Offline Message Queue

- **Priority:** P0 🔴 MUST
- **Description:** When offline, queue message trong Drift (status=pending). When có mạng, gửi tất cả pending messages theo thứ tự. Sau 5 lần retry thất bại → hiện "Gửi thất bại" + nút Retry.

### CHAT-FR-030 — Reconnect & Missed Messages Sync

- **Priority:** P0 🔴 MUST
- **Description:** When app foreground sau background, gửi `last_synced_at` qua WS. Server trả về tất cả messages mới hơn.

### CHAT-FR-031 — Load tin nhắn cũ (Infinite Scroll)

- **Priority:** P0 🔴 MUST
- **Description:** When scroll lên đầu, load thêm 30 tin cũ hơn bằng cursor-based pagination. Hiện shimmer loading.

### CHAT-FR-032 — Jump to Date

- **Priority:** P2 🟡 COULD
- **Description:** When chọn ngày từ calendar, scroll tới message gần nhất với context window (15 trước + 15 sau).

### CHAT-FR-033 — Media Gallery per Conversation

- **Priority:** P2 🟡 COULD
- **Description:** Hiển thị gallery ảnh/video/file đã chia sẻ trong conversation info, phân loại theo tab.

### CHAT-FR-034 — Mention (@user)

- **Priority:** P2 🟡 COULD
- **Description:** When gõ `@` trong group, hiện danh sách members. Mentioned user nhận notification đặc biệt.

### CHAT-FR-035 — Message Rate Limiting

- **Priority:** P0 🔴 MUST
- **Description:** Giới hạn 30 messages/phút/user, 10 file uploads/phút/user. Vượt quá → reject.
