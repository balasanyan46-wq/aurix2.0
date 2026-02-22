import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено')));
        setState(() => _loading = false);
      }
    } catch (e) {
      final msg = formatSupabaseError(e);
      setState(() {
        _error = msg;
        _loading = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $msg')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Профиль')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                const Text('Войдите в аккаунт'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Войти'),
                ),
              ],
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
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          if (ref.watch(isAdminProvider).valueOrNull == true)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => context.push('/admin/releases'),
              tooltip: 'Админ',
            ),
        ],
      ),
      body: profileAsync.when(
        data: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Имя'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'Город'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Телефон',
                        hintText: '+7 999 123-45-67',
                      ),
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: 'Пол'),
                      items: _genders.map((g) => DropdownMenuItem(value: g.value, child: Text(g.label))).toList(),
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'О себе',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Сохранить'),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Выйти'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ошибка: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(currentProfileProvider),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
