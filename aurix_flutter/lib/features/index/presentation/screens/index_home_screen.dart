import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

class IndexHomeScreen extends ConsumerStatefulWidget {
  const IndexHomeScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<IndexHomeScreen> createState() => _IndexHomeScreenState();
}

class _IndexHomeScreenState extends ConsumerState<IndexHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final dk = w >= 800;

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(dk ? 40 : 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(children: [
              SizedBox(height: dk ? 60 : 32),

              // ── Animated badge ──
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AurixTokens.accent.withValues(alpha: 0.15 + _pulseCtrl.value * 0.1),
                      AurixTokens.accent.withValues(alpha: 0.03),
                    ]),
                    boxShadow: [
                      BoxShadow(
                        color: AurixTokens.accent.withValues(alpha: 0.1 + _pulseCtrl.value * 0.08),
                        blurRadius: 48,
                        spreadRadius: -12,
                      ),
                    ],
                  ),
                  child: Icon(Icons.leaderboard_rounded,
                      size: 44, color: AurixTokens.accent.withValues(alpha: 0.8 + _pulseCtrl.value * 0.2)),
                ),
              ),
              const SizedBox(height: 28),

              // ── Title ──
              Text('AURIX РЕЙТИНГ', style: TextStyle(
                fontFamily: AurixTokens.fontDisplay,
                color: AurixTokens.text,
                fontSize: dk ? 36 : 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              )),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AurixTokens.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
                ),
                child: Text('СКОРО', style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  color: AurixTokens.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                )),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: dk ? 480 : double.infinity,
                child: Text(
                  'Единая система рейтинга артистов на платформе.\nМы создаём пространство, где талант определяет позицию.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AurixTokens.textSecondary,
                    fontSize: dk ? 16 : 14,
                    height: 1.7,
                  ),
                ),
              ),

              SizedBox(height: dk ? 56 : 40),

              // ── Feature cards ──
              _FeatureCard(
                icon: Icons.trending_up_rounded,
                color: AurixTokens.accent,
                title: 'Живой рейтинг',
                desc: 'Позиция обновляется в реальном времени на основе стримов, релизов и активности. Чем больше делаешь — тем выше.',
                delay: 0,
              ),
              const SizedBox(height: 14),
              _FeatureCard(
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFFFFD700),
                title: 'Достижения и Awards',
                desc: 'Уникальные бейджи за вехи карьеры: первый релиз, 1000 стримов, топ-10 рейтинга. Коллекционируй и показывай в профиле.',
                delay: 80,
              ),
              const SizedBox(height: 14),
              _FeatureCard(
                icon: Icons.show_chart_rounded,
                color: AurixTokens.positive,
                title: 'История роста',
                desc: 'Графики твоего прогресса по неделям и месяцам. Видишь динамику, понимаешь что работает.',
                delay: 160,
              ),
              const SizedBox(height: 14),
              _FeatureCard(
                icon: Icons.groups_rounded,
                color: AurixTokens.aiAccent,
                title: 'Профили артистов',
                desc: 'Открытые профили с рейтингом, жанром, достижениями. Зрители и лейблы находят тебя по рейтингу.',
                delay: 240,
              ),
              const SizedBox(height: 14),
              _FeatureCard(
                icon: Icons.bolt_rounded,
                color: AurixTokens.warning,
                title: 'Рекомендации AI',
                desc: 'Персональные советы: что улучшить, какие треки добавить в плейлисты, как поднять позицию.',
                delay: 320,
              ),

              SizedBox(height: dk ? 56 : 40),

              // ── Bottom message ──
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(dk ? 36 : 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AurixTokens.accent.withValues(alpha: 0.06),
                      AurixTokens.aiAccent.withValues(alpha: 0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.12)),
                ),
                child: Column(children: [
                  Text('Мы работаем над этим', style: TextStyle(
                    fontFamily: AurixTokens.fontHeading,
                    color: AurixTokens.text,
                    fontSize: dk ? 22 : 18,
                    fontWeight: FontWeight.w800,
                  )),
                  const SizedBox(height: 12),
                  Text(
                    'Рейтинг запустится когда на платформе будет достаточно артистов. Пока — выпускай музыку, набирай стримы, и ты будешь среди первых.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AurixTokens.textSecondary,
                      fontSize: 14,
                      height: 1.7,
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 40),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final int delay;
  const _FeatureCard({required this.icon, required this.color, required this.title, required this.desc, this.delay = 0});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    Future.delayed(Duration(milliseconds: 100 + widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withValues(alpha: 0.04) : AurixTokens.glass(0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered ? widget.color.withValues(alpha: 0.2) : AurixTokens.stroke(0.06),
            ),
            boxShadow: _hovered ? [
              BoxShadow(color: widget.color.withValues(alpha: 0.05), blurRadius: 32, spreadRadius: -10),
            ] : null,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, size: 22, color: widget.color),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: TextStyle(
                  color: AurixTokens.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 6),
                Text(widget.desc, style: TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 13,
                  height: 1.55,
                )),
              ],
            )),
          ]),
        ),
      ),
    );
  }
}
