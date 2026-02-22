import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _artistNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _initialFillDone = false;

  @override
  void dispose() {
    _artistNameController.dispose();
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _fillFromProfile(dynamic profile) {
    if (profile == null) return;
    _artistNameController.text = profile.artistName ?? '';
    _displayNameController.text = profile.displayName ?? '';
    _phoneController.text = profile.phone ?? '';
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            userId,
            artistName: _artistNameController.text.trim().isEmpty ? null : _artistNameController.text.trim(),
            displayName: _displayNameController.text.trim().isEmpty ? null : _displayNameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Профиль сохранён')));
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() {
        _error = 'Не удалось сохранить. Проверьте интернет.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentProfileProvider);
    ref.listen<AsyncValue<ProfileModel?>>(currentProfileProvider, (prev, next) {
      next.whenData((p) {
        if (!_initialFillDone) {
          _fillFromProfile(p);
          _initialFillDone = true;
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())),
      body: SingleChildScrollView(
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
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _artistNameController,
                    decoration: const InputDecoration(labelText: 'Имя артиста / псевдоним'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(labelText: 'Отображаемое имя'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Телефон (необязательно)'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _save,
                    child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Сохранить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
