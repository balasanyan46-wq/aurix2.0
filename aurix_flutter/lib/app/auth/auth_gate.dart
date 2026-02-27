import 'package:aurix_flutter/app/auth/auth_store_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/landing/landing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Prevents rendering any user-specific UI until the Supabase session is restored.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStoreProvider);

    if (!auth.ready) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AurixTokens.orange),
        ),
      );
    }

    if (!auth.isAuthed) {
      return const LandingPage();
    }

    // Authed users should be redirected to /home by the router.
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AurixTokens.orange),
      ),
    );
  }
}

