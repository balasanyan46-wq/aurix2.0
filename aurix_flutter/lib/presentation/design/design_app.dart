import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/app_config.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/design/design_shell.dart';
import 'package:aurix_flutter/presentation/design/screens/design_auth_screen.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

/// Design mode app. При настроенном Supabase — требуется вход.
class DesignApp extends ConsumerWidget {
  const DesignApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appStateProvider).locale;
    final authState = ref.watch(authStateProvider);
    final hasSupabase = AppConfig.isConfigured;

    final home = hasSupabase
        ? authState.when(
            data: (state) => state.session != null ? const DesignShell() : const DesignAuthScreen(),
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
            ),
            error: (_, __) => const DesignAuthScreen(),
          )
        : const DesignShell();

    return MaterialApp(
      title: 'Aurix (Design)',
      debugShowCheckedModeBanner: false,
      theme: aurixDarkTheme(),
      home: L10nScope(
        locale: locale,
        child: home,
      ),
    );
  }
}
