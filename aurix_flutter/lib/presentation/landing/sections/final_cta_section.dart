import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class FinalCtaSection extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onLogin;
  const FinalCtaSection({super.key, required this.onRegister, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Stack(
      children: [
        // Subtle radial glow behind text
        Positioned.fill(
          child: Center(
            child: Container(
              width: desktop ? 500 : 300,
              height: desktop ? 500 : 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AurixTokens.accent.withValues(alpha: 0.05),
                    AurixTokens.aiAccent.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        LandingSection(
          padding: EdgeInsets.symmetric(
            horizontal: desktop ? 40 : 20,
            vertical: desktop ? 120 : 80,
          ),
          child: Column(
            children: [
              Text(
                'Твоей музыке не нужна удача.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AurixTokens.text,
                  fontSize: desktop ? 46 : 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              GradientText(
                'Ей нужна стратегия.',
                style: TextStyle(
                  fontSize: desktop ? 46 : 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 40),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  PrimaryCta(label: 'Создать аккаунт', onTap: onRegister),
                  OutlineCta(label: 'Войти', onTap: onLogin),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Footer ──────────────────────────────────────────────────────

class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AurixTokens.stroke(0.08))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1140),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\u00a9 ${DateTime.now().year} AURIX',
                style: TextStyle(color: AurixTokens.micro, fontSize: 12),
              ),
              Row(
                children: const [
                  _FooterLink(label: 'Политика конфиденциальности'),
                  SizedBox(width: 24),
                  _FooterLink(label: 'Условия использования'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  const _FooterLink({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(color: AurixTokens.micro, fontSize: 12),
    );
  }
}
