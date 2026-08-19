import 'package:nineteen_tech_app/core/config/app_config.dart';

String? resolveChatAvatarUrl(String? avatarUrl) {
  if (avatarUrl == null) return null;

  final trimmed = avatarUrl.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  if (trimmed.startsWith('/')) {
    return '${AppConfig.instance.apiUrl}$trimmed';
  }

  return trimmed;
}
