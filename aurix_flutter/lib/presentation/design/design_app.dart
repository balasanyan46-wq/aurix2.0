import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/app_config.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/design/design_shell.dart';
import 'package:aurix_flutter/presentation/design/screens/design_auth_screen.dart';
import 'package:aurix_flutter/presentation/landing/landing_page.dart';
import 'package:aurix_flutter/app/auth/auth_store_provider.dart';

/// Design mode app. При настроенном Supabase — требуется вход.
class DesignApp extends ConsumerWidget {
  const DesignApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appStateProvider).locale;
    final auth = ref.watch(authStoreProvider);
    final hasSupabase = AppConfig.isConfigured;

    final home = hasSupabase
        ? (!auth.ready
            ? const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AurixTokens.orange),
                ),
              )
            : (auth.isAuthed ? const DesignShell() : const _UnauthFlow()))
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

enum _UnauthPage { landing, login, register }

class _UnauthFlow extends StatefulWidget {
  const _UnauthFlow();

  @override
  State<_UnauthFlow> createState() => _UnauthFlowState();
}

class _UnauthFlowState extends State<_UnauthFlow> {
  _UnauthPage _page = _UnauthPage.landing;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      pages: [
        MaterialPage(
          child: _DesignLandingAdapter(
            onLogin: () => setState(() => _page = _UnauthPage.login),
            onRegister: () => setState(() => _page = _UnauthPage.register),
          ),
        ),
        if (_page == _UnauthPage.login)
          const MaterialPage(child: DesignAuthScreen()),
        if (_page == _UnauthPage.register)
          MaterialPage(
            child: DesignAuthScreen(key: const ValueKey('register'), startOnRegister: true),
          ),
      ],
      onDidRemovePage: (_) {
        setState(() => _page = _UnauthPage.landing);
      },
    );
  }
}

class _DesignLandingAdapter extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  const _DesignLandingAdapter({required this.onLogin, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    return LandingPage(
      onLogin: onLogin,
      onRegister: onRegister,
    );
  }
}
