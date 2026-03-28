import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

/// Product demo: visual UI cards showing each product capability with real numbers.
class ProductDemoSection extends StatelessWidget {
  const ProductDemoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return LandingSection(
      child: Column(
        children: [
          const SectionLabel(text: 'ПРОДУКТ'),
          const SizedBox(height: 20),
          Text(
            'Не просто фичи.\nЦелая студия в браузере.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: desktop ? 42 : 30,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Каждый инструмент даёт конкретный, измеримый результат',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.muted, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 48),

          // Demo cards - 2x2 grid
          if (desktop)
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _DemoCard(
                      title: 'AI Анализ трека',
                      desc: 'Загрузи трек — получи score, вероятность вирусности и рекомендации по миксу за 30 секунд',
                      color: AurixTokens.accent,
                      result: '82/100 — потенциал вирусности',
                      child: const _AnalysisMock(),
                    )),
                    const SizedBox(width: 20),
                    Expanded(child: _DemoCard(
                      title: 'Генерация обложки',
                      desc: 'Опиши стиль — AI создаст обложку за 30 секунд. Промышленное качество 3000×3000px',
                      color: AurixTokens.aiAccent,
                      result: '200+ обложек создано артистами',
                      child: const _CoverMock(),
                    )),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _DemoCard(
                      title: 'AI Стратегия запуска',
                      desc: 'Персональный план: какие площадки, когда постить, какой контент создать для максимального охвата',
                      color: AurixTokens.accentWarm,
                      result: 'x3 рост сохранений за первый месяц',
                      child: const _StrategyMock(),
                    )),
                    const SizedBox(width: 20),
                    Expanded(child: _DemoCard(
                      title: 'Промо видео',
                      desc: 'AI создаёт вертикальные видео для Reels, TikTok, Shorts — готово к загрузке',
                      color: AurixTokens.positive,
                      result: '15 сек видео = +340% охвата',
                      child: const _VideoMock(),
                    )),
                  ],
                ),
              ],
            )
          else
            Column(
              children: [
                _DemoCard(title: 'AI Анализ трека', desc: 'Score, вероятность вирусности и рекомендации', color: AurixTokens.accent, result: '82/100 потенциал', child: const _AnalysisMock()),
                const SizedBox(height: 16),
                _DemoCard(title: 'Генерация обложки', desc: 'AI создаёт обложку за 30 секунд', color: AurixTokens.aiAccent, result: '200+ обложек создано', child: const _CoverMock()),
                const SizedBox(height: 16),
                _DemoCard(title: 'AI Стратегия', desc: 'Персональный план запуска', color: AurixTokens.accentWarm, result: 'x3 рост сохранений', child: const _StrategyMock()),
                const SizedBox(height: 16),
                _DemoCard(title: 'Промо видео', desc: 'Видео для Reels и TikTok', color: AurixTokens.positive, result: '+340% охвата', child: const _VideoMock()),
              ],
            ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatefulWidget {
  final String title;
  final String desc;
  final Color color;
  final String result;
  final Widget child;
  const _DemoCard({required this.title, required this.desc, required this.color, required this.result, required this.child});

  @override
  State<_DemoCard> createState() => _DemoCardState();
}

class _DemoCardState extends State<_DemoCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(24),
        transform: _hover ? (Matrix4.identity()..translate(0.0, -4.0)) : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AurixTokens.surface1,
          border: Border.all(
            color: _hover ? widget.color.withValues(alpha: 0.4) : AurixTokens.stroke(0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: _hover ? widget.color.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.2),
              blurRadius: _hover ? 40 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mock UI
            widget.child,
            const SizedBox(height: 20),
            Text(widget.title, style: TextStyle(color: widget.color, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(widget.desc, style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 10),
            // Result badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: widget.color.withValues(alpha: 0.08),
                border: Border.all(color: widget.color.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up_rounded, size: 13, color: widget.color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.result,
                      style: TextStyle(color: widget.color, fontSize: 11.5, fontWeight: FontWeight.w700),
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

// ── Mock UI components ──────────────────────────────────────────

class _AnalysisMock extends StatelessWidget {
  const _AnalysisMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AurixTokens.surface2,
        border: Border.all(color: AurixTokens.stroke(0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall score
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AurixTokens.positive.withValues(alpha: 0.12),
                ),
                child: Text('82', style: TextStyle(color: AurixTokens.positive, fontSize: 18, fontWeight: FontWeight.w900, fontFeatures: AurixTokens.tabularFigures)),
              ),
              const SizedBox(width: 8),
              Text('/100', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: AurixTokens.positive.withValues(alpha: 0.1),
                ),
                child: Text('ВЫСОКИЙ', style: TextStyle(color: AurixTokens.positive, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _bar('Вирусность', 0.82, AurixTokens.accent),
          const SizedBox(height: 8),
          _bar('Продакшн', 0.91, AurixTokens.aiAccent),
          const SizedBox(height: 8),
          _bar('Плейлист шанс', 0.73, AurixTokens.positive),
        ],
      ),
    );
  }

  Widget _bar(String label, double fill, Color c) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 10))),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: AurixTokens.stroke(0.08)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fill,
              child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: c)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('${(fill * 100).round()}%', style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
      ],
    );
  }
}

