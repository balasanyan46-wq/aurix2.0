import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class NavigatorSection extends StatelessWidget {
  const NavigatorSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      color: AurixTokens.surface1.withValues(alpha: 0.25),
      child: LandingSection(
        child: SplitCanvas(
          reversed: false,
          left: _NavigatorCopy(desktop: desktop),
          right: const _NavigatorChecklist(),
        ),
      ),
    );
  }
}

class _NavigatorCopy extends StatelessWidget {
  final bool desktop;
  const _NavigatorCopy({required this.desktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: desktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        const SectionLabel(text: 'НАВИГАТОР'),
        const SizedBox(height: 24),
        Text(
          'Навигатор артиста',
          textAlign: desktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: AurixTokens.text,
            fontSize: desktop ? 38 : 28,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AURIX ведёт тебя шаг за шагом и показывает, что делать дальше. Не просто данные — а конкретные действия.',
          textAlign: desktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(color: AurixTokens.muted, fontSize: 15, height: 1.6),
        ),
        const SizedBox(height: 28),
        _NavBullet(text: 'Что делать перед релизом'),
        const SizedBox(height: 10),
        _NavBullet(text: 'Как развивать аудиторию'),
        const SizedBox(height: 10),
        _NavBullet(text: 'Как улучшить треки'),
        const SizedBox(height: 10),
        _NavBullet(text: 'Как расти системно'),
      ],
    );
  }
}

class _NavBullet extends StatelessWidget {
  final String text;
  const _NavBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AurixTokens.accent),
        ),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Checklist mock ──────────────────────────────────────────────

class _NavigatorChecklist extends StatelessWidget {
  const _NavigatorChecklist();

  @override
  Widget build(BuildContext context) {
    return MockUIPanel(
      title: 'Навигатор артиста',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress header
          Row(
            children: [
              const Text('Прогресс', style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('3 / 6', style: TextStyle(color: AurixTokens.accent, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          Container(
            height: 4,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: AurixTokens.stroke(0.08)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(colors: [AurixTokens.accent, AurixTokens.aiAccent]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Tasks
          const _CheckItem(text: 'Загрузить трек для анализа', done: true),
          const SizedBox(height: 10),
          const _CheckItem(text: 'Изучить ДНК профиля', done: true),
          const SizedBox(height: 10),
          const _CheckItem(text: 'Подготовить обложку', done: true),
          const SizedBox(height: 10),
          const _CheckItem(text: 'Запустить pre-save кампанию', done: false, current: true),
          const SizedBox(height: 10),
          const _CheckItem(text: 'Создать контент', done: false),
          const SizedBox(height: 10),
          const _CheckItem(text: 'Релиз и промо', done: false),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  final bool done;
  final bool current;
  const _CheckItem({required this.text, required this.done, this.current = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: done
                ? AurixTokens.positive.withValues(alpha: 0.12)
                : (current ? AurixTokens.accent.withValues(alpha: 0.10) : AurixTokens.stroke(0.06)),
            border: Border.all(
              color: done
                  ? AurixTokens.positive.withValues(alpha: 0.4)
                  : (current ? AurixTokens.accent.withValues(alpha: 0.3) : AurixTokens.stroke(0.12)),
            ),
          ),
          child: done
              ? Icon(Icons.check_rounded, size: 14, color: AurixTokens.positive)
              : (current ? Icon(Icons.arrow_forward_rounded, size: 12, color: AurixTokens.accent) : null),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: done ? AurixTokens.muted : (current ? AurixTokens.text : AurixTokens.textSecondary),
              fontSize: 13,
              fontWeight: current ? FontWeight.w600 : FontWeight.w400,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: AurixTokens.muted.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}
