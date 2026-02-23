import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _error = 'Введите email и пароль';
          _loading = false;
        });
        return;
      }
      await ref.read(authRepositoryProvider).signIn(email: email, password: password);
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      String msg = 'Ошибка входа';
      if (e.message.contains('Invalid login')) {
        msg = 'Неверный email или пароль';
      } else if (e.message.contains('Email not confirmed')) {
        msg = 'Подтвердите email по ссылке из письма';
      }
      setState(() {
        _error = msg;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Нет связи с сервером. Проверьте интернет.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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
                          Text('Aurix', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Вход в личный кабинет', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
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
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'Email'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите email' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Пароль',
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Введите пароль' : null,
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _loading ? null : () {
                              if (_formKey.currentState?.validate() ?? false) _submit();
                            },
                            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Войти'),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => context.push('/register'),
                            child: const Text('Нет аккаунта? Зарегистрироваться'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'AURIX',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      TextSpan(
                        text: ' • by Armen Balasanyan',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
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
