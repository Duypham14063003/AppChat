# App Chat
<img width="1379" height="645" alt="Ảnh màn hình 2026-08-19 lúc 23 42 10" src="https://github.com/user-attachments/assets/2bf0a891-e297-424b-9ab2-f61819954b5f" />
<img width="933" height="699" alt="Ảnh màn hình 2026-08-19 lúc 23 41 52" src="https://github.com/user-attachments/assets/72feb7f3-523b-4c04-bc2c-e84f9852f17e" />
<img width="1733" height="766" alt="Ảnh màn hình 2026-08-19 lúc 23 41 39" src="https://github.com/user-attachments/assets/e1024b0c-b873-4450-a1ab-f7a3cf3db852" />
<img width="923" height="700" alt="Ảnh màn hình 2026-08-19 lúc 23 41 23" src="https://github.com/user-attachments/assets/ab6bb362-98c0-4e8a-a7f0-0d802c1b1452" />
<img width="909" height="699" alt="Ảnh màn hình 2026-08-19 lúc 23 40 39" src="https://github.com/user-attachments/assets/5b6cf3d8-7564-4e91-b3fb-87fecfc43ded" />

# AppChat – Nineteen Tech Internal App

  hỗ trợ giao tiếp doanh nghiệp, quản lý nhân sự, chấm công, công việc và thông báo thời gian thực.

  ## Giới thiệu

  AppChat là hệ thống quản lý và giao tiếp nội bộ gồm:

  - Ứng dụng Flutter đa nền tảng.
  - Backend REST API xây dựng bằng NestJS.
  - Chat thời gian thực qua WebSocket.
  - Quản lý nhân sự và chấm công.
  - Quản lý nghỉ phép, hợp đồng và bảng lương.
  - Thông báo đẩy qua Firebase Cloud Messaging.
  - Cuộc gọi âm thanh/video qua Agora.
  - Tích hợp Redis, PostgreSQL và hệ thống Odoo.

  ## Tính năng chính

  ### Xác thực và phân quyền

  - Đăng nhập người dùng.
  - Xác thực bằng JWT Access Token và Refresh Token.
  - Quản lý phiên đăng nhập.
  - Phân quyền theo vai trò RBAC.
  - Tích hợp đăng nhập và đồng bộ dữ liệu với Odoo.
  - Lưu trữ token an toàn trên thiết bị.

  ### Chat nội bộ

  - Chat một-một.
  - Chat nhóm.
  - Gửi và nhận tin nhắn thời gian thực.
  - WebSocket Gateway.
  - Trạng thái online/offline.
  - Trạng thái đã đọc tin nhắn.
  - Gửi hình ảnh, video, file và âm thanh.
  - Reply, forward, edit và recall tin nhắn.
  - Emoji reaction.
  - Bookmark tin nhắn.
  - Tìm kiếm tin nhắn.
  - Offline queue và đồng bộ lại khi kết nối.
  - Thông báo khi có tin nhắn mới.

  ### Quản lý nhân sự

  - Danh sách nhân viên.
  - Hồ sơ nhân viên.
  - Chấm công vào/ra.
  - Lịch sử chấm công.
  - Tính ngày công.
  - Quản lý nghỉ phép.
  - Theo dõi số ngày phép.
  - Quản lý hợp đồng.
  - Nhắc hạn hợp đồng.
  - Quản lý bảng lương.
  - Xuất dữ liệu bảng lương.
  - Mã QR thanh toán ngân hàng cho nhân viên.
  - Báo cáo công việc hằng ngày.

  ### Công việc và phối hợp

  - Đồng bộ project/task với Odoo.
  - Theo dõi task cá nhân.
  - Theo dõi tiến độ công việc.
  - Phân công công việc.
  - Quản lý POC.
  - Theo dõi năng lực và khối lượng công việc.
  - Báo cáo tiến độ theo tuần.

  ### Thông báo

  - Firebase Cloud Messaging.
  - Thông báo foreground/background.
  - Đồng bộ số lượng thông báo chưa đọc.
  - Điều hướng đến đúng màn hình khi người dùng nhấn thông báo.
  - Thông báo cuộc gọi đến.

  ### Cuộc gọi

  - Cuộc gọi âm thanh.
  - Cuộc gọi video.
  - Tích hợp Agora RTC.
  - Tích hợp CallKit trên iOS.
  - Xử lý cuộc gọi đến và cuộc gọi đi.
  - Ringtone và thông báo cuộc gọi.

  ## Kiến trúc hệ thống

  ```text
  Flutter Mobile/Desktop/Web
              |
              | REST API / WebSocket
              v
         NestJS API
              |
       +------+------+
       |             |
   PostgreSQL       Redis
       |
       +--------------------+
       |                    |
     Odoo              Firebase
                         |
                      FCM Push

  Flutter App <------> Agora RTC

  ## Công nghệ sử dụng

   Thành phần                 Công nghệ
  ━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━
   Frontend                   Flutter, Dart
  ─────────────────────────  ──────────────────────────
   State management           Riverpod
  ─────────────────────────  ──────────────────────────
   Navigation                 GoRouter
  ─────────────────────────  ──────────────────────────
   Local database             Drift, SQLite
  ─────────────────────────  ──────────────────────────
   Backend                    NestJS, TypeScript
  ─────────────────────────  ──────────────────────────
   Database                   PostgreSQL 16
  ─────────────────────────  ──────────────────────────
   Cache / PubSub             Redis 7
  ─────────────────────────  ──────────────────────────
   ORM                        TypeORM
  ─────────────────────────  ──────────────────────────
   Authentication             JWT, Passport
  ─────────────────────────  ──────────────────────────
   Real-time communication    WebSocket
  ─────────────────────────  ──────────────────────────
   Push notification          Firebase Cloud Messaging
  ─────────────────────────  ──────────────────────────
   Voice/Video call           Agora RTC
  ─────────────────────────  ──────────────────────────
   File storage               Bunny.net
  ─────────────────────────  ──────────────────────────
   External ERP               Odoo
  ─────────────────────────  ──────────────────────────
   API documentation          Swagger
  ─────────────────────────  ──────────────────────────
   Testing                    Jest, Flutter Test

  ## Cấu trúc thư mục

  .
  ├── backend-mobile-19t/       # Backend NestJS phiên bản đầy đủ
  ├── mobile-19t/               # Workspace chính
  │   ├── apps/
  │   │   ├── api/              # NestJS API
  │   │   └── mobile/           # Flutter application
  │   ├── docs/                 # Tài liệu kỹ thuật
  │   ├── openspec/             # Đặc tả và kế hoạch tính năng
  │   ├── requirements/         # Yêu cầu sản phẩm
  │   ├── srs/                  # Software Requirements Specification
  │   └── docker-compose.yml    # PostgreSQL và Redis
  ├── openspec/                 # OpenSpec ở cấp repository
  ├── README.md
  └── .gitignore

