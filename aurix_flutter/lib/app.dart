import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/router/app_router.dart';

class AurixApp extends ConsumerWidget {
  const AurixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return L10nScope(
      locale: AppLocale.ru,
      child: MaterialApp.router(
        title: 'Aurix',
        debugShowCheckedModeBanner: false,
        theme: aurixDarkTheme(),
        darkTheme: aurixDarkTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    );
  }
}
