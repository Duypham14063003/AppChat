# 8.2 Use Cases

## UC-001: Đăng nhập

```
Actor:      Employee
Trigger:    Mở app lần đầu hoặc sau khi logout
Precondition: Có tài khoản Odoo active

Main Flow:
  1. User mở app → hiện màn hình Login
  2. User nhập email + password
  3. User bấm "Đăng nhập"
  4. System gọi Odoo API xác thực
  5. System tạo JWT tokens
  6. System lưu tokens vào secure storage
  7. System mở WebSocket connection
  8. System navigate tới màn hình chính (Chat list)

Alternative Flows:
  3a. User bấm "Đăng nhập" với field trống → hiện validation error
  4a. Odoo trả về lỗi xác thực → hiện "Email hoặc mật khẩu không đúng"
  4b. Odoo không phản hồi (timeout) → hiện "Không thể kết nối, thử lại"
  4c. Đã login fail 5 lần → block 30 phút, hiện countdown

Post-condition: User đã đăng nhập, có JWT tokens, WebSocket connected
```

## UC-002: Gửi tin nhắn text

```
Actor:      Employee
Trigger:    User gõ tin nhắn và bấm Send
Precondition: Đã đăng nhập, đang trong conversation

Main Flow:
  1. User gõ text vào input field
  2. User bấm Send (hoặc Enter)
  3. System tạo UUID cho message
  4. System hiện bubble ngay (Optimistic UI, status=pending)
  5. System gửi qua WebSocket
  6. Server validate + lưu DB + publish Redis
  7. System nhận ACK → update status=sent
  8. Recipients nhận message qua WS → hiện bubble

Alternative Flows:
  5a. Không có mạng → lưu vào Drift queue (status=pending)
      → khi có mạng → auto retry → gửi thành công
  5b. Retry 5 lần thất bại → status=failed, hiện nút Retry
  6a. Server reject (rate limit) → hiện error toast
```

## UC-003: Gọi thoại

```
Actor:      Employee (Caller)
Trigger:    Bấm nút gọi thoại trong conversation
Precondition: Đã đăng nhập, có quyền microphone

Main Flow:
  1. Caller bấm nút Call
  2. System request Agora token từ backend
  3. System gửi FCM push cho Callee
  4. Caller join Agora channel, hiện "Đang gọi..."
  5. Callee nhận incoming call screen
  6. Callee bấm Accept
  7. Callee join Agora channel
  8. Cả 2 nghe được tiếng nhau
  9. Một trong 2 bấm End Call
  10. System lưu call log, hiện trong conversation

Alternative Flows:
  5a. Callee bấm Reject → Caller thấy "Cuộc gọi bị từ chối"
  5b. Callee không trả lời 60s → timeout, ghi "Cuộc gọi nhỡ"
  5c. Callee đang trong cuộc gọi khác → Caller thấy "Đang bận"
  2a. Không có quyền mic → hiện dialog xin quyền
```

## UC-004: Checkin chấm công

```
Actor:      Employee
Trigger:    Bấm nút Checkin trên tab HR
Precondition: Đã đăng nhập, GPS enabled, chưa checkin hôm nay

Main Flow:
  1. User mở tab HR
  2. User bấm "Checkin"
  3. System capture GPS + timestamp + device_id
  4. System lưu local (Drift, status=pending)
  5. System gửi POST /hr/attendance/checkin
  6. Server validate (GPS, timestamp, duplicate check)
  7. Server lưu DB + queue sync Odoo
  8. System hiện "Checkin thành công - 08:02"

Alternative Flows:
  3a. GPS disabled → hiện dialog "Bật GPS để checkin"
  5a. Offline → lưu local, sync khi có mạng (dùng original_timestamp)
  6a. Đã checkin hôm nay → reject "Bạn đã checkin hôm nay"
  6b. GPS ngoài vùng cho phép → reject (nếu geofencing enabled)
```

## UC-005: Xin nghỉ phép

```
Actor:      Employee
Trigger:    Bấm "Tạo đơn nghỉ" trong tab HR
Precondition: Đã đăng nhập

Main Flow:
  1. User bấm "Tạo đơn nghỉ"
  2. User chọn: loại (phép năm/ốm/việc riêng), ngày bắt đầu, ngày kết thúc, lý do
  3. User bấm "Gửi"
  4. System tạo leave request (status=submitted)
  5. System gửi notification cho Manager
  6. Manager nhận notification → mở đơn
  7. Manager bấm Approve/Reject (kèm ghi chú)
  8. System cập nhật status + gửi notification cho Employee
  9. System sync lên Odoo

Alternative Flows:
  2a. Ngày bắt đầu < hôm nay → validation error
  2b. Không đủ phép năm → warning "Bạn còn X ngày phép"
  7a. Manager reject → Employee nhận notification kèm lý do
  9a. Odoo sync fail → retry via BullMQ
```

## UC-006: AI Log Task

```
Actor:      Employee
Trigger:    Bấm nút AI Log hoặc gõ trong Task module
Precondition: Đã đăng nhập, AI provider configured

Main Flow:
  1. User bấm "AI Log Task"
  2. User nhập text tự nhiên: "Hôm nay làm xong API login, mất 3 tiếng"
  3. System gửi tới AI Gateway
  4. AI parse: {task: "API login", hours: 3, date: today, project: auto-detect}
  5. System hiện preview cho user
  6. User confirm (hoặc edit trước khi confirm)
  7. System POST timesheet entry lên Odoo
  8. System hiện "✅ Đã log 3h cho API login"

Alternative Flows:
  4a. AI parse sai → user edit fields trước khi confirm
  4b. AI provider fail → hiện error, suggest manual entry
  7a. Odoo sync fail → lưu local, retry later
```

