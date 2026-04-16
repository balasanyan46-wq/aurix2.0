import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/config/app_config.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/data/providers/growth_providers.dart';
import 'package:aurix_flutter/design/widgets/section_onboarding.dart';

class PublicProfileScreen extends ConsumerStatefulWidget {
  const PublicProfileScreen({super.key});

  @override
  ConsumerState<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  final _slugCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _genreCtrl = TextEditingController();
  bool _isPublic = false;
  bool _saving = false;
  bool _loaded = false;

  void _refresh() {
    ref.invalidate(myPublicProfileProvider);
  }

  void _loadProfile(Map<String, dynamic>? profile) {
    if (_loaded || profile == null) return;
    _loaded = true;
    _slugCtrl.text = profile['slug'] ?? '';
    _nameCtrl.text = profile['display_name'] ?? '';
    _bioCtrl.text = profile['bio'] ?? '';
    _genreCtrl.text = profile['genre'] ?? '';
    _isPublic = profile['is_public'] == true;
  }

  Future<void> _save() async {
    if (_slugCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slug обязателен'), backgroundColor: AurixTokens.danger, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiClient.post('/growth/public-profile', data: {
        'slug': _slugCtrl.text.trim(),
        'display_name': _nameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'genre': _genreCtrl.text.trim(),
        'is_public': _isPublic,
      });
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль сохранён'), backgroundColor: AurixTokens.positive, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _copyLink() {
    final slug = _slugCtrl.text.trim();
    if (slug.isEmpty) return;
    final url = '${AppConfig.apiBaseUrl}/p/$slug';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ссылка скопирована: $url'), backgroundColor: AurixTokens.positive, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _slugCtrl.dispose();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _genreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myPublicProfileProvider);

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('ПУБЛИЧНЫЙ ПРОФИЛЬ', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.8)),
        actions: [
          if (_isPublic && _slugCtrl.text.trim().isNotEmpty)
            IconButton(
              icon: const Icon(Icons.link_rounded, color: AurixTokens.accentWarm),
              onPressed: _copyLink,
              tooltip: 'Копировать ссылку',
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
        error: (e, _) => PremiumErrorState(message: 'Ошибка: $e'),
        data: (profile) {
          if (profile != null && !_loaded) _loadProfile(profile);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionOnboarding(tip: OnboardingTips.publicProfile),
                // Public toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (_isPublic ? AurixTokens.positive : AurixTokens.muted).withValues(alpha: 0.1),
                        AurixTokens.glass(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AurixTokens.stroke(0.16)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isPublic ? Icons.public_rounded : Icons.public_off_rounded,
                        color: _isPublic ? AurixTokens.positive : AurixTokens.muted,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPublic ? 'Профиль публичный' : 'Профиль скрыт',
                              style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            Text(
                              _isPublic ? 'Любой может увидеть ваш профиль по ссылке' : 'Включите, чтобы делиться профилем',
                              style: const TextStyle(color: AurixTokens.muted, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPublic,
                        activeColor: AurixTokens.positive,
                        onChanged: (v) => setState(() => _isPublic = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Fields
                TextField(
                  controller: _slugCtrl,
                  style: const TextStyle(color: AurixTokens.text),
                  decoration: const InputDecoration(
                    labelText: 'Slug (URL)',
                    hintText: 'my-artist-name',
                    prefixText: '/p/',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AurixTokens.text),
                  decoration: const InputDecoration(labelText: 'Имя артиста'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _genreCtrl,
                  style: const TextStyle(color: AurixTokens.text),
                  decoration: const InputDecoration(labelText: 'Жанр'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _bioCtrl,
                  style: const TextStyle(color: AurixTokens.text),
                  decoration: const InputDecoration(labelText: 'О себе'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Stats (if existing profile)
                if (profile != null) ...[
                  Row(
                    children: [
                      _StatChip(icon: Icons.visibility_rounded, label: '${profile['views'] ?? 0} просмотров'),
                      const SizedBox(width: 10),
                      _StatChip(icon: Icons.calendar_today_rounded, label: 'Создан'),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.text))
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Сохранение...' : 'Сохранить профиль'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AurixTokens.muted),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
