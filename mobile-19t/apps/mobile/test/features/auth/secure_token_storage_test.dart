import 'package:flutter_test/flutter_test.dart';
import 'package:nineteen_tech_app/features/auth/data/secure_token_storage.dart';

void main() {
  group('SecureTokenStorage', () {
    test(
      're-reads persisted refresh token on web when another tab rotates it',
      () async {
        final storage = _TestSecureTokenStorage(isWeb: true);
        await storage.saveTokens(
          accessToken: 'access-old',
          refreshToken: 'refresh-old',
        );

        storage.persistedValues['refresh_token'] = 'refresh-new';

        expect(await storage.getRefreshToken(), 'refresh-new');
        expect(storage.readCounts['refresh_token'], 1);
      },
    );

    test(
      'keeps using cached refresh token off web to preserve storage optimization',
      () async {
        final storage = _TestSecureTokenStorage(isWeb: false);
        await storage.saveTokens(
          accessToken: 'access-old',
          refreshToken: 'refresh-old',
        );

        storage.persistedValues['refresh_token'] = 'refresh-new';

        expect(await storage.getRefreshToken(), 'refresh-old');
        expect(storage.readCounts['refresh_token'] ?? 0, 0);
      },
    );
  });
}

class _TestSecureTokenStorage extends SecureTokenStorage {
  _TestSecureTokenStorage({required bool isWeb}) : super(null, isWeb);

  final Map<String, String?> persistedValues = {};
  final Map<String, int> readCounts = {};

  @override
  Future<String?> readValue(String key) async {
    readCounts[key] = (readCounts[key] ?? 0) + 1;
    return persistedValues[key];
  }

  @override
  Future<void> writeValue(String key, String value) async {
    persistedValues[key] = value;
  }

  @override
  Future<void> deleteValue(String key) async {
    persistedValues.remove(key);
  }
}
