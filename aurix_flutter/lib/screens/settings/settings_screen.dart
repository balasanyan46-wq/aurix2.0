import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/app_config.dart';
import 'package:aurix_flutter/config/app_mode.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

/// Настройки — без mock/dev индикаторов. About с 7 кликами по логотипу → Developer Settings.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _logoTapCount = 0;
  bool _devSettingsOpen = false;

  void _onLogoTap() {
    if (!kDevMode) return;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(L10n.t(context, 'settings'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 32),
              AurixGlassCard(
                padding: const EdgeInsets.all(24),
                child: AppConfig.isConfigured
                    ? _ProfileFromSupabase()
                    : _ProfilePlaceholder(),
              ),
              const SizedBox(height: 24),
              AurixGlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L10n.t(context, 'about'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _onLogoTap,
                      child: Text(
                        'AURIX',
                        style: TextStyle(
                          color: AurixTokens.orange,
                          letterSpacing: 6,
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Версия 1.0.0 (Design)',
                        style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                  ],
                ),
              ),
              if (kDevMode && _devSettingsOpen) ...[
                const SizedBox(height: 24),
                _DeveloperSettingsPanel(
                  onClose: () => setState(() => _devSettingsOpen = false),
                ),
              ],
            ],
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

    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(L10n.t(context, 'developerSettings'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: AurixTokens.orange)),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClose,
                color: AurixTokens.muted,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Role (dev only)', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              _RoleChip(
                label: 'Artist',
                selected: appState.currentUserRole == UserRole.artist,
                onTap: () => appState.setRole(UserRole.artist),
              ),
              const SizedBox(width: 12),
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

class _ProfileFromSupabase extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final user = ref.watch(currentUserProvider);
    final email = profile.valueOrNull?.email ?? user?.email ?? '—';
    final authEmail = user?.email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Профиль',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _ProfileRow(email: profile.isLoading ? '…' : email),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => ref.read(appStateProvider).navigateTo(AppScreen.profile),
          icon: Icon(Icons.person_rounded, size: 18, color: AurixTokens.orange),
          label: Text('Редактировать профиль', style: TextStyle(color: AurixTokens.orange)),
        ),
        const SizedBox(height: 16),
        if (authEmail != null && authEmail.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              try {
                await ref.read(authRepositoryProvider).resetPasswordForEmail(authEmail);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ссылка для сброса пароля отправлена на $authEmail')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Не удалось отправить письмо. Проверьте email.')),
                  );
                }
              }
            },
            icon: Icon(Icons.lock_reset, size: 18, color: AurixTokens.orange),
            label: Text('Сбросить пароль', style: TextStyle(color: AurixTokens.orange)),
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            await ref.read(authRepositoryProvider).signOut();
          },
          icon: Icon(Icons.logout, size: 18, color: AurixTokens.orange),
          label: Text('Выйти', style: TextStyle(color: AurixTokens.orange)),
        ),
      ],
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Профиль',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _ProfileRow(email: 'artist@example.com'),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String email;

  const _ProfileRow({required this.email});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AurixTokens.orange.withValues(alpha: 0.3),
            border: Border.all(color: AurixTokens.stroke(0.2)),
          ),
          child: const Icon(Icons.person, color: AurixTokens.text, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Аккаунт',
                style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600)),
            Text(email, style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
          ],
        ),
      ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AurixTokens.orange.withValues(alpha: 0.25) : AurixTokens.glass(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AurixTokens.orange : AurixTokens.stroke(0.15),
          ),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? AurixTokens.orange : AurixTokens.muted,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        )),
      ),
    );
  }
}
