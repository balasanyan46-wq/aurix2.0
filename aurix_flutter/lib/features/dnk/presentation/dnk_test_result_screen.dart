import 'package:flutter/material.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import '../data/dnk_tests_models.dart';

// ── Axis visual config ───────────────────────────────────

const _axisEmoji = <String, String>{
  'stage_power': '\u{26A1}',
  'vulnerability': '\u{1F49C}',
  'novelty_drive': '\u{1F52E}',
  'cohesion': '\u{1F3AF}',
  'directness': '\u{1F4A2}',
  'warmth': '\u{2600}',
  'provocation': '\u{1F525}',
  'clarity': '\u{1F48E}',
  'inner_conflict': '\u{1F300}',
  'narrative_depth': '\u{1F30A}',
  'emotional_range': '\u{1F308}',
  'resolution_style': '\u{1F511}',
  'community_bias': '\u{1F91D}',
  'viral_bias': '\u{1F4A5}',
  'playlist_bias': '\u{1F3B5}',
  'live_bias': '\u{1F3A4}',
  'planning': '\u{1F4CB}',
  'execution': '\u{1F3C3}',
  'recovery': '\u{1F504}',
  'focus_protection': '\u{1F6E1}',
  'avoidance': '\u{1F648}',
  'impulsivity': '\u{26A1}',
  'dependency': '\u{1F517}',
  'identity_rigidity': '\u{1F9CA}',
};

const _axisLabels = <String, String>{
  'stage_power': 'Сценическая сила',
  'vulnerability': 'Уязвимость',
  'novelty_drive': 'Тяга к новизне',
  'cohesion': 'Цельность образа',
  'directness': 'Прямота',
  'warmth': 'Теплота',
  'provocation': 'Провокативность',
  'clarity': 'Ясность',
  'inner_conflict': 'Внутренний конфликт',
  'narrative_depth': 'Глубина нарратива',
  'emotional_range': 'Эмоциональный диапазон',
  'resolution_style': 'Стиль развязки',
  'community_bias': 'Опора на комьюнити',
  'viral_bias': 'Вирусный потенциал',
  'playlist_bias': 'Фокус на плейлистах',
  'live_bias': 'Фокус на лайвах',
  'planning': 'Планирование',
  'execution': 'Исполнение',
  'recovery': 'Восстановление',
  'focus_protection': 'Защита фокуса',
  'avoidance': 'Избегание',
  'impulsivity': 'Импульсивность',
  'dependency': 'Зависимость',
  'identity_rigidity': 'Жёсткость идентичности',
};

const _testTitles = <String, String>{
  'artist_archetype': 'Твой Архетип',
  'tone_communication': 'Твой Голос',
  'story_core': 'Твой Сюжет',
  'growth_profile': 'Твой Путь',
  'discipline_index': 'Твой Ритм',
  'career_risk': 'Твой Щит',
};

const _testSubtitles = <String, String>{
  'artist_archetype': 'Кто ты на сцене и за её пределами',
  'tone_communication': 'Как мир слышит тебя',
  'story_core': 'История, которая делает тебя уникальным',
  'growth_profile': 'Куда ведёт твоя траектория',
  'discipline_index': 'Как ты управляешь своей энергией',
  'career_risk': 'Что защитит тебя от самосаботажа',
};

const _testGradients = <String, List<Color>>{
  'artist_archetype': [Color(0xFFFF6A1A), Color(0xFFB84DFF)],
  'tone_communication': [Color(0xFFFF7A45), Color(0xFFF44336)],
  'story_core': [Color(0xFFFFA000), Color(0xFFE53935)],
  'growth_profile': [Color(0xFF4CAF50), Color(0xFF00BCD4)],
  'discipline_index': [Color(0xFF7B5CFF), Color(0xFF3F51B5)],
  'career_risk': [Color(0xFFFF6F00), Color(0xFFD84315)],
};

// ── Main Screen ──────────────────────────────────────────

class DnkTestResultScreen extends StatelessWidget {
  final DnkTestResult result;

