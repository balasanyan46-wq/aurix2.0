import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart' show currentProfileProvider, currentUserProvider, authRepositoryProvider;

/// Full profile form with AURIX theme. Optional [isMandatory] blocks back navigation.
/// [onBack] for DesignShell (no GoRouter); when null, uses context.pop().
/// [onViewIndex] for navigation to Aurix Index; when null, uses context.go('/index').
class ProfilePage extends ConsumerStatefulWidget {
  final bool isMandatory;
  final VoidCallback? onBack;
  final VoidCallback? onViewIndex;

  const ProfilePage({super.key, this.isMandatory = false, this.onBack, this.onViewIndex});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  bool _loading = false;
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
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _fillFromProfile(ProfileModel? profile) {
    if (profile == null || _initialFillDone) return;
    _initialFillDone = true;
    _nameController.text = profile.name ?? profile.displayName ?? profile.artistName ?? '';
    _cityController.text = profile.city ?? '';
    _phoneController.text = profile.phone ?? '';
    _bioController.text = profile.bio ?? '';
    _avatarUrlController.text = profile.avatarUrl ?? '';
    _gender = profile.gender;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Укажите имя или псевдоним';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[^\d+\s\-]'), '');
    if (cleaned.length < 7) return 'Минимум 7 цифр';
    return null;
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) _showSnack('Войдите в аккаунт');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final current = await repo.getMyProfile();
      final profile = (current ??
              ProfileModel(
                userId: user.id,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                email: user.email ?? '',
              ))
          .copyWith(
        name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        gender: _gender,
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        avatarUrl: _avatarUrlController.text.trim().isEmpty ? null : _avatarUrlController.text.trim(),
      );
      await repo.upsertMyProfile(profile);
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        _showSnack('Сохранено');
        setState(() => _loading = false);
        if (widget.isMandatory) context.go('/home');
      }
    } catch (e) {
      final msg = formatSupabaseError(e);
      setState(() => _loading = false);
      if (mounted) _showSnack('Ошибка: $msg');
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: AurixTokens.bg2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final padding = horizontalPadding(context);

    ref.listen(currentProfileProvider, (prev, next) {
      next.whenData((p) => _fillFromProfile(p));
    });

    if (user == null) {
      return _buildCentered(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off, size: 64, color: AurixTokens.muted),
            const SizedBox(height: 16),
            Text('Войдите в аккаунт', style: TextStyle(color: AurixTokens.text, fontSize: 16)),
            const SizedBox(height: 24),
            AurixButton(text: 'Войти', onPressed: () => context.go('/login')),
          ],
        ),
      );
    }

    return PopScope(
      canPop: !widget.isMandatory,
      child: SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: profileAsync.when(
            data: (_) => Form(
              key: _formKey,
              child: AurixGlassCard(
                padding: EdgeInsets.all(isDesktop ? 32 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (!widget.isMandatory)
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
                            onPressed: () {
                              if (widget.onBack != null) {
                                widget.onBack!();
                              } else {
                                context.pop();
                              }
                            },
                          ),
                        Expanded(
                          child: Text(
                            widget.isMandatory ? 'Заполните профиль' : 'Профиль',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: AurixTokens.text,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.isMandatory)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: Text(
                          'Для продолжения укажите имя или псевдоним',
                          style: TextStyle(color: AurixTokens.muted, fontSize: 14),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _buildField(
                      controller: _nameController,
                      label: 'Имя / псевдоним',
                      hint: 'Обязательно',
                      validator: _validateName,
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _cityController,
                      label: 'Город',
                      hint: '',
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _phoneController,
                      label: 'Телефон',
                      hint: '+7 999 123-45-67',
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),
                    _buildGenderDropdown(),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _bioController,
                      label: 'О себе',
                      hint: 'Краткое описание',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _avatarUrlController,
                      label: 'Ссылка на аватар',
                      hint: 'https://...',
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 52,
                      child: AurixButton(
                        text: _loading ? 'Сохранение…' : 'Сохранить',
                        onPressed: _loading ? null : _save,
                        icon: _loading ? null : Icons.check_rounded,
                      ),
                    ),
                    if (!widget.isMandatory) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: widget.onViewIndex ?? () => context.go('/index'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AurixTokens.orange,
                          side: BorderSide(color: AurixTokens.orange.withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.leaderboard_rounded, size: 18),
                        label: const Text('View Aurix Index'),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(authRepositoryProvider).signOut();
                          if (context.mounted) context.go('/login');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AurixTokens.orange,
                          side: BorderSide(color: AurixTokens.orange.withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Выйти'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            loading: () => _buildCentered(child: const CircularProgressIndicator(color: AurixTokens.orange)),
            error: (e, _) => _buildCentered(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ошибка: $e', style: TextStyle(color: AurixTokens.muted), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  AurixButton(text: 'Повторить', onPressed: () => ref.invalidate(currentProfileProvider)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildCentered({required Widget child}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: child,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String hint = '',
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool autofocus = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      autofocus: autofocus,
      validator: validator,
      style: const TextStyle(color: AurixTokens.text, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint.isNotEmpty ? hint : null,
        labelStyle: TextStyle(color: AurixTokens.muted),
        hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.7)),
        filled: true,
        fillColor: AurixTokens.glass(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AurixTokens.stroke()),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AurixTokens.stroke(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AurixTokens.orange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String?>(
      value: _gender,
      decoration: InputDecoration(
        labelText: 'Пол',
        labelStyle: TextStyle(color: AurixTokens.muted),
        filled: true,
        fillColor: AurixTokens.glass(0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AurixTokens.stroke()),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AurixTokens.stroke(0.15)),
        ),
      ),
      dropdownColor: AurixTokens.bg2,
      items: _genders.map((g) => DropdownMenuItem(value: g.value, child: Text(g.label, style: const TextStyle(color: AurixTokens.text)))).toList(),
      onChanged: (v) => setState(() => _gender = v),
    );
  }
}
