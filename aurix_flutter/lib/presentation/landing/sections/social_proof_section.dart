import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

/// Social proof: animated stats + testimonials + case studies.
class SocialProofSection extends StatelessWidget {
  const SocialProofSection({super.key});

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
            AurixTokens.accent.withValues(alpha: 0.02),
            AurixTokens.bg0,
          ],
        ),
      ),
      child: LandingSection(
        child: Column(
          children: [
            const SectionLabel(text: 'РЕЗУЛЬТАТЫ'),
            const SizedBox(height: 20),
            Text(
              'Артисты уже используют AURIX',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AurixTokens.text,
                fontSize: desktop ? 38 : 28,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'И получают измеримые результаты с первого дня',
              textAlign: TextAlign.center,
              style: TextStyle(color: AurixTokens.muted, fontSize: 15),
            ),
            const SizedBox(height: 48),

            // Animated stats row
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _AnimatedStatBadge(endValue: 1247, label: 'AI анализов', icon: Icons.auto_awesome_rounded, color: AurixTokens.aiAccent, suffix: '+'),
                _AnimatedStatBadge(endValue: 89, label: 'Артистов', icon: Icons.person_rounded, color: AurixTokens.accent, suffix: '+'),
                _AnimatedStatBadge(endValue: 430, label: 'Обложек создано', icon: Icons.image_rounded, color: AurixTokens.accentWarm, suffix: '+'),
                _AnimatedStatBadge(endValue: 97, label: 'Довольны результатом', icon: Icons.thumb_up_rounded, color: AurixTokens.positive, suffix: '%'),
              ],
            ),
            const SizedBox(height: 48),

            // Case studies
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _CaseStudyCard(
                    quote: 'Раньше я тратил неделю на обложку и план. С AURIX всё за вечер — и качество лучше, чем я делал сам.',
                    name: 'Артём К.',
                    role: 'Hip-Hop артист',
                    avatar: 'AK',
                    metric: '+340%',
                    metricLabel: 'охват за первый месяц',
                    color: AurixTokens.accent,
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _CaseStudyCard(
                    quote: 'AI анализ показал что мой hook слабый. Переделал — и трек набрал x3 больше сохранений в первую неделю.',
                    name: 'Марина В.',
                    role: 'Pop/R&B',
                    avatar: 'MV',
                    metric: 'x3',
                    metricLabel: 'рост сохранений',
                    color: AurixTokens.aiAccent,
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _CaseStudyCard(
                    quote: 'Наконец-то есть система, а не хаос. Знаю что делать каждый день. Попал в 2 плейлиста за месяц.',
                    name: 'Денис Р.',
                    role: 'Электронная музыка',
                    avatar: 'DP',
                    metric: '2',
                    metricLabel: 'плейлиста за месяц',
                    color: AurixTokens.positive,
                  )),
                ],
              )
            else
              Column(
                children: [
                  _CaseStudyCard(quote: 'Раньше тратил неделю. С AURIX всё за вечер — качество лучше.', name: 'Артём К.', role: 'Hip-Hop артист', avatar: 'AK', metric: '+340%', metricLabel: 'охват', color: AurixTokens.accent),
                  const SizedBox(height: 14),
                  _CaseStudyCard(quote: 'AI показал слабый hook. Переделал — x3 сохранений.', name: 'Марина В.', role: 'Pop/R&B', avatar: 'MV', metric: 'x3', metricLabel: 'сохранений', color: AurixTokens.aiAccent),
                  const SizedBox(height: 14),
                  _CaseStudyCard(quote: 'Попал в 2 плейлиста за месяц. Система работает.', name: 'Денис Р.', role: 'Электронная музыка', avatar: 'DP', metric: '2', metricLabel: 'плейлиста', color: AurixTokens.positive),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Animated stat badge with counting animation ────────────────────

class _AnimatedStatBadge extends StatefulWidget {
  final int endValue;
  final String label;
  final IconData icon;
  final Color color;
  final String suffix;
  const _AnimatedStatBadge({required this.endValue, required this.label, required this.icon, required this.color, required this.suffix});

  @override
  State<_AnimatedStatBadge> createState() => _AnimatedStatBadgeState();
}

class _AnimatedStatBadgeState extends State<_AnimatedStatBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutQuart);
    // Start animation after a small delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 165,
        padding: const EdgeInsets.all(20),
        transform: _hover ? (Matrix4.identity()..translate(0.0, -3.0)) : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: widget.color.withValues(alpha: _hover ? 0.08 : 0.05),
          border: Border.all(color: widget.color.withValues(alpha: _hover ? 0.25 : 0.12)),
          boxShadow: [
            if (_hover)
              BoxShadow(
                color: widget.color.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          children: [
            Icon(widget.icon, color: widget.color, size: 24),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final v = (_anim.value * widget.endValue).round();
                final display = widget.suffix == '%' ? '$v${widget.suffix}' : '$v${widget.suffix}';
                return Text(display, style: TextStyle(color: AurixTokens.text, fontSize: 28, fontWeight: FontWeight.w900, fontFeatures: AurixTokens.tabularFigures));
              },
            ),
            const SizedBox(height: 2),
            Text(widget.label, style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Case study card with metric highlight ──────────────────────────

class _CaseStudyCard extends StatefulWidget {
  final String quote;
  final String name;
  final String role;
  final String avatar;
  final String metric;
  final String metricLabel;
  final Color color;
  const _CaseStudyCard({required this.quote, required this.name, required this.role, required this.avatar, required this.metric, required this.metricLabel, required this.color});

  @override
  State<_CaseStudyCard> createState() => _CaseStudyCardState();
}

class _CaseStudyCardState extends State<_CaseStudyCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(22),
        transform: _hover ? (Matrix4.identity()..translate(0.0, -3.0)) : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _hover ? AurixTokens.surface2 : AurixTokens.surface1,
          border: Border.all(color: _hover ? widget.color.withValues(alpha: 0.25) : AurixTokens.stroke(0.10)),
          boxShadow: [
            if (_hover)
              BoxShadow(
                color: widget.color.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metric highlight
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: widget.color.withValues(alpha: 0.08),
                border: Border.all(color: widget.color.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.metric, style: TextStyle(color: widget.color, fontSize: 22, fontWeight: FontWeight.w900, fontFeatures: AurixTokens.tabularFigures)),
                  const SizedBox(width: 8),
                  Text(widget.metricLabel, style: TextStyle(color: widget.color.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Icon(Icons.format_quote_rounded, color: widget.color.withValues(alpha: 0.3), size: 24),
            const SizedBox(height: 8),
            Text(widget.quote, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13.5, height: 1.55, fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [widget.color.withValues(alpha: 0.3), widget.color.withValues(alpha: 0.15)]),
                  ),
                  child: Center(child: Text(widget.avatar, style: const TextStyle(color: AurixTokens.text, fontSize: 11, fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(widget.role, style: TextStyle(color: AurixTokens.micro, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
