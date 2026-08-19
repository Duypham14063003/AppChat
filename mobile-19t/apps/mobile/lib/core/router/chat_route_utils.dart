String? conversationIdForChatLocation(String? location) {
  if (location == null || location.isEmpty) return null;
  final chatMatch = RegExp(r'^/chat/([^/?#]+)$').firstMatch(location);
  return chatMatch?.group(1);
}
