import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/app/auth/auth_gate.dart';
import 'package:aurix_flutter/app/auth/auth_store_provider.dart';
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
import 'package:aurix_flutter/presentation/screens/studio/studio_hub_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/artist_screen.dart';
import 'package:aurix_flutter/presentation/screens/subscription/subscription_route_screen.dart';
import 'package:aurix_flutter/presentation/screens/billing/credits_screen.dart';
import 'package:aurix_flutter/presentation/screens/growth/achievements_screen.dart';
import 'package:aurix_flutter/presentation/screens/growth/goals_screen.dart';
import 'package:aurix_flutter/presentation/screens/growth/public_profile_screen.dart';
import 'package:aurix_flutter/presentation/screens/home/home_screen.dart';
import 'package:aurix_flutter/presentation/screens/analytics/analytics_screen.dart';
import 'package:aurix_flutter/presentation/screens/analytics/release_plan_screen.dart';
import 'package:aurix_flutter/presentation/screens/analytics/promo_ideas_screen.dart';
import 'package:aurix_flutter/presentation/screens/promotion/promotion_screen.dart';
import 'package:aurix_flutter/presentation/screens/finances/finances_screen.dart';
import 'package:aurix_flutter/presentation/screens/team/team_screen.dart';
import 'package:aurix_flutter/features/production/presentation/production_page.dart';
import 'package:aurix_flutter/presentation/screens/services/services_screen.dart';
import 'package:aurix_flutter/presentation/screens/support/support_screen.dart';
import 'package:aurix_flutter/presentation/screens/settings/settings_screen.dart';
import 'package:aurix_flutter/features/legal/presentation/legal_list_page.dart';
import 'package:aurix_flutter/features/legal/presentation/legal_detail_page.dart';
import 'package:aurix_flutter/features/legal/presentation/legal_history_page.dart';
import 'package:aurix_flutter/features/legal/compliance/legal_pages.dart';
import 'package:aurix_flutter/features/settings/presentation/account_deletion_request_page.dart';
import 'package:aurix_flutter/features/index/presentation/screens/index_home_screen.dart';
import 'package:aurix_flutter/features/index/presentation/screens/artist_index_profile_screen.dart';
import 'package:aurix_flutter/features/index_engine/presentation/index_engine_debug_screen.dart';
import 'package:aurix_flutter/features/dnk/presentation/dnk_screen.dart';
import 'package:aurix_flutter/features/dnk/presentation/dnk_tests_hub_screen.dart';
import 'package:aurix_flutter/features/dnk/presentation/dnk_test_launch_screen.dart';
import 'package:aurix_flutter/features/dnk/presentation/dnk_test_result_loader_screen.dart';
import 'package:aurix_flutter/features/progress/presentation/screens/progress_home_screen.dart';
import 'package:aurix_flutter/features/progress/presentation/screens/habit_manage_screen.dart';
import 'package:aurix_flutter/features/navigator/presentation/screens/navigator_landing_screen.dart';
import 'package:aurix_flutter/features/navigator/presentation/screens/navigator_onboarding_screen.dart';
import 'package:aurix_flutter/features/navigator/presentation/screens/navigator_ai_intake_screen.dart';
import 'package:aurix_flutter/features/navigator/presentation/screens/navigator_results_screen.dart';
import 'package:aurix_flutter/features/navigator/presentation/screens/navigator_library_screen.dart';
import 'package:aurix_flutter/features/navigator/presentation/screens/navigator_article_screen.dart';
import 'package:aurix_flutter/features/navigator/presentation/screens/navigator_saved_screen.dart';
import 'package:aurix_flutter/presentation/widgets/subscription_guard.dart';
import 'package:aurix_flutter/presentation/screens/promo/promo_video_screen.dart';

