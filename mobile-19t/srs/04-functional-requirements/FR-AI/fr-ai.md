# FR-AI — AI Integration

### AI-FR-001 — AI Gateway Configuration

- **Priority:** P1 🟠 SHOULD
- **Actor:** Admin
- **Description:** Admin shall config AI provider qua Settings:
  ```json
  {
    "provider": "openai | anthropic | custom",
    "base_url": "https://api.openai.com/v1",
    "api_key": "sk-...",
    "model": "gpt-4o | claude-3.5-sonnet",
    "features": ["chat_assist", "task_log", "summarize"]
  }
  ```
  The system shall validate connection khi save config.

### AI-FR-002 — Tóm tắt Conversation

- **Priority:** P2 🟡 COULD
- **Actor:** Employee
- **Description:** When user bấm "Tóm tắt" trong conversation, the system shall gửi N tin nhắn gần nhất tới AI và hiển thị bản tóm tắt.
- **Acceptance Criteria:**
  - Given conversation 200 tin nhắn, When tóm tắt, Then AI trả về summary 3-5 bullet points

### AI-FR-003 — Smart Reply Suggestions

- **Priority:** P2 🟡 COULD
- **Actor:** System
- **Description:** When nhận tin nhắn, the system shall gợi ý 2-3 quick reply options dựa trên context. User tap để gửi hoặc bỏ qua.

### AI-FR-004 — AI Log Task (Natural Language)

- **Priority:** P1 🟠 SHOULD
- **Actor:** Employee
- **Description:** (Xem TASK-FR-006) AI parse text tự nhiên thành timesheet entry.

### AI-FR-005 — /ai Command trong Chat

- **Priority:** P2 🟡 COULD
- **Actor:** Employee
- **Description:** When user gõ `/ai [câu hỏi]` trong chat, the system shall gửi câu hỏi tới AI provider và trả lời ngay trong conversation (chỉ user đó thấy hoặc cả group tùy config).

### AI-FR-006 — Báo cáo HR tự động

- **Priority:** P2 🟡 COULD
- **Actor:** System
- **Description:** The system shall tự động tạo báo cáo HR cuối kỳ lương: tổng hợp công, OT, nghỉ phép, anomalies. Gửi cho Manager/Admin.

### AI-FR-007 — AI Provider Fallback

- **Priority:** P1 🟠 SHOULD
- **Actor:** System
- **Description:** When primary AI provider fail, the system shall fallback sang provider phụ (nếu config). Retry 3 lần trước khi báo lỗi.

### AI-FR-008 — AI Usage Tracking

- **Priority:** P1 🟠 SHOULD
- **Actor:** Admin
- **Description:** The system shall track AI usage: số requests, tokens consumed, cost estimate. Hiển thị trong Admin dashboard.

### AI-FR-009 — AI Feature Toggle

- **Priority:** P1 🟠 SHOULD
- **Actor:** Admin
- **Description:** Admin shall bật/tắt từng AI feature riêng biệt (chat_assist, task_log, summarize, smart_reply) mà không ảnh hưởng features khác.

### AI-FR-010 — AI Response Caching

- **Priority:** P2 🟡 COULD
- **Actor:** System
- **Description:** The system shall cache AI responses cho các query giống nhau (VD: summary cùng conversation) trong Redis TTL 1 giờ để tiết kiệm cost.

