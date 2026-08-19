# Odoo Login Integration Guide

Tài liệu này mô tả cách hệ thống backend hiện tại xác thực người dùng qua Odoo, cách cấu hình môi trường, và cách test nhanh để gửi cho người khác thao tác.

## 1. Mục đích

Backend này không tự quản lý mật khẩu người dùng nội bộ cho bước đăng nhập ban đầu. Khi người dùng bấm đăng nhập:

1. Client gọi API `POST /auth/login` của backend.
2. Backend gọi sang Odoo để xác thực email và mật khẩu.
3. Nếu Odoo trả về `uid` hợp lệ, backend mới tạo hoặc cập nhật user local, sau đó phát hành `accessToken` và `refreshToken`.

Nói ngắn gọn: Odoo là nguồn xác thực gốc, backend là nơi cấp session/token cho mobile app.


## 3. Cấu hình môi trường

Các biến môi trường tối thiểu cho login Odoo:

```env tổng 
ODOO_URL=https://erp.19t.vn
ODOO_DB=erp_oddo
ODOO_API_KEY=386c8a362a24bf0046d888439356b90663750c51
ODOO_SERVICE_USERNAME=meeting-service@19t.vn
ODOO_SERVICE_PASSWORD="Meeting@Service#2024!"

```

```env
ODOO_URL=https://erp.19t.vn
ODOO_DB=19t
```

Ý nghĩa:

- `ODOO_URL`: domain Odoo backend sẽ gọi tới.
- `ODOO_DB`: tên database Odoo.

Các biến dưới đây không bắt buộc cho login người dùng thường, nhưng cần cho các thao tác đồng bộ dữ liệu hoặc service account:

```env
ODOO_API_KEY=
ODOO_SERVICE_USERNAME=
ODOO_SERVICE_PASSWORD=
```

## 4. Luồng đăng nhập hiện tại

### 4.1 API mobile/backend gọi

Endpoint:

```http
POST /auth/login
```

Body:

```json
{
  "email": "user@19t.vn",
  "password": "your-password",
  "device_id": "iphone-15-duy",
  "device_name": "iPhone 15 Pro"
}
```

Trong đó:

- `email`: bắt buộc, phải đúng định dạng email.
- `password`: bắt buộc.
- `device_id`: tùy chọn, dùng để quản lý session theo thiết bị.
- `device_name`: tùy chọn, tên thiết bị để hiển thị trong danh sách session.

### 4.2 Backend gọi Odoo như thế nào

Backend gọi trực tiếp endpoint:

```http
POST {ODOO_URL}/web/session/authenticate
```

Payload gửi sang Odoo:

```json
{
  "jsonrpc": "2.0",
  "params": {
    "db": "19t",
    "login": "user@19t.vn",
    "password": "your-password"
  }
}
```

Nếu Odoo trả về:

- `result.uid` có giá trị: đăng nhập thành công.
- `result.uid = false` hoặc không có `uid`: backend trả lỗi đăng nhập.

### 4.3 Sau khi Odoo xác thực thành công

Backend sẽ:

1. Tìm user local theo `odoo_uid`.
2. Nếu chưa có thì tạo user mới.
3. Nếu đã có thì cập nhật lại `name`, `email`, `last_seen_at`.
4. Cấp:
   - `accessToken`
   - `refreshToken`
5. Tạo session local theo thiết bị.
6. Ghi audit log cho sự kiện login.

## 5. Response thành công mẫu

Ví dụ response từ `POST /auth/login`:

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "session-id.random-refresh-token",
  "user": {
    "id": "4f7d8d1d-1111-2222-3333-444444444444",
    "email": "user@19t.vn",
    "name": "Nguyen Van A",
    "department": null,
    "job_title": null,
    "phone_number": null,
    "employment_status": null,
    "avatar_url": null,
    "roles": ["employee"],
    "jobTitle": null,
    "phoneNumber": null,
    "employmentStatus": null,
    "avatarUrl": null
  }
}
```

Lưu ý:

- Cấu trúc thực tế có thể thay đổi nếu `buildAuthUserResponse()` được cập nhật.
- Giá trị `roles` phụ thuộc vào dữ liệu local của hệ thống, không lấy trực tiếp từ Odoo ở bước login.

## 6. Curl mẫu để test

### 6.1 Test qua backend

Đổi `BASE_URL` sang domain backend đang dùng.

```bash
curl -X POST "http://localhost:3000/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@19t.vn",
    "password": "your-password",
    "device_id": "test-device-001",
    "device_name": "Postman Test Device"
  }'
