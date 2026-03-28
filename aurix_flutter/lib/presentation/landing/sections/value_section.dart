import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class ValueSection extends StatelessWidget {
  const ValueSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      color: AurixTokens.surface1.withValues(alpha: 0.25),
      child: LandingSection(
        child: Column(
          children: [
            const SectionLabel(text: 'ЦЕННОСТЬ'),
            const SizedBox(height: 24),
            Text(
              'Один инструмент вместо десяти',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AurixTokens.text,
                fontSize: desktop ? 40 : 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                'AURIX заменяет целый набор инструментов, которые артисты обычно собирают по частям.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AurixTokens.muted, fontSize: desktop ? 16 : 14, height: 1.6),
              ),
            ),
            SizedBox(height: desktop ? 48 : 36),
            // Comparison layout
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: desktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Expanded(child: _OldWay()),
                        SizedBox(width: 28),
                        Expanded(child: _NewWay()),
                      ],
                    )
                  : Column(
                      children: const [
                        _OldWay(),
                        SizedBox(height: 20),
                        _NewWay(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Old way (multiple tools) ────────────────────────────────────

class _OldWay extends StatelessWidget {
  const _OldWay();

  static const _tools = [
    'Аналитика стримов',
    'Отдельный сервис дистрибуции',
    'Планировщик контента',
    'Таблицы метрик',
    'Разрозненные гайды',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AurixTokens.bg0.withValues(alpha: 0.6),
        border: Border.all(color: AurixTokens.stroke(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Без AURIX', style: TextStyle(color: AurixTokens.muted, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 18),
          for (final tool in _tools) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.close_rounded, color: AurixTokens.danger.withValues(alpha: 0.5), size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tool,
                      style: TextStyle(
                        color: AurixTokens.muted,
                        fontSize: 13.5,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: AurixTokens.muted.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── New way (AURIX) ─────────────────────────────────────────────

class _NewWay extends StatelessWidget {
  const _NewWay();

  static const _features = [
    'AI анализ треков',
    'Дистрибуция',
    'Контент генератор',
    'Стратегия продвижения',
    'ДНК артиста',
    'Навигатор',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AurixTokens.accent.withValues(alpha: 0.06),
            AurixTokens.aiAccent.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            'AURIX',
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2),
          ),
          const SizedBox(height: 18),
          for (final f in _features) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.check_rounded, color: AurixTokens.positive, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(f, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13.5, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
