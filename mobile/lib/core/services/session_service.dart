import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  static VoidCallback? onSessionExpired;

  static void notifySessionExpired() {
    onSessionExpired?.call();
  }

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kAccessToken = 'ms_access_token';
  static const _kRefreshToken = 'ms_refresh_token';
  static const _kUserId = 'ms_user_id';
  static const _kEmail = 'ms_email';
  static const _kFullName = 'ms_full_name';
  static const _kRole = 'ms_role';

  static Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String email,
    required String fullName,
    required String role,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
      _storage.write(key: _kUserId, value: userId),
      _storage.write(key: _kEmail, value: email),
      _storage.write(key: _kFullName, value: fullName),
      _storage.write(key: _kRole, value: role),
    ]);
  }

  static Future<Map<String, String?>> loadSession() async {
    final values = await Future.wait([
      _storage.read(key: _kAccessToken),
      _storage.read(key: _kRefreshToken),
      _storage.read(key: _kUserId),
      _storage.read(key: _kEmail),
      _storage.read(key: _kFullName),
      _storage.read(key: _kRole),
    ]);
    return {
      'accessToken': values[0],
      'refreshToken': values[1],
      'userId': values[2],
      'email': values[3],
      'fullName': values[4],
      'role': values[5],
    };
  }

  static Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  static Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);

  static Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
    ]);
  }

  static Future<void> clearSession() => _storage.deleteAll();
}
