import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/core/api/auth_api.dart';
import 'package:aurix_flutter/core/api/token_store.dart';

/// Single source of truth for auth state (JWT + refresh token).
///
/// Guarantees:
/// - [ready] becomes true only after an explicit token restore attempt.
/// - [user] is populated from /users/me if a valid token exists.
/// - If access token is expired, silently refreshes via refresh token.
/// - If refresh fails, user is signed out (Instagram-like: stays logged in
///   for months until refresh token expires).
class AuthStore extends ChangeNotifier {
  bool _ready = false;
  ApiUser? _user;

  bool get ready => _ready;
  ApiUser? get user => _user;
  bool get isAuthed => _user != null;
  String? get userId => _user?.stringId;
  String? get role => _user?.role;

  Future<void> init() async {
    if (_ready) return;

    // Register session-expired callback so interceptor can force sign-out
    ApiClient.onSessionExpired = _onSessionExpired;

    // Try to restore session from stored tokens.
    final token = await TokenStore.read();
    if (token != null) {
      // Try /users/me with current access token
      _user = await AuthApi.me();

      if (_user == null) {
        // Access token expired — try refresh
        final refreshed = await AuthApi.refresh();
        if (refreshed) {
          _user = await AuthApi.me();
        }
        if (_user == null) {
          // Refresh also failed — clear everything
          await TokenStore.clear();
        }
      }
    } else {
      // No access token — check if we have a refresh token
      final refreshToken = await TokenStore.readRefresh();
      if (refreshToken != null) {
        final refreshed = await AuthApi.refresh();
        if (refreshed) {
          _user = await AuthApi.me();
        }
        if (_user == null) {
          await TokenStore.clear();
        }
      }
    }

    _ready = true;
    notifyListeners();
  }

  /// Called after successful login/register.
  void setUser(ApiUser user) {
    _user = user;
    notifyListeners();
  }

  /// Sign out — revoke refresh token on server, clear local tokens.
  Future<void> signOut() async {
    await AuthApi.signOut();
    _user = null;
    notifyListeners();
  }

  /// Called by the refresh interceptor when all tokens are invalid.
  void _onSessionExpired() {
    if (_user != null) {
      _user = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    ApiClient.onSessionExpired = null;
    super.dispose();
  }
}
