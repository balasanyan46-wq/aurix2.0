import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:aurix_flutter/data/repositories/profile_repository.dart';

class AuthRepository {
  AuthRepository({required this.profileRepository});
  final ProfileRepository profileRepository;

  User? get currentUser => supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  Future<void> signUp({
    required String email,
    required String password,
    required String phone,
  }) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: null,
    );
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        await profileRepository.upsertProfile(
          id: user.id,
          email: user.email ?? email,
          displayName: null,
          phone: phone,
          plan: 'base',
        );
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('23505') || msg.contains('unique') || msg.contains('duplicate') || msg.contains('profiles_phone')) {
          throw AuthException('Этот номер уже используется');
        }
        rethrow;
      }
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
    final user = supabase.auth.currentUser;
    if (user != null) {
      await profileRepository.upsertProfile(
        id: user.id,
        email: user.email ?? email,
        displayName: null,
        plan: 'base',
      );
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  Session? get currentSession => supabase.auth.currentSession;
}
