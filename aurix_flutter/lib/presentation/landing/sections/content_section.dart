import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class ContentSection extends StatelessWidget {
  const ContentSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      color: AurixTokens.surface1.withValues(alpha: 0.25),
      child: LandingSection(
        child: SplitCanvas(
          reversed: false,
          left: _ContentCopy(desktop: desktop),
          right: const _ContentCards(),
        ),
      ),
    );
  }
}

class _ContentCopy extends StatelessWidget {
  final bool desktop;
  const _ContentCopy({required this.desktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: desktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        const SectionLabel(text: 'КОНТЕНТ'),
        const SizedBox(height: 24),
        Text(
          'AI генерирует\nидеи контента',
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
          'Не нужно придумывать с нуля. AI анализирует трек и предлагает конкретные идеи для видео, Reels и TikTok под твой стиль.',
          textAlign: desktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(color: AurixTokens.muted, fontSize: 15, height: 1.6),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: desktop ? WrapAlignment.start : WrapAlignment.center,
          children: const [
            _FormatTag('TikTok'),
            _FormatTag('Reels'),
            _FormatTag('Shorts'),
            _FormatTag('Stories'),
          ],
        ),
      ],
    );
  }
}

class _FormatTag extends StatelessWidget {
  final String label;
  const _FormatTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AurixTokens.accent.withValues(alpha: 0.06),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.16)),
      ),
      child: Text(label, style: TextStyle(color: AurixTokens.accentWarm, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Floating content idea cards ─────────────────────────────────

class _ContentCards extends StatelessWidget {
  const _ContentCards();

  static const _ideas = [
    _Idea(
      Icons.movie_creation_outlined,
      'TikTok: Ночная поездка',
      'Атмосферное видео с ночной поездкой по городу. Замедленные кадры + bass-drop момент.',
      AurixTokens.accent,
    ),
    _Idea(
      Icons.phone_android_rounded,
      'Reels: Студийная сессия',
      'Behind-the-scenes: процесс записи с лупами и битами. Сырой, честный контент.',
      AurixTokens.aiAccent,
    ),
    _Idea(
      Icons.mic_rounded,
      'Short: Тизер текста',
      'Текст на экране поверх визуала. Самая сильная строчка трека как hook.',
      AurixTokens.accent,
    ),
    _Idea(
      Icons.local_fire_department_rounded,
      'Story: Обратный отсчёт',
      'Серия из 3 Stories с обратным отсчётом до релиза. Сниппет + голосование.',
      AurixTokens.aiAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _ideas.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _IdeaCard(idea: _ideas[i], index: i),
        ],
      ],
    );
  }
}

class _Idea {
  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  const _Idea(this.icon, this.title, this.description, this.accentColor);
}

class _IdeaCard extends StatefulWidget {
  final _Idea idea;
  final int index;
  const _IdeaCard({required this.idea, required this.index});

  @override
  State<_IdeaCard> createState() => _IdeaCardState();
}

class _IdeaCardState extends State<_IdeaCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.idea.accentColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _hover ? AurixTokens.surface2 : AurixTokens.surface1,
          border: Border.all(color: _hover ? c.withValues(alpha: 0.2) : AurixTokens.stroke(0.08)),
          boxShadow: [
            if (_hover)
              BoxShadow(color: c.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: c.withValues(alpha: 0.10),
              ),
              child: Icon(widget.idea.icon, color: c, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.idea.title,
                    style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.idea.description,
                    style: TextStyle(color: AurixTokens.muted, fontSize: 12.5, height: 1.5),
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