/// Fade transition for shell-internal pages (200ms, easeOut).
class _FadePage<T> extends CustomTransitionPage<T> {
  _FadePage({required super.child, super.key})
      : super(
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 160),
        );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStore = ref.read(authStoreProvider);
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: authStore,
    redirect: (context, state) {
      final isReady = authStore.ready;
      final hasUser = authStore.isAuthed;
      final loc = state.matchedLocation;
      final isAuthPage = loc == '/' || loc == '/login' || loc == '/register';
      final isLegalPublic = loc == '/legal' || loc.startsWith('/legal/');
      final isPublic = isAuthPage || isLegalPublic;
      if (!isReady) {
        // Never render any user-specific screen until session restore is complete.
        return loc == '/' ? null : '/';
      }
      if (!hasUser && !isPublic) return '/';
      if (hasUser && isAuthPage) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const AuthGate()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/legal', builder: (_, __) => const LegalHubPage()),
      GoRoute(
        path: '/legal/:slug',
        builder: (_, state) => LegalDocumentPage(slug: state.pathParameters['slug']!),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return Consumer(builder: (context, ref, _) {
            final loc = state.matchedLocation;
            final userKey = ref.watch(authStoreProvider).userId ?? 'anon';
            // Reset all user-scoped providers on user switch to prevent stale data flashes.
            return ProviderScope(
              key: ValueKey(userKey),
              child: AppShellScaffold(
                currentLocation: loc,
                child: ProfileGate(location: loc, child: child),
              ),
            );
          });
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => _FadePage(child: const _HomeRoute()),
          ),
          GoRoute(
            path: '/releases',
            pageBuilder: (context, state) => _FadePage(child: const ReleasesListScreen()),
          ),
          GoRoute(
            path: '/releases/create',
            pageBuilder: (context, state) => _FadePage(child: const CreateReleaseScreen()),
          ),
          GoRoute(
            path: '/releases/:id',
            pageBuilder: (context, state) => _FadePage(child: ReleaseDetailScreen(releaseId: state.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/upload',
            redirect: (_, __) => '/releases/create',
          ),
          GoRoute(
            path: '/stats',
            pageBuilder: (context, state) => _FadePage(child: const AnalyticsScreen()),
          ),
          GoRoute(
            path: '/stats/release-plan',
            pageBuilder: (context, state) => _FadePage(child: const ReleasePlanScreen()),
          ),
          GoRoute(
            path: '/stats/promo-ideas',
            pageBuilder: (context, state) => _FadePage(child: const PromoIdeasScreen()),
          ),
          GoRoute(
            path: '/promo',
            pageBuilder: (context, state) => _FadePage(
              child: const SubscriptionGuard(
                requiredPlan: 'breakthrough',
                child: PromotionScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/promo/video',
            pageBuilder: (context, state) => _FadePage(
              child: const SubscriptionGuard(
                requiredPlan: 'breakthrough',
                child: PromoVideoScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/ai',
            pageBuilder: (context, state) => _FadePage(
              child: const SubscriptionGuard(
                requiredPlan: 'breakthrough',
                child: StudioHubScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/artist',
            pageBuilder: (context, state) => _FadePage(
              child: const SubscriptionGuard(
                requiredPlan: 'breakthrough',
                child: ArtistScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/finance',
            pageBuilder: (context, state) => _FadePage(child: const FinancesScreen()),
          ),
          GoRoute(
            path: '/team',
            pageBuilder: (context, state) => _FadePage(
              child: const SubscriptionGuard(
                requiredPlan: 'empire',
                child: TeamScreen(),
                lockedTitle: 'Команда и CRM доступны на Империи',
              ),
            ),
          ),
          GoRoute(
            path: '/production',
            pageBuilder: (context, state) => _FadePage(
              child: const SubscriptionGuard(
                requiredPlan: 'empire',
                child: ProductionPage(),
                lockedTitle: 'Продакшн доступен на Империи',
              ),
            ),
          ),
          GoRoute(
            path: '/subscription',
            pageBuilder: (context, state) => _FadePage(child: const SubscriptionRouteScreen()),
          ),
          GoRoute(
            path: '/credits',
            pageBuilder: (context, state) => _FadePage(child: const CreditsScreen()),
          ),
          GoRoute(
            path: '/achievements',
            pageBuilder: (context, state) => _FadePage(child: const AchievementsScreen()),
          ),
          GoRoute(
            path: '/goals',
            pageBuilder: (context, state) => _FadePage(child: const GoalsScreen()),
          ),
          GoRoute(
            path: '/public-profile',
            pageBuilder: (context, state) => _FadePage(child: const PublicProfileScreen()),
          ),
          GoRoute(
            path: '/services',
            pageBuilder: (context, state) => _FadePage(child: const ServicesScreen()),
          ),
          GoRoute(
            path: '/support',
            pageBuilder: (context, state) => _FadePage(child: const SupportScreen()),
          ),
          GoRoute(
            path: '/legal-tools',
            pageBuilder: (context, state) => _FadePage(child: const LegalListPage()),
          ),
          GoRoute(
            path: '/legal-tools/history',
            pageBuilder: (context, state) => _FadePage(child: const LegalHistoryPage()),
          ),
          GoRoute(
            path: '/legal-tools/:id',
            pageBuilder: (context, state) => _FadePage(child: LegalDetailPage(templateId: state.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) {
              final mandatory = state.uri.queryParameters['mandatory'] == '1';
              return _FadePage(child: ProfilePage(isMandatory: mandatory));
            },
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _FadePage(child: const SettingsScreen()),
          ),
          GoRoute(
            path: '/settings/account-deletion',
            pageBuilder: (context, state) => _FadePage(child: const AccountDeletionRequestPage()),
          ),
          GoRoute(
            path: '/index',
            pageBuilder: (context, state) => _FadePage(child: const IndexHomeScreen()),
          ),
          GoRoute(
            path: '/index/artist/:id',
            pageBuilder: (context, state) => _FadePage(
              child: ArtistIndexProfileScreen(artistId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/index/debug',
            pageBuilder: (context, state) => _FadePage(child: const IndexEngineDebugScreen()),
          ),
          GoRoute(
            path: '/dnk',
            pageBuilder: (context, state) => _FadePage(
              child: const SubscriptionGuard(
                requiredPlan: 'breakthrough',
                child: DnkTestsHubScreen(),
                lockedTitle: 'DNK Pro доступен с тарифа Прорыв',
              ),
            ),
          ),
          GoRoute(
            path: '/dnk/artist',
            pageBuilder: (context, state) => _FadePage(child: const AurixDnkScreen()),
          ),
          GoRoute(
            path: '/dnk/tests',
            pageBuilder: (context, state) => _FadePage(
              child: const SubscriptionGuard(
                requiredPlan: 'breakthrough',
                child: DnkTestsHubScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/dnk/tests/result/:id',
            pageBuilder: (context, state) => _FadePage(
              child: SubscriptionGuard(
                requiredPlan: 'breakthrough',
                child: DnkTestResultLoaderScreen(resultId: state.pathParameters['id']!),
              ),
            ),
          ),
          GoRoute(
            path: '/dnk/tests/:slug',
            pageBuilder: (context, state) => _FadePage(
              child: SubscriptionGuard(
                requiredPlan: 'breakthrough',
                child: DnkTestLaunchScreen(testSlug: state.pathParameters['slug']!),
              ),
            ),
          ),
          GoRoute(
            path: '/progress',
            pageBuilder: (context, state) => _FadePage(child: const ProgressHomeScreen()),
          ),
          GoRoute(
            path: '/progress/manage',
            pageBuilder: (context, state) {
              final openNew = state.uri.queryParameters['new'] == '1';
              return _FadePage(child: HabitManageScreen(openNewOnStart: openNew));
            },
          ),
          GoRoute(
            path: '/navigator',
            pageBuilder: (context, state) =>
                _FadePage(child: const NavigatorLandingScreen()),
          ),
          GoRoute(
            path: '/navigator/onboarding',
            pageBuilder: (context, state) =>
                _FadePage(child: const NavigatorOnboardingScreen()),
          ),
          GoRoute(
            path: '/navigator/ai-intake',
            pageBuilder: (context, state) =>
                _FadePage(child: const NavigatorAiIntakeScreen()),
          ),
          GoRoute(
            path: '/navigator/results',
            pageBuilder: (context, state) =>
                _FadePage(child: const NavigatorResultsScreen()),
          ),
          GoRoute(
            path: '/navigator/library',
            pageBuilder: (context, state) =>
                _FadePage(child: const NavigatorLibraryScreen()),
          ),
          GoRoute(
            path: '/navigator/saved',
            pageBuilder: (context, state) =>
                _FadePage(child: const NavigatorSavedScreen()),
          ),
          GoRoute(
            path: '/navigator/article/:slug',
            pageBuilder: (context, state) => _FadePage(
              child: NavigatorArticleScreen(
                slug: state.pathParameters['slug']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        redirect: (context, state) {
          final container = ProviderScope.containerOf(context);
          final role = container.read(authStoreProvider).role;
          if (role != 'admin') return '/home';
          return null;
        },
        pageBuilder: (context, state) {
          return NoTransitionPage(
            child: Consumer(builder: (context, ref, _) {
              final role = ref.watch(authStoreProvider).role;
              if (role != 'admin') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) context.go('/home');
                });
                return const SizedBox.shrink();
              }
              final tab = state.uri.queryParameters['tab'];
              final userKey = ref.watch(authStoreProvider).userId ?? 'anon';
              return ProviderScope(
                key: ValueKey('admin:$userKey'),
                child: AdminPanel(initialTab: tab),
              );
            }),
          );
        },
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
      onViewDemo: () => context.push('/releases'),
      onCreateRelease: () => context.push('/releases/create'),
      onViewReleases: () => context.push('/releases'),
      onViewSubscription: () => context.push('/subscription'),
      onViewIndex: () => context.push('/index'),
      onOpenStudioAi: () => context.push('/ai'),
      onOpenPromotion: () => context.push('/promo'),
      onOpenAnalytics: () => context.push('/stats'),
      onOpenFinances: () => context.push('/finance'),
      onOpenTeam: () => context.push('/team'),
      onOpenLegal: () => context.push('/legal-tools'),
      onOpenReleaseDetails: (id) => context.push('/releases/$id'),
      onOpenAchievements: () => context.push('/achievements'),
      onOpenGoals: () => context.push('/goals'),
    );
  }
}