  const DnkTestResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final gradient = _testGradients[result.testSlug] ?? [AurixTokens.accent, const Color(0xFFB84DFF)];
    final title = _testTitles[result.testSlug] ?? 'Результат';
    final subtitle = _testSubtitles[result.testSlug] ?? '';

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: EdgeInsets.all(isDesktop ? 32 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── Hero Card ──
                  FadeInSlide(
                    delayMs: 0,
                    child: _HeroCard(
                      title: title,
                      subtitle: subtitle,
                      summary: result.summary,
                      gradient: gradient,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Axes Radar ──
                  FadeInSlide(
                    delayMs: 80,
                    child: _AxesCard(axes: result.scoreAxes, gradient: gradient),
                  ),
                  const SizedBox(height: 16),
                  // ── Strengths & Risks side by side on desktop ──
                  if (isDesktop)
                    FadeInSlide(
                      delayMs: 140,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _InsightCard(
                            title: 'Суперсилы',
                            icon: Icons.bolt_rounded,
                            color: AurixTokens.positive,
                            items: result.strengths,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _InsightCard(
                            title: 'Зоны роста',
                            icon: Icons.warning_amber_rounded,
                            color: AurixTokens.warning,
                            items: result.risks,
                          )),
                        ],
                      ),
                    )
                  else ...[
                    FadeInSlide(
                      delayMs: 140,
                      child: _InsightCard(
                        title: 'Суперсилы',
                        icon: Icons.bolt_rounded,
                        color: AurixTokens.positive,
                        items: result.strengths,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeInSlide(
                      delayMs: 180,
                      child: _InsightCard(
                        title: 'Зоны роста',
                        icon: Icons.warning_amber_rounded,
                        color: AurixTokens.warning,
                        items: result.risks,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // ── 7-day Action Plan ──
                  FadeInSlide(
                    delayMs: 220,
                    child: _ActionPlanCard(actions: result.actions7Days, gradient: gradient),
                  ),
                  const SizedBox(height: 16),
                  // ── Content Ideas ──
                  if (result.contentPrompts.isNotEmpty)
                    FadeInSlide(
                      delayMs: 280,
                      child: _ContentIdeasCard(prompts: result.contentPrompts),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero Card ────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String summary;
  final List<Color> gradient;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusHero),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradient[0].withValues(alpha: 0.15),
            gradient[1].withValues(alpha: 0.08),
            AurixTokens.bg1,
          ],
        ),
        border: Border.all(color: gradient[0].withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.1),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title area
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(colors: gradient).createShader(bounds),
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AurixTokens.fontHeading,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: gradient[0].withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          // Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradient[0].withValues(alpha: 0.3), Colors.transparent],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Summary text
          Text(
            summary,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: 15,
              height: 1.7,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Axes Card ────────────────────────────────────────────

class _AxesCard extends StatelessWidget {
  final Map<String, double> axes;
  final List<Color> gradient;

  const _AxesCard({required this.axes, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
        gradient: AurixTokens.cardGradient,
        border: Border.all(color: AurixTokens.stroke(0.18)),
        boxShadow: AurixTokens.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radar_rounded, color: gradient[0], size: 20),
              const SizedBox(width: 8),
              Text(
                'Твой профиль',
                style: TextStyle(
                  fontFamily: AurixTokens.fontHeading,
                  color: AurixTokens.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...axes.entries.map((e) => _AxisBar(
            label: _axisLabels[e.key] ?? e.key,
            emoji: _axisEmoji[e.key] ?? '\u{1F4CA}',
            value: e.value,
            color: gradient[0],
          )),
        ],
      ),
    );
  }
}

class _AxisBar extends StatelessWidget {
  final String label;
  final String emoji;
  final double value;
  final Color color;

  const _AxisBar({required this.label, required this.emoji, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final normalized = (value / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, style: const TextStyle(
                  color: AurixTokens.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AurixTokens.surface2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: normalized,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.7), color],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Insight Card (Strengths / Risks) ─────────────────────

class _InsightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _InsightCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
        gradient: AurixTokens.cardGradient,
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: AurixTokens.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(
                fontFamily: AurixTokens.fontHeading,
                color: AurixTokens.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text('Нет данных', style: TextStyle(color: AurixTokens.muted))
          else
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.6),
                    ),
                  ),
                  Expanded(
                    child: Text(item, style: const TextStyle(
                      color: AurixTokens.textSecondary, fontSize: 13, height: 1.5)),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

// ── Action Plan Card ─────────────────────────────────────

class _ActionPlanCard extends StatelessWidget {
  final List<String> actions;
  final List<Color> gradient;

  const _ActionPlanCard({required this.actions, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradient[0].withValues(alpha: 0.06),
            AurixTokens.bg1,
          ],
        ),
        border: Border.all(color: gradient[0].withValues(alpha: 0.15)),
        boxShadow: AurixTokens.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(colors: gradient),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('План на 7 дней', style: TextStyle(
                    fontFamily: AurixTokens.fontHeading,
                    color: AurixTokens.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  )),
                  Text('Конкретные шаги для прогресса', style: TextStyle(
                    color: AurixTokens.muted, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (actions.isEmpty)
            const Text('Нет данных', style: TextStyle(color: AurixTokens.muted))
          else
            ...actions.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          gradient[0].withValues(alpha: 0.15),
                          gradient[1].withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(color: gradient[0].withValues(alpha: 0.2)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${e.key + 1}',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontHeading,
                        color: gradient[0],
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(e.value, style: const TextStyle(
                        color: AurixTokens.textSecondary, fontSize: 13, height: 1.5)),
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

// ── Content Ideas Card ───────────────────────────────────

class _ContentIdeasCard extends StatelessWidget {
  final List<String> prompts;

  const _ContentIdeasCard({required this.prompts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
        gradient: AurixTokens.cardGradient,
        border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.15)),
        boxShadow: [
          ...AurixTokens.subtleShadow,
          BoxShadow(
            color: AurixTokens.aiAccent.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AurixTokens.aiAccent.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.lightbulb_rounded, color: AurixTokens.aiAccent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Контент-идеи для тебя', style: TextStyle(
                      fontFamily: AurixTokens.fontHeading,
                      color: AurixTokens.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    )),
                    Text('Готовые заготовки на основе твоего DNK', style: TextStyle(
                      color: AurixTokens.muted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...prompts.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AurixTokens.aiAccent.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: AurixTokens.aiAccent.withValues(alpha: 0.5), size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p, style: const TextStyle(
                    color: AurixTokens.textSecondary, fontSize: 13, height: 1.45)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
