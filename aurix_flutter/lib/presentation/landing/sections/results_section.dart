import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class ResultsSection extends StatelessWidget {
  const ResultsSection({super.key});

  static const _results = [
    _Result(Icons.blur_on_rounded, 'Меньше хаоса', 'Все инструменты и данные в одном месте — не нужно собирать информацию по крупицам.'),
    _Result(Icons.psychology_outlined, 'Больше понимания', 'Понятные метрики вместо догадок. Знаешь, что работает и почему.'),
    _Result(Icons.map_outlined, 'Понятный план', 'AI строит стратегию продвижения — шаг за шагом, под твой стиль.'),
    _Result(Icons.lightbulb_outline_rounded, 'Идеи контента', 'Готовые концепции для Reels, TikTok, Shorts — не нужно придумывать с нуля.'),
    _Result(Icons.verified_outlined, 'Уверенность', 'Данные и прогнозы дают ощущение контроля перед релизом.'),
    _Result(Icons.trending_up_rounded, 'Системный рост', 'Не разовый хайп, а стратегия развития на длинной дистанции.'),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return LandingSection(
      child: Column(
        children: [
          const SectionLabel(text: 'РЕЗУЛЬТАТ'),
          const SizedBox(height: 20),
          Text(
            'Что получает артист',
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
            'Не просто функции — результат для карьеры.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.muted, fontSize: 14),
          ),
          const SizedBox(height: 48),
          _buildGrid(desktop),
        ],
      ),
    );
  }

  Widget _buildGrid(bool desktop) {
    final cols = desktop ? 3 : 1;
    final rows = <Widget>[];
    for (var i = 0; i < _results.length; i += cols) {
      final slice = _results.sublist(i, i + cols > _results.length ? _results.length : i + cols);
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < slice.length; j++) ...[
              if (j > 0) const SizedBox(width: 16),
              Expanded(child: _ResultTile(data: slice[j])),
            ],
            if (slice.length < cols)
              for (var k = 0; k < cols - slice.length; k++) ...[
                const SizedBox(width: 16),
                const Expanded(child: SizedBox.shrink()),
              ],
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _Result {
  final IconData icon;
  final String title, text;
  const _Result(this.icon, this.title, this.text);
}

class _ResultTile extends StatelessWidget {
  final _Result data;
  const _ResultTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AurixTokens.accent.withValues(alpha: 0.08),
            ),
            child: Icon(data.icon, color: AurixTokens.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  data.text,
                  style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
