import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class DemoSection extends StatefulWidget {
  final VoidCallback onRegister;
  const DemoSection({super.key, required this.onRegister});

  @override
  State<DemoSection> createState() => _DemoSectionState();
}

class _DemoSectionState extends State<DemoSection> with SingleTickerProviderStateMixin {
  int? _selected;
  bool _showResult = false;
  late final AnimationController _resultAnim;

  @override
  void initState() {
    super.initState();
    _resultAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _resultAnim.dispose();
    super.dispose();
  }

  static const _tracks = [
    _TrackEntry('Travis Scott', 'FE!N', genre: 'Trap / Rage', emotion: 'Агрессия, энергия', vibe: 'Хайповая толпа, фестивали', energy: 92, potential: 88, strategy: 'Максимум коротких клипов с bass-drop моментами в первые 48 часов'),
    _TrackEntry('Drake', 'One Dance', genre: 'Afrobeat / Pop', emotion: 'Лёгкость, радость', vibe: 'Массовая, танцевальная', energy: 74, potential: 95, strategy: 'Виральные танцевальные челленджи + плейлисты настроения'),
    _TrackEntry('Miyagi', 'Minor', genre: 'Reggae / Hip-Hop', emotion: 'Меланхолия, глубина', vibe: 'Думающая, лояльная', energy: 58, potential: 82, strategy: 'Атмосферные визуалы + текстовые цитаты + плейлисты для вечера'),
    _TrackEntry('Скриптонит', 'Положение', genre: 'Cloud Rap / R&B', emotion: 'Тревога, притяжение', vibe: 'Нишевая, продвинутая', energy: 65, potential: 79, strategy: 'Эстетика ночного города + коллабы с визуальными артистами'),
    _TrackEntry('Ice Spice', 'Munch', genre: 'Drill / Hip-Hop', emotion: 'Дерзость, уверенность', vibe: 'Gen-Z, вайбовая', energy: 80, potential: 84, strategy: 'Мемы + quick-cut Reels с attitude моментами'),
    _TrackEntry('Playboi Carti', 'Sky', genre: 'Experimental Trap', emotion: 'Эйфория, свобода', vibe: 'Культовая, альтернативная', energy: 85, potential: 86, strategy: 'Эстетические видео + fan-culture контент'),
  ];

  void _select(int idx) {
    setState(() {
      _selected = idx;
      _showResult = false;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _showResult = true);
        _resultAnim.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return LandingSection(
      child: Column(
        children: [
          const SectionLabel(text: 'ПОПРОБУЙ'),
          const SizedBox(height: 20),
          Text(
            'Выбери трек — увидь AI-анализ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: desktop ? 36 : 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Реальные результаты. Не рандом, не имитация.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.muted, fontSize: 14),
          ),
          const SizedBox(height: 40),
          // Track selector
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < _tracks.length; i++)
                _TrackChip(
                  artist: _tracks[i].artist,
                  track: _tracks[i].track,
                  selected: _selected == i,
                  onTap: () => _select(i),
                ),
            ],
          ),
          const SizedBox(height: 36),
          // Result
          if (_selected != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _showResult
                  ? FadeTransition(
                      opacity: CurvedAnimation(parent: _resultAnim, curve: Curves.easeOut),
                      child: _ResultCard(
                        data: _tracks[_selected!],
                        onCta: widget.onRegister,
                      ),
                    )
                  : const _AnalyzingIndicator(),
            ),
        ],
      ),
    );
  }
}

class _TrackEntry {
  final String artist, track, genre, emotion, vibe, strategy;
  final int energy, potential;
  const _TrackEntry(this.artist, this.track, {
    required this.genre, required this.emotion, required this.vibe,
    required this.energy, required this.potential, required this.strategy,
  });
}

class _TrackChip extends StatefulWidget {
  final String artist, track;
  final bool selected;
  final VoidCallback onTap;
  const _TrackChip({required this.artist, required this.track, required this.selected, required this.onTap});

  @override
  State<_TrackChip> createState() => _TrackChipState();
}

class _TrackChipState extends State<_TrackChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _hover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.selected
                ? AurixTokens.accent.withValues(alpha: 0.12)
                : (active ? AurixTokens.surface2 : AurixTokens.surface1),
            border: Border.all(
              color: widget.selected
                  ? AurixTokens.accent.withValues(alpha: 0.4)
                  : AurixTokens.stroke(active ? 0.18 : 0.10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.artist,
                style: TextStyle(
                  color: widget.selected ? AurixTokens.accent : AurixTokens.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                ' — ${widget.track}',
                style: TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyzingIndicator extends StatelessWidget {
  const _AnalyzingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AurixTokens.accent.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Анализирую...',
            style: TextStyle(color: AurixTokens.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final _TrackEntry data;
  final VoidCallback onCta;
  const _ResultCard({required this.data, required this.onCta});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(desktop ? 32 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AurixTokens.surface1,
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AurixTokens.accent.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AurixTokens.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                '${data.artist} — ${data.track}',
                style: const TextStyle(
                  color: AurixTokens.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: desktop ? 32 : 16,
            runSpacing: 16,
            children: [
              _ResultItem('Жанр', data.genre),
              _ResultItem('Эмоция', data.emotion),
              _ResultItem('Аудитория', data.vibe),
              _ResultItem('Энергия', '${data.energy} / 100'),
              _ResultItem('Потенциал', '${data.potential} / 100'),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AurixTokens.accent.withValues(alpha: 0.06),
              border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Рекомендация',
                  style: TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  data.strategy,
                  style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: PrimaryCta(label: 'Получить полный анализ', onTap: onCta),
          ),
        ],
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final String label, value;
  const _ResultItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AurixTokens.micro, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
