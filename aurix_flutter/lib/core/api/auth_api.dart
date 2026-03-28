import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'token_store.dart';

/// User data returned by the backend.
class ApiUser {
  final String id;
  final String email;
  final String? name;
  final String role;

  const ApiUser({
    required this.id,
    required this.email,
    this.name,
    this.role = 'artist',
  });

  factory ApiUser.fromJson(Map<String, dynamic> json) => ApiUser(
        id: json['id'].toString(),
        email: json['email'] as String? ?? '',
        name: json['name'] as String?,
        role: json['role'] as String? ?? 'artist',
      );

  /// Alias for backward compatibility.
  String get stringId => id;
}

/// Auth result containing user + JWT token.
class AuthResult {
  final ApiUser user;
  final String token;
  const AuthResult({required this.user, required this.token});
}

/// REST auth API wrapping /users/* endpoints.
class AuthApi {
  AuthApi._();

  /// POST /users/register
  /// Sends verification email. User must confirm before login.
  static Future<void> register({
    required String email,
    required String password,
    String? name,
    String? phone,
  }) async {
    await ApiClient.post('/users/register', data: {
      'email': email,
      'password': password,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    });
  }

  /// POST /auth/request-password-reset
  static Future<void> requestPasswordReset({required String email}) async {
    await ApiClient.post('/auth/request-password-reset', data: {
      'email': email,
    });
  }

  /// POST /auth/reset-password
  static Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await ApiClient.post('/auth/reset-password', data: {
      'token': token,
      'password': password,
    });
  }

  /// POST /users/login
  /// Returns access token + refresh token. Both are stored locally.
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final res = await ApiClient.post('/users/login', data: {
      'email': email,
      'password': password,
    });
    final body = _asMap(res.data);
    final token = body['token']?.toString() ?? '';
    if (token.isEmpty) throw Exception('Сервер не вернул токен');
    final refreshToken = body['refreshToken']?.toString();

    await TokenStore.save(token);
    if (refreshToken != null) {
      await TokenStore.saveRefresh(refreshToken);
    }

    return AuthResult(
      user: ApiUser.fromJson(_asMap(body['user'])),
      token: token,
    );
  }

  /// POST /auth/refresh — exchange refresh token for new access + refresh tokens.
  /// Returns true if refresh succeeded, false if user must re-login.
  static Future<bool> refresh() async {
    final refreshToken = await TokenStore.readRefresh();
    if (refreshToken == null) return false;

    try {
      final res = await ApiClient.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });
      final body = _asMap(res.data);
      final newAccess = body['token']?.toString() ?? '';
      if (newAccess.isEmpty) throw Exception('No token in refresh response');
      final newRefresh = body['refreshToken']?.toString();

      await TokenStore.save(newAccess);
      if (newRefresh != null) {
        await TokenStore.saveRefresh(newRefresh);
      }
      return true;
    } catch (e) {
      debugPrint('[AuthApi] refresh() failed: $e');
      // Refresh token is invalid/expired — clear everything
      await TokenStore.clear();
      return false;
    }
  }

  /// GET /users/me — validate current token & get user.
  static Future<ApiUser?> me() async {
    final token = await TokenStore.read();
    if (token == null) return null;
    try {
      final res = await ApiClient.get('/users/me');
      final body = _asMap(res.data);
      final userData = body['user'];
      if (userData == null) return null;
      return ApiUser.fromJson(_asMap(userData));
    } catch (e) {
      debugPrint('[AuthApi] me() failed: $e');
      return null;
    }
  }

  /// Sign out — revoke refresh token on server, clear local tokens.
  static Future<void> signOut() async {
    final refreshToken = await TokenStore.readRefresh();
    if (refreshToken != null) {
      try {
        await ApiClient.post('/auth/logout', data: {
          'refreshToken': refreshToken,
        });
      } catch (_) {
        // Best-effort server revocation
      }
    }
    await TokenStore.clear();
  }

  /// Check if we have a stored token.
  static Future<bool> hasToken() async {
    final token = await TokenStore.read();
    return token != null;
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
