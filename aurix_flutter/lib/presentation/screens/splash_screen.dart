import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (prev, next) {
      next.whenData((AuthState state) {
        if (state.session != null) {
          context.go('/home');
        } else {
          context.go('/login');
        }
      });
    });
    final auth = ref.watch(authStateProvider);
    if (auth.hasValue && auth.value!.session == null) {
      context.go('/login');
    } else if (auth.hasValue && auth.value!.session != null) {
      context.go('/home');
    }
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
