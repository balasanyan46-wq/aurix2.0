import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurix_flutter/data/supabase_client.dart';

/// Сервис аутентификации — обёртка над Supabase Auth.
class AuthService {
  User? get currentUser => supabase.auth.currentUser;

  Stream<AuthState> get authState => supabase.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: null,
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Session? get currentSession => supabase.auth.currentSession;
}
