import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/auth_api.dart';

class AuthRepository {
  AuthRepository();

  ApiUser? _currentUser;

  ApiUser? get currentUser => _currentUser;

  /// Registers user. Returns nothing — user must verify email first.
  Future<void> signUp({
    required String email,
    required String password,
    required String phone,
    String? name,
  }) async {
    try {
      await AuthApi.register(
        email: email,
        password: password,
        name: name?.trim(),
        phone: phone.trim(),
      );
    } on DioException catch (e) {
      final msg = _extractError(e);
      if (msg.contains('already registered') || msg.contains('409')) {
        throw Exception('Этот email уже используется');
      }
      throw Exception(msg);
    } catch (e) {
      throw Exception('Ошибка сети: $e');
    }
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await AuthApi.login(
        email: email,
        password: password,
      );
      _currentUser = result.user;
      return result;
    } on DioException catch (e) {
      debugPrint('[AuthRepo] DioException: ${e.type} ${e.response?.statusCode} ${e.response?.data} ${e.message}');
      final msg = _extractError(e);
      if (msg.contains('invalid credentials')) {
        throw Exception('Неверный email или пароль');
      }
      if (msg.contains('Подтвердите email') || msg.contains('not verified')) {
        throw Exception('Подтвердите email перед входом. Проверьте почту.');
      }
      throw Exception(msg);
    } catch (e) {
      debugPrint('[AuthRepo] Unexpected error: $e');
      throw Exception('Ошибка сети: $e');
    }
  }

  Future<void> signOut() async {
    await AuthApi.signOut();
    _currentUser = null;
  }

  Future<ApiUser?> getCurrentUser() async {
    final user = await AuthApi.me();
    _currentUser = user;
    return user;
  }

  Future<void> resetPasswordForEmail(String email) async {
    try {
      await AuthApi.requestPasswordReset(email: email);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    try {
      await AuthApi.resetPassword(token: token, password: password);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ?? e.message ?? 'Unknown error';
    }
    return e.message ?? 'Network error';
  }
}
