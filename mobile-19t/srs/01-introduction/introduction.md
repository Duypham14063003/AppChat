# 1. Introduction

## 1.1 Purpose

Tài liệu này mô tả đầy đủ các yêu cầu phần mềm cho **Nineteen Tech Internal App** — ứng dụng nội bộ cross-platform phục vụ hoạt động vận hành của công ty Nineteen Tech (19T).

Đối tượng sử dụng tài liệu:
- Development team (Flutter + NestJS)
- Project Manager
- QA/Tester
- Stakeholders (Ban lãnh đạo 19T)

## 1.2 Product Scope

**Nineteen Tech Internal App** là ứng dụng nội bộ tích hợp các chức năng:

| Module | Mô tả |
|--------|-------|
| Authentication | Đăng nhập qua Odoo SSO, JWT token management |
| Chat | Nhắn tin cá nhân/nhóm kiểu Telegram (text, voice, file, emoji, bot) |
| Call | Gọi thoại/video cross-platform qua Agora |
| HR | Chấm công, xin nghỉ, tăng ca, kỳ lương — sync Odoo |
| Projects & Tasks | Quản lý task từ Odoo, AI hỗ trợ log task |
| Profile | Thống kê thông tin cá nhân từ các module |
| AI | Tích hợp AI linh hoạt (OpenAI, Anthropic, custom) |
| Notification | Push notification (FCM) + in-app notification |
| Reminder | Nhắc hẹn task, deadline, sự kiện |

**Platforms:** iOS, Android, Windows, macOS, Web

**Không bao gồm:**
- Quản lý tài chính/kế toán (thuộc Odoo)
- CRM / Sales (thuộc Odoo)
- Public-facing features (chỉ dùng nội bộ)

## 1.3 Definitions, Acronyms, and Abbreviations

| Thuật ngữ | Định nghĩa |
|-----------|-----------|
| 19T | Nineteen Tech — tên công ty |
| Odoo | Hệ thống ERP đang sử dụng tại erp.19t.vn |
| SSO | Single Sign-On — đăng nhập một lần |
| JWT | JSON Web Token — cơ chế xác thực |
| FCM | Firebase Cloud Messaging — push notification |
| SFU | Selective Forwarding Unit — kiến trúc media server (Agora) |
| WS | WebSocket — giao thức real-time |
| OT | Overtime — tăng ca |
| FTS | Full-Text Search — tìm kiếm toàn văn |
| EARS | Easy Approach to Requirements Syntax |
| FR | Functional Requirement |
| NFR | Non-Functional Requirement |
| E2E | End-to-End |
| CDN | Content Delivery Network |
| FMEA | Failure Mode and Effects Analysis |

## 1.4 References

| Tài liệu | Mô tả |
|-----------|-------|
| IEEE 830-1998 | Recommended Practice for SRS |
| IEEE 29148:2018 | Systems and software engineering — Life cycle processes — Requirements engineering |
| `requirements/brief.md` | Brief dự án gốc |
| `requirements/brainstom.md` | Brainstorm chi tiết kiến trúc và tính năng |
| `requirements/third_party_libraries.html` | Danh sách thư viện third-party |
| `requirements/pre_coding_brainstorm_checklist.html` | Checklist các vấn đề cần giải quyết |
| Odoo 17 API Documentation | https://www.odoo.com/documentation/17.0/developer/reference/external_api.html |
| Agora Flutter SDK | https://docs.agora.io/en/video-calling/get-started/get-started-sdk?platform=flutter |
| Bunny.net Storage API | https://docs.bunny.net/reference/storage-api |

## 1.5 Document Overview

Tài liệu SRS này được tổ chức theo chuẩn IEEE 830 với các điều chỉnh phù hợp cho dự án cross-platform:

- **Section 2** — Tổng quan sản phẩm, đặc điểm người dùng, ràng buộc
- **Section 3** — Kiến trúc hệ thống và tech stack
- **Section 4** — Yêu cầu chức năng chi tiết theo từng module
- **Section 5** — Yêu cầu phi chức năng (performance, security, usability)
- **Section 6** — Yêu cầu dữ liệu (schema, data flow, data dictionary)
- **Section 7** — Giao diện bên ngoài (API, Odoo, third-party)
- **Section 8** — Phụ lục (glossary, use cases, traceability, risk)

