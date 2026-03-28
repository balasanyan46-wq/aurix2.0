import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class FoundingSection extends StatelessWidget {
  final VoidCallback onRegister;
  const FoundingSection({super.key, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return LandingSection(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(desktop ? 56 : 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AurixTokens.surface2,
              AurixTokens.surface1,
            ],
          ),
          border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: AurixTokens.accent.withValues(alpha: 0.05),
              blurRadius: 48,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AurixTokens.accent.withValues(alpha: 0.10),
              ),
              child: const Text(
                'FOUNDING ARTISTS',
                style: TextStyle(
                  color: AurixTokens.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Стань частью новой волны',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AurixTokens.text,
                fontSize: desktop ? 32 : 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'Ранний доступ — это не просто тест. Это возможность быть среди первых артистов, которые строят карьеру с AI. Тех, кто думает о будущем.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AurixTokens.muted, fontSize: 15, height: 1.6),
              ),
            ),
            const SizedBox(height: 32),
            PrimaryCta(label: 'Получить ранний доступ', onTap: onRegister),
          ],
        ),
      ),
    );
  }
}
