Ưng dụng app nội bộ của công ty, để triển khai cac hoạt động nội bộ khi đã là nhân viên của công ty:
- Authen: Login từ tài khoản của oddo - Hệ thống sử dụng service account để gọi Odoo API cho các tác vụ nội bộ:
- Trao đổi thông tin (chat ca nhân, chat nhom), tham khảo telegram ( animation, ui, attachment file, voice,command, emoji,  ghim tin nhan, bot (thiêt lập cac bot), tin nhan đã lưu, phân loại thư mục, cuộc gọi,.... hãy lây telegram làm gôc,)
- Hr: checkin, checkout, xin off, tăng ca (x1.5 trên sô giờ ),  Kì lương bắt đầu từ ngày, Số ngày công tiêu chuẩn => đua data lên oddo
- Projects - Task: lây data tù oddo, AI Giup log task
- Profile: thông kê được thông tin từ cac data trên
- Reminder: nhăc hẹn task,.. liên quan đên thời gian.

Tech stack:
- FE: Flutter (mobile app, window app, mac app, web app) - đạc biệt là phần chat, cần muojt và hiệu quả
- BE: NodeJs (Nestjs)
- Databae: postgreesql - Data chat hàng triệu tin nhan, quan tâm đên performance
- storage: bunny.net
- call: agora
- Tich hợp AI: setting url, api key, model...
- Notification: tôi đang dự kiên firebase
