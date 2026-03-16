import 'package:aurix_flutter/core/api/auth_api.dart';
import 'package:aurix_flutter/core/api/token_store.dart';

/// Auth service wrapping the REST API.
class AuthService {
  ApiUser? _currentUser;

  ApiUser? get currentUser => _currentUser;

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await AuthApi.register(email: email, password: password);
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final result = await AuthApi.login(email: email, password: password);
    _currentUser = result.user;
    return result;
  }

  Future<void> signOut() async {
    await AuthApi.signOut();
    _currentUser = null;
  }

  bool get hasSession => TokenStore.cachedToken != null;
}
