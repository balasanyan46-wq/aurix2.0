import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/presentation/screens/auth/login_screen.dart';
import 'package:aurix_flutter/presentation/screens/auth/register_screen.dart';
import 'package:aurix_flutter/features/app_shell/app_shell_scaffold.dart';
import 'package:aurix_flutter/features/profile/presentation/profile_page.dart';
import 'package:aurix_flutter/features/profile/presentation/profile_gate.dart';
import 'package:aurix_flutter/presentation/screens/releases/releases_list_screen.dart';
import 'package:aurix_flutter/presentation/screens/releases/release_detail_screen.dart';
import 'package:aurix_flutter/presentation/screens/releases/create_release_screen.dart';
import 'package:aurix_flutter/presentation/screens/admin/admin_panel.dart';
import 'package:aurix_flutter/presentation/screens/studio/studio_screen.dart';
import 'package:aurix_flutter/presentation/screens/subscription/subscription_route_screen.dart';
import 'package:aurix_flutter/screens/home/home_screen.dart';
import 'package:aurix_flutter/screens/analytics/analytics_screen.dart';
import 'package:aurix_flutter/screens/promotion/promotion_screen.dart';
import 'package:aurix_flutter/screens/finances/finances_screen.dart';
import 'package:aurix_flutter/screens/team/team_screen.dart';
import 'package:aurix_flutter/screens/services/services_screen.dart';
import 'package:aurix_flutter/screens/support/support_screen.dart';
import 'package:aurix_flutter/screens/settings/settings_screen.dart';
import 'package:aurix_flutter/features/legal/presentation/legal_list_page.dart';
import 'package:aurix_flutter/features/legal/presentation/legal_detail_page.dart';
import 'package:aurix_flutter/features/legal/presentation/legal_history_page.dart';
import 'package:aurix_flutter/features/index/presentation/screens/index_home_screen.dart';
import 'package:aurix_flutter/features/index/presentation/screens/artist_index_profile_screen.dart';
import 'package:aurix_flutter/features/index_engine/presentation/index_engine_debug_screen.dart';
import 'package:aurix_flutter/presentation/landing/landing_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final hasUser = authState.valueOrNull?.session != null;
      final loc = state.matchedLocation;
      final isPublic = loc == '/' || loc == '/login' || loc == '/register';
      if (isLoading) return null;
      if (!hasUser && !isPublic) return '/';
      if (hasUser && isPublic) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingPage()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) {
          final loc = state.matchedLocation;
          return AppShellScaffold(
            currentLocation: loc,
            child: ProfileGate(location: loc, child: child),
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(child: _HomeRoute()),
          ),
          GoRoute(
            path: '/releases',
            pageBuilder: (context, state) => const NoTransitionPage(child: ReleasesListScreen()),
          ),
          GoRoute(
            path: '/releases/create',
            pageBuilder: (context, state) => const NoTransitionPage(child: CreateReleaseScreen()),
          ),
          GoRoute(
            path: '/releases/:id',
            pageBuilder: (context, state) => NoTransitionPage(child: ReleaseDetailScreen(releaseId: state.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/upload',
            redirect: (_, __) => '/releases/create',
          ),
          GoRoute(
            path: '/stats',
            pageBuilder: (context, state) => const NoTransitionPage(child: AnalyticsScreen()),
          ),
          GoRoute(
            path: '/promo',
            pageBuilder: (context, state) => const NoTransitionPage(child: PromotionScreen()),
          ),
          GoRoute(
            path: '/ai',
            pageBuilder: (context, state) => const NoTransitionPage(child: StudioScreen()),
          ),
          GoRoute(
            path: '/finance',
            pageBuilder: (context, state) => const NoTransitionPage(child: FinancesScreen()),
          ),
          GoRoute(
            path: '/team',
            pageBuilder: (context, state) => const NoTransitionPage(child: TeamScreen()),
          ),
          GoRoute(
            path: '/subscription',
            pageBuilder: (context, state) => const NoTransitionPage(child: SubscriptionRouteScreen()),
          ),
          GoRoute(
            path: '/services',
            pageBuilder: (context, state) => const NoTransitionPage(child: ServicesScreen()),
          ),
          GoRoute(
            path: '/support',
            pageBuilder: (context, state) => const NoTransitionPage(child: SupportScreen()),
          ),
          GoRoute(
            path: '/legal',
            pageBuilder: (context, state) => const NoTransitionPage(child: LegalListPage()),
          ),
          GoRoute(
            path: '/legal/history',
            pageBuilder: (context, state) => const NoTransitionPage(child: LegalHistoryPage()),
          ),
          GoRoute(
            path: '/legal/:id',
            pageBuilder: (context, state) => NoTransitionPage(child: LegalDetailPage(templateId: state.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) {
              final mandatory = state.uri.queryParameters['mandatory'] == '1';
              return NoTransitionPage(child: ProfilePage(isMandatory: mandatory));
            },
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
          ),
          GoRoute(
            path: '/index',
            pageBuilder: (context, state) => const NoTransitionPage(child: IndexHomeScreen()),
          ),
          GoRoute(
            path: '/index/artist/:id',
            pageBuilder: (context, state) => NoTransitionPage(
              child: ArtistIndexProfileScreen(artistId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/index/debug',
            pageBuilder: (context, state) => const NoTransitionPage(child: IndexEngineDebugScreen()),
          ),
          GoRoute(
            path: '/admin',
            pageBuilder: (context, state) {
              final tab = state.uri.queryParameters['tab'];
              return NoTransitionPage(child: AdminPanel(initialTab: tab));
            },
          ),
        ],
      ),
    ],
  );
});

/// Home with go_router callbacks.
class _HomeRoute extends StatelessWidget {
  const _HomeRoute();

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      onViewDemo: () => context.go('/releases'),
      onCreateRelease: () => context.push('/releases/create'),
      onViewReleases: () => context.go('/releases'),
      onViewSubscription: () => context.go('/subscription'),
      onViewIndex: () => context.go('/index'),
    );
  }
}
