import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure token store for access + refresh tokens.
/// - Mobile (iOS/Android/macOS): uses flutter_secure_storage (Keychain / EncryptedSharedPreferences)
/// - Web/Linux/Windows: falls back to SharedPreferences
class TokenStore {
  static const _accessKey = 'aurix_jwt_token';
  static const _refreshKey = 'aurix_refresh_token';
  static String? _cachedAccess;
  static String? _cachedRefresh;
  /// Use secure storage only on iOS and Android.
  /// macOS Keychain requires signed builds with keychain-access-groups entitlement,
  /// so we fall back to SharedPreferences in debug/unsigned builds.
  static final bool _useSecure = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Access token ──────────────────────────────────

  static Future<void> save(String token) async {
    _cachedAccess = token;
    await _write(_accessKey, token);
  }

  static Future<String?> read() async {
    if (_cachedAccess != null) return _cachedAccess;
    _cachedAccess = await _read(_accessKey);
    return _cachedAccess;
  }

  static String? get cachedToken => _cachedAccess;

  // ── Refresh token ─────────────────────────────────

  static Future<void> saveRefresh(String token) async {
    _cachedRefresh = token;
    await _write(_refreshKey, token);
  }

  static Future<String?> readRefresh() async {
    if (_cachedRefresh != null) return _cachedRefresh;
    _cachedRefresh = await _read(_refreshKey);
    return _cachedRefresh;
  }

  static String? get cachedRefreshToken => _cachedRefresh;

  // ── Clear all ─────────────────────────────────────

  static Future<void> clear() async {
    _cachedAccess = null;
    _cachedRefresh = null;
    await _delete(_accessKey);
    await _delete(_refreshKey);
  }

  // ── Private helpers ───────────────────────────────

  static Future<void> _write(String key, String value) async {
    if (_useSecure) {
      await _secure.write(key: key, value: value);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  static Future<String?> _read(String key) async {
    if (_useSecure) {
      return _secure.read(key: key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  static Future<void> _delete(String key) async {
    if (_useSecure) {
      await _secure.delete(key: key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }
}
