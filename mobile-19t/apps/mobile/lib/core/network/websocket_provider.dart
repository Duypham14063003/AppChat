import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/websocket_manager.dart';
import '../../features/auth/providers/auth_notifier.dart';
import '../config/app_config.dart';

final webSocketManagerProvider = Provider<WebSocketManager>((ref) {
  final manager = WebSocketManager(
    baseUrl: AppConfig.instance.apiUrl,
    tokenProvider: () {
      // This will be called synchronously — token should be cached
      // The actual async retrieval happens in the notifier
      return _cachedToken ?? '';
    },
  );

  // Attach token refresher so reconnects can refresh expired tokens
  manager.tokenRefresher = () async {
    try {
      final storage = ref.read(secureTokenStorageProvider);
      final accessToken = await storage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        setCachedToken(accessToken);
        return accessToken;
      }
    } catch (e) {
      // Fall back to cached token
    }
    return null;
  };

  ref.onDispose(() => manager.dispose());
  return manager;
});

// Simple token cache for synchronous access in WS manager
String? _cachedToken;

/// Set the cached token for WS auth handshake
void setCachedToken(String token) {
  _cachedToken = token;
}

void clearCachedToken() {
  _cachedToken = null;
}

final webSocketConnectionProvider = StreamProvider<WsConnectionState>((ref) {
  final manager = ref.watch(webSocketManagerProvider);
  return manager.stateStream;
});

/// Call this to initialize WS connection after auth
void initializeWebSocket(WidgetRef ref) async {
  final tokenStorage = ref.read(secureTokenStorageProvider);
  final accessToken = await tokenStorage.getAccessToken();
  if (accessToken != null) {
    setCachedToken(accessToken);
    ref.read(webSocketManagerProvider).connect();
  }
}
