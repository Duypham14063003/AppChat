import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_repository.dart';
import '../models/chat_reminder.dart';
import 'chat_providers.dart';

final conversationRemindersProvider = FutureProvider.family<List<ChatReminder>, String>((ref, convId) async {
  final repo = ref.read(chatRepositoryProvider);
  final maps = await repo.getConversationReminders(convId);
  return maps.map(ChatReminder.fromJson).toList();
});
