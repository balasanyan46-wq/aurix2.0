import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

/// Solution: AURIX = The Artist Operating System.
class SolutionSection extends StatelessWidget {
  const SolutionSection({super.key});

  static const _pillars = [
    _Pillar(icon: Icons.insights_rounded, title: 'Анализ', desc: 'AI оценивает трек до релиза: потенциал, hook, качество', color: AurixTokens.accent),
    _Pillar(icon: Icons.route_rounded, title: 'Стратегия', desc: 'Персональный план продвижения: что, где, когда постить', color: AurixTokens.aiAccent),
    _Pillar(icon: Icons.auto_awesome_rounded, title: 'Контент', desc: 'Обложки, видео, тексты — генерируются за минуты', color: AurixTokens.accentWarm),
    _Pillar(icon: Icons.rocket_launch_rounded, title: 'Продвижение', desc: 'Дистрибуция, промо, аналитика в одном месте', color: AurixTokens.positive),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AurixTokens.bg0,
            AurixTokens.accent.withValues(alpha: 0.03),
            AurixTokens.bg0,
          ],
        ),
      ),
      child: LandingSection(
        child: Column(
          children: [
            const SectionLabel(text: 'РЕШЕНИЕ'),
            const SizedBox(height: 20),
            GradientText(
              'AURIX = система артиста',
              style: TextStyle(
                fontSize: desktop ? 42 : 30,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Всё что нужно для роста — в одном AI-инструменте.\nНе набор фич, а единая операционная система.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AurixTokens.muted, fontSize: desktop ? 16 : 14, height: 1.6),
            ),
            const SizedBox(height: 48),
            desktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _pillars.length; i++) ...[
                        Expanded(child: _PillarCard(p: _pillars[i], index: i)),
                        if (i < _pillars.length - 1) const SizedBox(width: 16),
                      ],
                    ],
                  )
                : Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (var i = 0; i < _pillars.length; i++)
                        SizedBox(
                          width: (MediaQuery.sizeOf(context).width - 54) / 2,
                          child: _PillarCard(p: _pillars[i], index: i),
                        ),
                    ],
                  ),
            const SizedBox(height: 48),
            // Connector line
            Container(
              width: desktop ? 400 : double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [AurixTokens.accent.withValues(alpha: 0.08), AurixTokens.aiAccent.withValues(alpha: 0.06)],
                ),
                border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_rounded, color: AurixTokens.accent, size: 18),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Все модули связаны AI — каждый шаг усиливает следующий',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pillar {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _Pillar({required this.icon, required this.title, required this.desc, required this.color});
}

class _PillarCard extends StatefulWidget {
  final _Pillar p;
  final int index;
  const _PillarCard({required this.p, required this.index});

  @override
  State<_PillarCard> createState() => _PillarCardState();
}

class _PillarCardState extends State<_PillarCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.p.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _hover ? c.withValues(alpha: 0.06) : AurixTokens.surface1,
          border: Border.all(color: _hover ? c.withValues(alpha: 0.3) : AurixTokens.stroke(0.10)),
          boxShadow: [
            if (_hover)
              BoxShadow(color: c.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(colors: [c.withValues(alpha: 0.2), c.withValues(alpha: 0.08)]),
              ),
              child: Icon(widget.p.icon, color: c, size: 22),
            ),
            const SizedBox(height: 16),
            Text(widget.p.title, style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(widget.p.desc, style: TextStyle(color: AurixTokens.muted, fontSize: 12.5, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
