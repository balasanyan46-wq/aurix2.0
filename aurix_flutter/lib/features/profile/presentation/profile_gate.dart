import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

/// Redirects to /profile?mandatory=1 when user has no profile or empty name.
/// Then redirects to /onboarding when AI profile is empty.
class ProfileGate extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const ProfileGate({super.key, required this.child, required this.location});

  @override
  ConsumerState<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends ConsumerState<ProfileGate> {
  bool _redirected = false;
  bool _onboardingChecked = false;

  Future<void> _checkAiProfile() async {
    try {
      final res = await ApiClient.get('/api/ai/profile');
      final data = res.data;
      // If backend has a profile with a name, onboarding is done
      if (data is Map && (data['name'] ?? '').toString().trim().isNotEmpty) {
        return; // Already onboarded
      }
      // No AI profile — show onboarding
      if (mounted) context.go('/onboarding');
    } catch (_) {
      // API error — don't block, skip onboarding
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return widget.child;

    final isProfileRoute = widget.location.startsWith('/profile');
    final isAuthRoute = widget.location == '/login' || widget.location == '/register';
    final isOnboarding = widget.location == '/onboarding';
    if (isProfileRoute || isAuthRoute || isOnboarding) return widget.child;

    final needsFill = ref.watch(profileNeedsFillProvider);
    return needsFill.when(
      data: (needs) {
        if (needs == true && !_redirected) {
          _redirected = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/profile?mandatory=1');
          });
          return widget.child;
        }

        // After basic profile is filled, check AI profile onboarding (once)
        if (!needs && !_onboardingChecked && widget.location == '/home') {
          _onboardingChecked = true;
          _checkAiProfile();
        }

        // After profile + onboarding, redirect to subscription if no plan
        if (!needs && widget.location == '/home') {
          final profile = ref.read(currentProfileProvider).valueOrNull;
          if (profile != null &&
              (profile.plan == 'none' || profile.plan.isEmpty) &&
              (profile.subscriptionStatus == 'none' || profile.subscriptionStatus.isEmpty)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/subscription');
            });
          }
        }

        return widget.child;
      },
      loading: () => widget.child,
      error: (_, __) => widget.child,
    );
  }
}

final profileNeedsFillProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  final profileAsync = ref.watch(currentProfileProvider);
  final profile = profileAsync.valueOrNull;
  if (profile == null) {
    final repo = ref.read(profileRepositoryProvider);
    final fetched = await repo.ensureProfile();
    if (fetched == null) return true;
    final hasName = (fetched.artistName?.trim().isNotEmpty ?? false) ||
        (fetched.name?.trim().isNotEmpty ?? false) ||
        (fetched.displayName?.trim().isNotEmpty ?? false);
    return !hasName;
  }
  final hasName = (profile.artistName?.trim().isNotEmpty ?? false) ||
      (profile.name?.trim().isNotEmpty ?? false) ||
      (profile.displayName?.trim().isNotEmpty ?? false);
  return !hasName;
});
