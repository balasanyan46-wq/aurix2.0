import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class CapabilitiesSection extends StatelessWidget {
  const CapabilitiesSection({super.key});

  static const _items = [
    _Cap(
      icon: Icons.graphic_eq_rounded,
      title: 'AI-анализ трека',
      text: 'Разбор жанра, энергии, настроения и продакшн-особенностей за секунды.',
      color: AurixTokens.accent,
    ),
    _Cap(
      icon: Icons.show_chart_rounded,
      title: 'Прогноз потенциала',
      text: 'Оценка вероятности сильного результата ещё до релиза.',
      color: AurixTokens.aiAccent,
    ),
    _Cap(
      icon: Icons.route_rounded,
      title: 'AI-стратегия продвижения',
      text: 'Персональный план промо: когда, где и как продвигать трек.',
      color: AurixTokens.accent,
    ),
    _Cap(
      icon: Icons.fingerprint_rounded,
      title: 'DNA артиста',
      text: 'Уникальный профиль: жанр, стиль, аудитория, вектор роста.',
      color: AurixTokens.aiAccent,
    ),
    _Cap(
      icon: Icons.videocam_outlined,
      title: 'Контент-идеи',
      text: 'Готовые идеи для TikTok, Reels и Shorts под твой стиль и трек.',
      color: AurixTokens.accent,
    ),
    _Cap(
      icon: Icons.groups_outlined,
      title: 'Понимание аудитории',
      text: 'Кто слушает, что цепляет, как расти — данные вместо догадок.',
      color: AurixTokens.aiAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return LandingSection(
      child: Column(
        children: [
          const SectionLabel(text: 'ВОЗМОЖНОСТИ'),
          const SizedBox(height: 20),
          Text(
            'Что даёт AURIX',
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
            'Каждый инструмент работает на результат, а не на красивые графики.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 48),
          _buildGrid(context, desktop),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, bool desktop) {
    final cols = desktop ? 3 : (MediaQuery.sizeOf(context).width >= 640 ? 2 : 1);
    final rows = <Widget>[];
    for (var i = 0; i < _items.length; i += cols) {
      final slice = _items.sublist(i, i + cols > _items.length ? _items.length : i + cols);
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < slice.length; j++) ...[
              if (j > 0) const SizedBox(width: 16),
              Expanded(child: _CapCard(data: slice[j])),
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

class _Cap {
  final IconData icon;
  final String title;
  final String text;
  final Color color;
  const _Cap({required this.icon, required this.title, required this.text, required this.color});
}

class _CapCard extends StatefulWidget {
  final _Cap data;
  const _CapCard({required this.data});

  @override
  State<_CapCard> createState() => _CapCardState();
}

class _CapCardState extends State<_CapCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.data.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _hover ? AurixTokens.surface2 : AurixTokens.surface1,
          border: Border.all(
            color: _hover ? c.withValues(alpha: 0.22) : AurixTokens.stroke(0.10),
          ),
          boxShadow: [
            if (_hover)
              BoxShadow(
                color: c.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: c.withValues(alpha: _hover ? 0.28 : 0.16)),
              ),
              child: Icon(widget.data.icon, color: c, size: 22),
            ),
            const SizedBox(height: 18),
            Text(
              widget.data.title,
              style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.data.text,
              style: TextStyle(
                color: AurixTokens.muted,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
