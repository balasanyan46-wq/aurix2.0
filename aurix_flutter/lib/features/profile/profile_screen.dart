import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/core/api/api_error.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/app/auth/auth_store_provider.dart';

/// Профиль в shell. Редактирование name, city, phone, gender, bio.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _initialFillDone = false;
  String? _gender;

  static const _genders = [
    (value: null, label: 'Не выбрано'),
    (value: 'male', label: 'Мужской'),
    (value: 'female', label: 'Женский'),
    (value: 'other', label: 'Другое'),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _fillFromProfile(ProfileModel? profile) {
    if (profile == null) return;
    _nameController.text = profile.name ?? profile.displayName ?? profile.artistName ?? '';
    _cityController.text = profile.city ?? '';
    _phoneController.text = profile.phone ?? '';
    _bioController.text = profile.bio ?? '';
    _gender = profile.gender;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[^\d+\s\-]'), '');
    if (cleaned.length < 7) return 'Минимум 7 символов';
    return null;
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) _snack('Войдите в аккаунт');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final repo = ref.read(profileRepositoryProvider);
      final current = await repo.getMyProfile();
      final profile = (current ?? ProfileModel(userId: user.id, createdAt: DateTime.now(), updatedAt: DateTime.now(), email: user.email ?? ''))
          .copyWith(
            name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
            city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
            gender: _gender,
            bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
          );
      await repo.upsertMyProfile(profile);
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        _snack('Сохранено');
        setState(() => _loading = false);
      }
    } catch (e) {
      final msg = formatApiError(e);
      setState(() {
        _error = msg;
        _loading = false;
      });
      if (mounted) _snack('Ошибка: $msg');
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: AurixTokens.bg2,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: FadeInSlide(
            child: PremiumSectionCard(
              radius: AurixTokens.radiusHero,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AurixTokens.muted.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_off_rounded, size: 40, color: AurixTokens.muted),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Войдите в аккаунт',
                    style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  AurixButton(text: 'Войти', onPressed: () => context.go('/login')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    ref.listen<AsyncValue<ProfileModel?>>(currentProfileProvider, (prev, next) {
      next.whenData((p) {
        if (!_initialFillDone && p != null) {
          _fillFromProfile(p);
          _initialFillDone = true;
          setState(() {});
        }
      });
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: profileAsync.when(
        data: (_) => PremiumPageScaffold(
          title: 'Профиль',
          subtitle: 'Основная информация',
          maxWidth: 560,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ref.watch(isAdminProvider).valueOrNull == true)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings_rounded, color: AurixTokens.muted, size: 20),
                  onPressed: () => context.push('/admin?tab=releases'),
                  tooltip: 'Админ',
                  style: IconButton.styleFrom(
                    backgroundColor: AurixTokens.glass(0.06),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AurixTokens.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AurixTokens.danger.withValues(alpha: 0.7)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_error!, style: TextStyle(color: AurixTokens.danger.withValues(alpha: 0.9), fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            PremiumSectionCard(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Имя', style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: AurixTokens.text, fontSize: 15),
                      decoration: const InputDecoration(hintText: 'Ваше имя'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Город', style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _cityController,
                      style: const TextStyle(color: AurixTokens.text, fontSize: 15),
                      decoration: const InputDecoration(hintText: 'Город'),
                    ),
                    const SizedBox(height: 16),
                    const Text('Телефон', style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AurixTokens.text, fontSize: 15),
                      decoration: const InputDecoration(hintText: '+7 999 123-45-67'),
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),
                    const Text('Пол', style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: _gender,
                      decoration: const InputDecoration(),
                      dropdownColor: AurixTokens.bg2,
                      style: const TextStyle(color: AurixTokens.text, fontSize: 15),
                      items: _genders.map((g) => DropdownMenuItem(
                        value: g.value,
                        child: Text(g.label, style: const TextStyle(color: AurixTokens.text)),
                      )).toList(),
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 16),
                    const Text('О себе', style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      style: const TextStyle(color: AurixTokens.text, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Краткое описание',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    PremiumHoverLift(
                      child: AurixButton(
                        text: _loading ? 'Сохранение…' : 'Сохранить',
                        onPressed: _loading ? null : _save,
                        icon: _loading ? null : Icons.check_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PremiumHoverLift(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(authStoreProvider).signOut();
                          if (context.mounted) context.go('/');
                        },
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text('Выйти'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AurixTokens.muted,
                          side: BorderSide(color: AurixTokens.stroke(0.2)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const PremiumLoadingState(message: 'Загрузка профиля…'),
        error: (e, _) => PremiumErrorState(
          title: 'Ошибка загрузки',
          message: '$e',
          onRetry: () => ref.invalidate(currentProfileProvider),
        ),
      ),
    );
  }
}
