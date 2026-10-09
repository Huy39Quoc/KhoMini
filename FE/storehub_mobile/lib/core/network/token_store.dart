import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores credentials separately from ordinary app preferences.
class TokenStore {
  static final TokenStore instance = TokenStore._();
  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'jwt_token';
  static const _refreshKey = 'refresh_token';
  Future<void>? _migration;

  TokenStore._();

  Future<String?> readAccessToken() async {
    await _ensureMigrated();
    return _storage.read(key: _accessKey);
  }

  Future<String?> readRefreshToken() async {
    await _ensureMigrated();
    return _storage.read(key: _refreshKey);
  }

  Future<void> saveLogin(String accessToken, String? refreshToken) async {
    await _ensureMigrated();
    await _storage.write(key: _accessKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    } else {
      await _storage.delete(key: _refreshKey);
    }
    await _removeLegacyTokens();
  }

  Future<void> saveRefresh(String accessToken, String? refreshToken) async {
    await _ensureMigrated();
    await _storage.write(key: _accessKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
    await _removeLegacyTokens();
  }

  Future<void> clear() async {
    await _ensureMigrated();
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _removeLegacyTokens();
  }

  Future<void> _removeLegacyTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  Future<void> _ensureMigrated() => _migration ??= _migrateLegacyTokens();

  Future<void> _migrateLegacyTokens() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_accessKey, _refreshKey]) {
      final legacy = prefs.getString(key);
      if (legacy != null && legacy.isNotEmpty &&
          await _storage.read(key: key) == null) {
        await _storage.write(key: key, value: legacy);
      }
      await prefs.remove(key);
    }
  }
}