```

Nếu backend local của bạn đang chạy port khác, thay lại cho đúng.

### 6.2 Test trực tiếp vào Odoo

Lệnh này giúp kiểm tra tách biệt xem lỗi là do Odoo hay do backend.

```bash
curl -X POST "https://erp.19t.vn/web/session/authenticate" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "params": {
      "db": "19t",
      "login": "user@19t.vn",
      "password": "your-password"
    }
  }'
```

Nếu Odoo trả kết quả có `uid`, nghĩa là tài khoản Odoo hợp lệ.

## 7. Quy tắc phân biệt 2 loại xác thực Odoo

### 7.1 User login

Dùng khi người dùng đăng nhập app:

- input là `email/password` do người dùng nhập
- gọi hàm `authenticate(email, password)`
- endpoint Odoo dùng: `/web/session/authenticate`

### 7.2 Service account login

Dùng khi backend cần thao tác dữ liệu Odoo mà không phụ thuộc user đang đăng nhập:

- dùng `ODOO_SERVICE_USERNAME`
- dùng `ODOO_SERVICE_PASSWORD` hoặc `ODOO_API_KEY`
- gọi hàm `authenticateServiceAccount()`
- sau đó backend gọi tiếp `/jsonrpc` với `execute_kw`

Phần này không phải login mobile app, mà là login kỹ thuật cho backend sync dữ liệu.

## 8. Lỗi thường gặp

### 8.1 Sai email hoặc mật khẩu

Biểu hiện:

- backend trả `401`
- message thường là `Email hoặc mật khẩu không đúng`

Nguyên nhân:

- tài khoản Odoo không đúng
- mật khẩu Odoo sai

### 8.2 Sai `ODOO_URL` hoặc Odoo không truy cập được

Biểu hiện:

- backend trả `503`
- log có thể chứa `Odoo unreachable` hoặc `Odoo timeout`

Nguyên nhân:

- domain Odoo sai
- mạng không tới được Odoo
- Odoo đang downtime

### 8.3 Sai `ODOO_DB`

Biểu hiện:

- gọi đúng domain Odoo nhưng đăng nhập luôn thất bại
- response Odoo không trả `uid` hợp lệ

Nguyên nhân:

- database name cấu hình không đúng

### 8.4 User đăng nhập được Odoo nhưng không dùng được app

Biểu hiện:

- Odoo auth pass nhưng backend vẫn chặn

Nguyên nhân có thể có:

- user local bị `is_active = false`
- backend ném `ForbiddenException('Tài khoản đã bị vô hiệu hóa')`

## 9. Cách kiểm tra nhanh khi có sự cố

Khi một user báo không login được, kiểm tra theo thứ tự:

1. Gọi trực tiếp Odoo bằng curl ở mục 6.2.
2. Nếu Odoo fail, xử lý ở tài khoản Odoo hoặc cấu hình Odoo.
3. Nếu Odoo pass, gọi backend ở mục 6.1.
4. Nếu backend fail nhưng Odoo pass, kiểm tra:
   - log backend
   - `ODOO_URL`
   - `ODOO_DB`
   - trạng thái `is_active` của user local
   - session/token handling

## 10. Ghi chú cho người vận hành

- Hệ thống này không có “SSO redirect” kiểu OAuth browser flow.
- Đây là mô hình backend nhận `email/password`, rồi backend xác thực với Odoo bằng JSON-RPC/web session API.
- Người dùng đổi mật khẩu ở Odoo thì app sẽ dùng mật khẩu mới đó ở lần login tiếp theo.
- Việc login thành công không có nghĩa là toàn bộ dữ liệu nhân sự đã sync đủ; sync nhân sự là luồng khác.

