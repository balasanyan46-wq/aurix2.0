import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/app_config.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/repositories/legal_compliance_repository.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/app/auth/auth_store_provider.dart';
import 'package:aurix_flutter/design/widgets/section_onboarding.dart';

final _latestAccountDeletionStatusProvider =
    FutureProvider<String?>((ref) async {
  return ref.watch(accountDeletionRequestRepositoryProvider).latestStatus();
});

final _cookieConsentStateProvider =
    FutureProvider<CookieConsentState>((ref) async {
  return ref
      .watch(legalComplianceRepositoryProvider)
      .loadOrCreateCookieChoices();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _logoTapCount = 0;
  bool _devSettingsOpen = false;
  bool _analyticsAllowed = true;
  bool _marketingAllowed = false;
  bool _privacySaving = false;
  bool _cookieStateInitialized = false;

  void _onLogoTap() {
    if (!false) return;
    setState(() {
      _logoTapCount++;
      if (_logoTapCount >= 7) {
        _devSettingsOpen = true;
        _logoTapCount = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = horizontalPadding(context);
    final deletionStatusAsync = ref.watch(_latestAccountDeletionStatusProvider);
    final cookieConsentState = ref.watch(_cookieConsentStateProvider);

    cookieConsentState.whenData((state) {
      if (_cookieStateInitialized) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _cookieStateInitialized) return;
        setState(() {
          _analyticsAllowed = state.analyticsAllowed;
          _marketingAllowed = state.marketingAllowed;
          _cookieStateInitialized = true;
        });
      });
    });

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionOnboarding(tip: OnboardingTips.settings),
              // Page header
              FadeInSlide(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Text(
                    L10n.t(context, 'settings'),
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),

              // Profile section
              FadeInSlide(
                delayMs: 50,
                child: PremiumSectionCard(
                  padding: const EdgeInsets.all(20),
                  child: AppConfig.isConfigured
                      ? _ProfileSection()
                      : _ProfilePlaceholder(),
                ),
              ),
              const SizedBox(height: 16),

              // Legal & Privacy section
              FadeInSlide(
                delayMs: 100,
                child: PremiumSectionCard(
                  padding: const EdgeInsets.all(20),
                  child: _buildLegalSection(
                    context,
                    cookieConsentState,
                    deletionStatusAsync,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // About section
              FadeInSlide(
                delayMs: 150,
                child: PremiumSectionCard(
                  padding: const EdgeInsets.all(20),
                  child: _buildAboutSection(context),
                ),
              ),

              // Developer settings
              if (false && _devSettingsOpen) ...[
                const SizedBox(height: 16),
                FadeInSlide(
                  child: _DeveloperSettingsPanel(
                    onClose: () => setState(() => _devSettingsOpen = false),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalSection(
    BuildContext context,
    AsyncValue<CookieConsentState> cookieConsentState,
    AsyncValue<String?> deletionStatusAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AurixTokens.aiAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, size: 18, color: AurixTokens.aiAccent),
            ),
            const SizedBox(width: 12),
            const Text(
              'Конфиденциальность',
              style: TextStyle(
                color: AurixTokens.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _linkChip(context, 'Политика конфиденциальности', '/legal/privacy'),
            _linkChip(context, 'Пользовательское соглашение', '/legal/terms'),
            _linkChip(context, 'Управление конфиденциальностью', '/legal/privacy-choices'),
            _linkChip(context, 'Удаление данных', '/legal/data-deletion'),
            _linkChip(context, 'Возвраты и возмещение', '/legal/refunds'),
          ],
        ),
        const SizedBox(height: 20),
        _buildToggle(
          value: _analyticsAllowed,
          label: 'Аналитические cookies/SDK',
          enabled: !cookieConsentState.isLoading,
          onChanged: (v) => setState(() => _analyticsAllowed = v),
        ),
        const SizedBox(height: 8),
        _buildToggle(
          value: _marketingAllowed,
          label: 'Маркетинговые cookies/SDK',
          enabled: !cookieConsentState.isLoading,
          onChanged: (v) => setState(() => _marketingAllowed = v),
        ),
        if (cookieConsentState.isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AurixTokens.muted.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Загружаем настройки…',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        PremiumHoverLift(
          child: FilledButton.icon(
            onPressed: _privacySaving || cookieConsentState.isLoading
                ? null
                : () async {
                    setState(() => _privacySaving = true);
                    try {
                      await ref
                          .read(legalComplianceRepositoryProvider)
                          .upsertCookieChoices(
                            analyticsAllowed: _analyticsAllowed,
                            marketingAllowed: _marketingAllowed,
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Privacy choices сохранены'),
                          backgroundColor: AurixTokens.bg2,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      ref.invalidate(_cookieConsentStateProvider);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Не удалось сохранить: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _privacySaving = false);
                    }
                  },
            icon: Icon(
              _privacySaving ? Icons.hourglass_empty_rounded : Icons.check_rounded,
              size: 16,
            ),
            label: Text(_privacySaving ? 'Сохраняем…' : 'Сохранить'),
          ),
        ),
        const SizedBox(height: 20),
        Divider(color: AurixTokens.stroke(0.12), height: 1),
        const SizedBox(height: 16),
        PremiumHoverLift(
          child: OutlinedButton.icon(
            onPressed: () async {
              await context.push('/settings/account-deletion');
              ref.invalidate(_latestAccountDeletionStatusProvider);
            },
            icon: const Icon(Icons.delete_forever_outlined, size: 16),
            style: OutlinedButton.styleFrom(
              foregroundColor: AurixTokens.danger,
              side: BorderSide(color: AurixTokens.danger.withValues(alpha: 0.3)),
            ),
            label: const Text('Запросить удаление аккаунта'),
          ),
        ),
        const SizedBox(height: 8),
        deletionStatusAsync.when(
          data: (status) => Text(
            status == null
                ? 'Запрос на удаление пока не отправлялся'
                : 'Статус запроса: $status',
            style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
          ),
          loading: () => Row(
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AurixTokens.muted.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Загружаем статус…',
                style: TextStyle(color: AurixTokens.muted, fontSize: 12),
              ),
            ],
          ),
          error: (_, __) => Text(
            'Не удалось загрузить статус',
            style: TextStyle(color: AurixTokens.danger.withValues(alpha: 0.7), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required bool value,
    required String label,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AurixTokens.text, fontSize: 14),
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: AurixTokens.accent,
            activeTrackColor: AurixTokens.accent.withValues(alpha: 0.3),
            inactiveTrackColor: AurixTokens.bg2,
            inactiveThumbColor: AurixTokens.muted,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AurixTokens.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, size: 18, color: AurixTokens.accent),
            ),
            const SizedBox(width: 12),
            Text(
              L10n.t(context, 'about'),
              style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _onLogoTap,
          child: const Text(
            'AURIX',
            style: TextStyle(
              color: AurixTokens.accentWarm,
              letterSpacing: 6,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Версия 1.0.0 (Design)',
          style: TextStyle(color: AurixTokens.muted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _linkChip(BuildContext context, String label, String path) {
    return GestureDetector(
      onTap: () => context.push(path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AurixTokens.bg2.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
          border: Border.all(color: AurixTokens.stroke(0.18)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AurixTokens.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DeveloperSettingsPanel extends ConsumerWidget {
  final VoidCallback onClose;

  const _DeveloperSettingsPanel({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    return PremiumSectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AurixTokens.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.developer_mode_rounded, size: 18, color: AurixTokens.accent),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    L10n.t(context, 'developerSettings'),
                    style: const TextStyle(
                      color: AurixTokens.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClose,
                color: AurixTokens.muted,
                style: IconButton.styleFrom(
                  backgroundColor: AurixTokens.glass(0.06),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Role (dev only)',
            style: TextStyle(color: AurixTokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RoleChip(
                label: 'Artist',
                selected: appState.currentUserRole == UserRole.artist,
                onTap: () => appState.setRole(UserRole.artist),
              ),
              const SizedBox(width: 10),
              _RoleChip(
                label: 'Admin',
                selected: appState.currentUserRole == UserRole.admin,
                onTap: () => appState.setRole(UserRole.admin),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final user = ref.watch(currentUserProvider);
    final email = profile.valueOrNull?.email ?? user?.email ?? '—';
    final authEmail = user?.email;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AurixTokens.accent.withValues(alpha: 0.2),
                    AurixTokens.aiAccent.withValues(alpha: 0.15),
                  ],
                ),
                border: Border.all(color: AurixTokens.stroke(0.24)),
              ),
              child: const Icon(Icons.person_rounded, color: AurixTokens.text, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Аккаунт',
                    style: TextStyle(
                      color: AurixTokens.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.isLoading ? '…' : email,
                    style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SettingsAction(
                icon: Icons.person_rounded,
                label: 'Профиль',
                onTap: () => ref.read(appStateProvider).navigateTo(AppScreen.profile),
              ),
            ),
            const SizedBox(width: 8),
            if (authEmail != null && authEmail.isNotEmpty)
              Expanded(
                child: _SettingsAction(
                  icon: Icons.lock_reset_rounded,
                  label: 'Сбросить пароль',
                  onTap: () async {
                    try {
                      await ref.read(authRepositoryProvider).resetPasswordForEmail(authEmail);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ссылка отправлена на $authEmail'),
                            backgroundColor: AurixTokens.bg2,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Не удалось отправить письмо')),
                        );
                      }
                    }
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _SettingsAction(
            icon: Icons.logout_rounded,
            label: 'Выйти из аккаунта',
            danger: true,
            onTap: () async {
              await ref.read(authStoreProvider).signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ),
      ],
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AurixTokens.bg2,
            border: Border.all(color: AurixTokens.stroke(0.2)),
          ),
          child: const Icon(Icons.person_rounded, color: AurixTokens.muted, size: 22),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Профиль', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600)),
            SizedBox(height: 2),
            Text('artist@example.com', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
          ],
        ),
      ],
    );
  }
}

class _SettingsAction extends StatefulWidget {
  const _SettingsAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_SettingsAction> createState() => _SettingsActionState();
}

class _SettingsActionState extends State<_SettingsAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.danger ? AurixTokens.danger : AurixTokens.accent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: _hovered ? color.withValues(alpha: 0.08) : AurixTokens.glass(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? color.withValues(alpha: 0.2) : AurixTokens.stroke(0.12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 16, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AurixTokens.accent.withValues(alpha: 0.18)
              : AurixTokens.glass(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AurixTokens.accent.withValues(alpha: 0.4) : AurixTokens.stroke(0.14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AurixTokens.accent : AurixTokens.muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
