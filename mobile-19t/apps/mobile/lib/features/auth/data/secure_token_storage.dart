import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureTokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage, bool? isWebOverride])
    : _storage = storage ?? const FlutterSecureStorage(),
      _isWeb = isWebOverride ?? kIsWeb;

  final FlutterSecureStorage _storage;
  final bool _isWeb;
  static const _uuid = Uuid();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _deviceIdKey = 'device_id';
  static const _fcmTokenKey = 'fcm_token';
  static const _voipTokenKey = 'voip_token';

  // In-memory cache — avoids repeated Web Crypto decrypt calls on web,
  // which throw OperationError (DOMException) in some browsers.
  String? _accessToken;
  String? _refreshToken;
  String? _deviceId;
  String? _fcmToken;
  String? _voipToken;

  Future<String?> getAccessToken() async {
    if (_accessToken != null) return _accessToken;
    try {
      _accessToken = await readValue(_accessTokenKey);
    } catch (e) {
      debugPrint('[SecureTokenStorage] read accessToken failed: $e');
    }
    return _accessToken;
  }

  Future<String?> getRefreshToken() async {
    // On web, another tab can rotate refresh tokens while this tab still has
    // an old in-memory value, so refresh-token freshness beats cache reuse.
    if (!_isWeb && _refreshToken != null) return _refreshToken;
    try {
      final persistedRefreshToken = await readValue(_refreshTokenKey);
      _refreshToken = persistedRefreshToken;
    } catch (e) {
      debugPrint('[SecureTokenStorage] read refreshToken failed: $e');
    }
    return _refreshToken;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    try {
      await Future.wait([
        writeValue(_accessTokenKey, accessToken),
        writeValue(_refreshTokenKey, refreshToken),
      ]);
    } catch (e) {
      debugPrint('[SecureTokenStorage] write tokens failed: $e');
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    try {
      await Future.wait([
        deleteValue(_accessTokenKey),
        deleteValue(_refreshTokenKey),
      ]);
    } catch (e) {
      debugPrint('[SecureTokenStorage] clear tokens failed: $e');
    }
  }

  Future<String?> getDeviceId() async {
    if (_deviceId != null) return _deviceId;
    try {
      _deviceId = await readValue(_deviceIdKey);
    } catch (e) {
      debugPrint('[SecureTokenStorage] read deviceId failed: $e');
    }
    return _deviceId;
  }

  Future<String> getOrCreateDeviceId() async {
    final existing = await getDeviceId();
    if (existing != null && existing.isNotEmpty) return existing;

    final deviceId = _uuid.v4();
    _deviceId = deviceId;
    try {
      await writeValue(_deviceIdKey, deviceId);
    } catch (e) {
      debugPrint('[SecureTokenStorage] write deviceId failed: $e');
    }
    return deviceId;
  }

  Future<String?> getFcmToken() async {
    if (_fcmToken != null) return _fcmToken;
    try {
      _fcmToken = await readValue(_fcmTokenKey);
    } catch (e) {
      debugPrint('[SecureTokenStorage] read fcmToken failed: $e');
    }
    return _fcmToken;
  }

  Future<void> saveFcmToken(String fcmToken) async {
    _fcmToken = fcmToken;
    try {
      await writeValue(_fcmTokenKey, fcmToken);
    } catch (e) {
      debugPrint('[SecureTokenStorage] write fcmToken failed: $e');
    }
  }

  Future<void> clearFcmToken() async {
    _fcmToken = null;
    try {
      await deleteValue(_fcmTokenKey);
    } catch (e) {
      debugPrint('[SecureTokenStorage] clear fcmToken failed: $e');
    }
  }

  Future<String?> getVoipToken() async {
    if (_voipToken != null) return _voipToken;
    try {
      _voipToken = await readValue(_voipTokenKey);
    } catch (e) {
      debugPrint('[SecureTokenStorage] read voipToken failed: $e');
    }
    return _voipToken;
  }

  Future<void> saveVoipToken(String voipToken) async {
    _voipToken = voipToken;
    try {
      await writeValue(_voipTokenKey, voipToken);
    } catch (e) {
      debugPrint('[SecureTokenStorage] write voipToken failed: $e');
    }
  }

  Future<void> clearVoipToken() async {
    _voipToken = null;
    try {
      await deleteValue(_voipTokenKey);
    } catch (e) {
      debugPrint('[SecureTokenStorage] clear voipToken failed: $e');
    }
  }

  @protected
  Future<String?> readValue(String key) {
    return _storage.read(key: key);
  }

  @protected
  Future<void> writeValue(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @protected
  Future<void> deleteValue(String key) {
    return _storage.delete(key: key);
  }
}
