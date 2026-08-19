import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/agora_call_service.dart';

final agoraCallServiceProvider = Provider<AgoraCallService>((ref) {
  final service = AgoraCallService();
  ref.onDispose(() => service.dispose());
  return service;
});
