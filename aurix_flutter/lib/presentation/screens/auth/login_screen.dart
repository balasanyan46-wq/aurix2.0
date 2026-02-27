import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  late final AnimationController _logoController;
  late final AnimationController _formController;
  late final AnimationController _glowController;
  late final AnimationController _btnShimmerController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _formFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _footerFade;
  late final Animation<double> _taglineFade;
  int _glowCycles = 0;
  int _btnCycles = 0;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _glowCycles = 0;
    _glowController.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _glowCycles++;
        if (_glowCycles < 6) {
          if (status == AnimationStatus.completed) {
            _glowController.reverse();
          } else {
            _glowController.forward();
          }
        }
      }
    });
    _glowController.forward();

    _btnShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _btnCycles = 0;
    _btnShimmerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _btnCycles++;
        if (_btnCycles < 3) {
          _btnShimmerController.forward(from: 0);
        }
      }
    });
    _btnShimmerController.forward();

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
    _formFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic),
    );
    _footerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _formController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
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
    _btnShimmerController.dispose();
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
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      // Do not navigate here. AuthGate/router will switch screens when session is ready.
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

  InputDecoration _premiumInput(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AurixTokens.muted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
      ),
      filled: true,
      fillColor: AurixTokens.glass(0.06),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AurixTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AurixTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AurixTokens.orange.withValues(alpha: 0.7), width: 1.5),
      ),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: Stack(
        children: [
          // Background radial vignette
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _BackgroundPainter(
                    glowProgress: _glowController.value,
                    logoFade: _logoFade.value,
                  ),
                );
              },
            ),
          ),
          SafeArea(
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 16),
                              _buildLogo(),
                              const SizedBox(height: 6),
                              _buildTagline(),
                              const SizedBox(height: 32),
                              _buildDivider(),
                              const SizedBox(height: 32),
                              _buildForm(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoController, _glowController]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _logoFade,
          child: ScaleTransition(
            scale: _logoScale,
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
              child: const Text(
                'AURIX',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 10,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagline() {
    return FadeTransition(
      opacity: _taglineFade,
      child: Text(
        'MUSIC INTELLIGENCE PLATFORM',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AurixTokens.muted.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 3,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return FadeTransition(
      opacity: _formFade,
      child: Container(
        width: 40,
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AurixTokens.orange.withValues(alpha: 0.0),
              AurixTokens.orange.withValues(alpha: 0.5),
              AurixTokens.orange.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return FadeTransition(
      opacity: _formFade,
      child: SlideTransition(
        position: _formSlide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 18,
                        color: Colors.red.shade300),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade200,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
              decoration: _premiumInput('Email'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите email' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
              decoration: _premiumInput(
                'Пароль',
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AurixTokens.muted,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Введите пароль' : null,
            ),
            const SizedBox(height: 28),
            _buildShimmerButton(),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.push('/register'),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Нет аккаунта? ',
                      style: TextStyle(
                        color: AurixTokens.muted,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: 'Зарегистрироваться',
                      style: TextStyle(
                        color: AurixTokens.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerButton() {
    return AnimatedBuilder(
      animation: _btnShimmerController,
      builder: (context, _) {
        final t = _btnShimmerController.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AurixTokens.orange.withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: -4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _loading
                  ? null
                  : () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _submit();
                      }
                    },
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AurixTokens.orange,
                      AurixTokens.orange2,
                      AurixTokens.orange,
                      Color.lerp(AurixTokens.orange, Colors.white, 0.3)!,
                      AurixTokens.orange,
                    ],
                    stops: [
                      0.0,
                      math.max(0, t - 0.2),
                      math.max(0, t - 0.05),
                      t,
                      math.min(1, t + 0.15),
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Войти',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return FadeTransition(
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
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double glowProgress;
  final double logoFade;

  _BackgroundPainter({required this.glowProgress, required this.logoFade});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.32);
    final radius = size.width * 0.7;
    final pulseRadius = radius * (0.9 + 0.1 * math.sin(glowProgress * math.pi));

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          AurixTokens.orange.withValues(alpha: 0.06 * logoFade),
          AurixTokens.orange.withValues(alpha: 0.02 * logoFade),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: pulseRadius),
      );

    canvas.drawCircle(center, pulseRadius, paint);
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      old.glowProgress != glowProgress || old.logoFade != logoFade;
}