class _CoverMock extends StatelessWidget {
  const _CoverMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a0a30), Color(0xFF0a1a2a), Color(0xFF0a0a20)],
        ),
        border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.2)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.2),
                  radius: 1.2,
                  colors: [AurixTokens.aiAccent.withValues(alpha: 0.25), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: RadialGradient(
                  center: const Alignment(0.5, 0.5),
                  radius: 0.8,
                  colors: [AurixTokens.accent.withValues(alpha: 0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MIDNIGHT', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 4)),
                Text('D R E A M S', style: TextStyle(color: AurixTokens.aiGlow.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 6)),
              ],
            ),
          ),
          // AI badge
          Positioned(
            right: 10, bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: AurixTokens.aiAccent.withValues(alpha: 0.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 10, color: AurixTokens.aiGlow),
                  const SizedBox(width: 4),
                  Text('3000×3000', style: TextStyle(color: AurixTokens.aiGlow, fontSize: 9, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          // Time badge
          Positioned(
            left: 10, bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: Text('⚡ 30 сек', style: TextStyle(color: AurixTokens.text, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StrategyMock extends StatelessWidget {
  const _StrategyMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AurixTokens.surface2,
        border: Border.all(color: AurixTokens.stroke(0.08)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, size: 14, color: AurixTokens.accentWarm),
              const SizedBox(width: 6),
              Text('План запуска', style: TextStyle(color: AurixTokens.accentWarm, fontSize: 11, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: AurixTokens.accentWarm.withValues(alpha: 0.1),
                ),
                child: Text('7 дней', style: TextStyle(color: AurixTokens.accentWarm, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _step('1', 'Тизер в Stories — 3 дня до релиза', true),
          const SizedBox(height: 6),
          _step('2', 'TikTok с hook 0:47-1:02', true),
          const SizedBox(height: 6),
          _step('3', 'Reels + Shorts за день до релиза', false),
          const SizedBox(height: 6),
          _step('4', 'Пост-релиз: благодарность + статистика', false),
        ],
      ),
    );
  }

  Widget _step(String num, String text, bool done) {
    return Row(
      children: [
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AurixTokens.positive.withValues(alpha: 0.15) : AurixTokens.stroke(0.1),
          ),
          child: Center(
            child: done
                ? Icon(Icons.check_rounded, size: 10, color: AurixTokens.positive)
                : Text(num, style: TextStyle(color: AurixTokens.muted, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: done ? AurixTokens.textSecondary : AurixTokens.muted,
              fontSize: 11,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: AurixTokens.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoMock extends StatelessWidget {
  const _VideoMock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0a1510), Color(0xFF050a08)],
        ),
        border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.15)),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AurixTokens.positive.withValues(alpha: 0.15),
                    border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: AurixTokens.positive, size: 28),
                ),
                const SizedBox(height: 8),
                Text('Reels · 0:15', style: TextStyle(color: AurixTokens.muted, fontSize: 11)),
              ],
            ),
          ),
          // Format badge
          Positioned(
            left: 10, top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.black.withValues(alpha: 0.5),
              ),
              child: Text('9:16', style: TextStyle(color: AurixTokens.text, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
          // Platform badges
          Positioned(
            right: 10, top: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _platformBadge('TikTok'),
                const SizedBox(width: 4),
                _platformBadge('Reels'),
                const SizedBox(width: 4),
                _platformBadge('Shorts'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _platformBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: AurixTokens.positive.withValues(alpha: 0.15),
      ),
      child: Text(name, style: TextStyle(color: AurixTokens.positive, fontSize: 8, fontWeight: FontWeight.w700)),
    );
  }
}
