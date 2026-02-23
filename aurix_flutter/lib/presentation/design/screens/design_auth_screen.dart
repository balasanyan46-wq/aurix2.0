import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Экран входа/регистрации для Design mode.
class DesignAuthScreen extends ConsumerStatefulWidget {
  const DesignAuthScreen({super.key});

  @override
  ConsumerState<DesignAuthScreen> createState() => _DesignAuthScreenState();
}

bool _isValidPhone(String s) {
  final cleaned = s.replaceAll(RegExp(r'\s'), '');
  if (cleaned.length < 8) return false;
  return RegExp(r'^\+[0-9]+$').hasMatch(cleaned);
}

class _DesignAuthScreenState extends ConsumerState<DesignAuthScreen>
    with TickerProviderStateMixin {
  bool _isRegister = false;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  late final AnimationController _logoController;
  late final AnimationController _formController;
  late final AnimationController _glowController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    _formFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic),
    );
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _formController, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
    );

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _formController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _formController.dispose();
    _glowController.dispose();
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
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final phone = _phoneController.text.trim();
    try {
      if (_isRegister) {
        if (email.isEmpty) {
          setState(() { _error = 'Введите email'; _loading = false; });
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
        if (password != _confirmController.text) {
          setState(() {
            _error = 'Пароли не совпадают';
            _loading = false;
          });
          return;
        }
        await ref.read(authRepositoryProvider).signUp(email: email, password: password, phone: phone);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Регистрация успешна. Подтвердите email при необходимости.')),
          );
          setState(() {
            _isRegister = false;
            _loading = false;
          });
        }
      } else {
        await ref.read(authRepositoryProvider).signIn(email: email, password: password);
      }
    } on AuthException catch (e) {
      String msg = e.message;
      if (msg == 'Этот номер уже используется') { /* use as is */ }
      else if (msg.contains('Invalid login')) msg = 'Неверный email или пароль';
      else if (msg.contains('already registered')) msg = 'Этот email уже зарегистрирован';
      else if (msg.contains('Email not confirmed')) msg = 'Подтвердите email по ссылке';
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
      backgroundColor: AurixTokens.bg0,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        // Animated AURIX logo
                        AnimatedBuilder(
                          animation: Listenable.merge([_logoController, _glowController]),
                          builder: (context, child) {
                            return FadeTransition(
                              opacity: _logoFade,
                              child: ScaleTransition(
                                scale: _logoScale,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: ShaderMask(
                                    shaderCallback: (bounds) {
                                      final t = _glowController.value;
                                      return LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          AurixTokens.orange,
                                          AurixTokens.orange.withValues(alpha: 0.6),
                                          Colors.white,
                                          AurixTokens.orange.withValues(alpha: 0.6),
                                          AurixTokens.orange,
                                        ],
                                        stops: [
                                          0.0,
                                          math.max(0, t - 0.15),
                                          t,
                                          math.min(1, t + 0.15),
                                          1.0,
                                        ],
                                      ).createShader(bounds);
                                    },
                                    child: Text(
                                      'AURIX',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 44,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        // Animated form
                        FadeTransition(
                          opacity: _formFade,
                          child: SlideTransition(
                            position: _formSlide,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Text(
                                    _isRegister ? 'Регистрация' : 'Вход',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: AurixTokens.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                if (_error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(_error!, style: TextStyle(color: Colors.red.shade200)),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: AurixTokens.text),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'you@example.com',
                                    filled: true,
                                    fillColor: AurixTokens.glass(0.08),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                ),
                                if (_isRegister) ...[
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    style: const TextStyle(color: AurixTokens.text),
                                    decoration: InputDecoration(
                                      labelText: 'Телефон',
                                      hintText: '+7... или +374...',
                                      filled: true,
                                      fillColor: AurixTokens.glass(0.08),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(color: AurixTokens.text),
                                  decoration: InputDecoration(
                                    labelText: _isRegister ? 'Пароль (не менее 8 символов)' : 'Пароль',
                                    filled: true,
                                    fillColor: AurixTokens.glass(0.08),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AurixTokens.muted),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                ),
                                if (_isRegister) ...[
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _confirmController,
                                    obscureText: _obscureConfirm,
                                    style: const TextStyle(color: AurixTokens.text),
                                    decoration: InputDecoration(
                                      labelText: 'Повторите пароль',
                                      filled: true,
                                      fillColor: AurixTokens.glass(0.08),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: AurixTokens.muted),
                                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AurixTokens.orange,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _loading
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : Text(_isRegister ? 'Зарегистрироваться' : 'Войти'),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _isRegister = !_isRegister;
                                    _error = null;
                                    _phoneController.clear();
                                  }),
                                  child: Text(
                                    _isRegister ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Зарегистрироваться',
                                    style: TextStyle(color: AurixTokens.orange),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            FadeTransition(
              opacity: _footerFade,
              child: Padding(
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
            ),
          ],
        ),
      ),
    );
  }
}
