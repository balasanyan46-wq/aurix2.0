import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/screens/home/home_screen.dart';

/// Главная (Dashboard) — единый опыт "личный продюсер".
/// Реализация делегирована в `HomeScreen`, чтобы вкладка и роут `/home`
/// всегда выглядели одинаково.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HomeScreen(
      onViewDemo: () => context.push('/releases'),
      onCreateRelease: () => context.push('/releases/create'),
      onViewReleases: () => context.push('/releases'),
      onViewSubscription: () => context.push('/subscription'),
      onViewIndex: () => context.push('/index'),
    );
  }
}

