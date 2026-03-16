import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/app_back_button.dart';

bool _isValidPhone(String s) {
  final cleaned = s.replaceAll(RegExp(r'\s'), '');
  if (cleaned.length < 8) return false;
  return RegExp(r'^\+[0-9]+$').hasMatch(cleaned);
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;
  bool _acceptLegal = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final password = _passwordController.text;
      final confirm = _confirmController.text;
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        setState(() {
          _error = 'Заполните все поля';
          _loading = false;
        });
        return;
      }
      if (!_isValidPhone(phone)) {
        setState(() {
          _error = 'Телефон: минимум 8 символов, формат +7... или +374...';
          _loading = false;
        });
        return;
      }
      if (password.length < 8) {
        setState(() {
          _error = 'Пароль не менее 8 символов';
          _loading = false;
        });
        return;
      }
      if (password != confirm) {
        setState(() {
          _error = 'Пароли не совпадают';
          _loading = false;
        });
        return;
      }
      if (!_acceptLegal) {
        setState(() {
          _error = 'Подтвердите согласие с юридическими документами';
          _loading = false;
        });
        return;
      }
      await ref.read(authRepositoryProvider).signUp(email: email, password: password, phone: phone, name: name);
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Письмо отправлено! Проверьте почту для подтверждения.'),
            duration: Duration(seconds: 5),
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('уже используется') || msg.contains('already registered')) {
        setState(() {
          _error = 'Этот email уже зарегистрирован';
          _loading = false;
        });
        return;
      }
      setState(() {
        _error = 'Нет связи с сервером. Проверьте интернет.';
        _loading = false;
      });
    }
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppBackButton(onPressed: _goBack),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Регистрация', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Создайте аккаунт артиста', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AurixTokens.muted)),
                          const SizedBox(height: 32),
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _nameController,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(labelText: 'Имя и фамилия'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите имя' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'Email'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите email' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Телефон', hintText: '+7... или +374...'),
                            validator: (v) => (v == null || !_isValidPhone(v.trim())) ? 'Минимум 8 символов, только + и цифры' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Пароль (не менее 8 символов)',
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 8) ? 'Минимум 8 символов' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'Повторите пароль',
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            validator: (v) => v != _passwordController.text ? 'Пароли не совпадают' : null,
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: _acceptLegal,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) => setState(() => _acceptLegal = v ?? false),
                            title: Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: [
                                const Text('Я принимаю'),
                                InkWell(
                                  onTap: () => context.push('/legal/terms'),
                                  child: const Text('Пользовательское соглашение', style: TextStyle(decoration: TextDecoration.underline)),
                                ),
                                const Text('и'),
                                InkWell(
                                  onTap: () => context.push('/legal/privacy'),
                                  child: const Text('Политику конфиденциальности', style: TextStyle(decoration: TextDecoration.underline)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    if (_formKey.currentState?.validate() ?? false) _submit();
                                  },
                            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Зарегистрироваться'),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Уже есть аккаунт? Войти'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
