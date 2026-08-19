/// SocketService — đã được thay thế bởi Chat WebSocket + FCM.
///
/// Incoming call được nhận qua hai kênh:
///   - Khi online: event `incoming_call` qua Chat WebSocket (`/ws`)
///   - Khi offline: FCM Push Notification với `type: call_invite`
///
/// File này giữ lại class rỗng để tránh break các import cũ
/// trong quá trình migration. Có thể xóa hoàn toàn sau khi
/// tất cả các import đã được dọn dẹp.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class SocketService {
  SocketService(Ref ref);

  // Không còn dùng Socket.IO.
  // Incoming call được xử lý qua:
  //   1. WebSocket event 'incoming_call' (xem app.dart)
  //   2. FCM push notification type 'call_invite' (xem app.dart)
}

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService(ref);
});
