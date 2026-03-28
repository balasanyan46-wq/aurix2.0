import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

/// Pain section: Hit the artist's psychology — why they're not growing.
class PainSection extends StatelessWidget {
  const PainSection({super.key});

  static const _pains = [
    _PainItem(
      icon: Icons.casino_rounded,
      title: 'Выпускаешь вслепую',
      desc: 'Ты не знаешь, зайдёт трек или нет. Каждый релиз — как рулетка. Ты надеешься на удачу, а не на данные.',
      accent: Color(0xFFFF5F57),
    ),
    _PainItem(
      icon: Icons.videocam_off_rounded,
      title: 'Контент без стратегии',
      desc: 'Ты тратишь часы на reels, обложки и посты. Но без понимания что работает — это просто шум в ленте.',
      accent: Color(0xFFFFBD2E),
    ),
    _PainItem(
      icon: Icons.money_off_rounded,
      title: 'Бюджет утекает в никуда',
      desc: 'Промо, реклама, дистрибуция — ты платишь, но не видишь роста. Деньги уходят, а аудитория не приходит.',
      accent: Color(0xFFFF6A8A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return LandingSection(
      child: Column(
        children: [
          const SectionLabel(text: 'ПРОБЛЕМА', color: Color(0xFFFF5F57)),
          const SizedBox(height: 20),
          Text(
            'Почему у тебя не растёт',
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
            '90% артистов делают одни и те же ошибки.\nНе потому что бездарны — потому что нет системы.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.muted, fontSize: desktop ? 16 : 14, height: 1.6),
          ),
          const SizedBox(height: 48),
          desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _pains.length; i++) ...[
                      Expanded(child: _PainCard(item: _pains[i])),
                      if (i < _pains.length - 1) const SizedBox(width: 20),
                    ],
                  ],
                )
              : Column(
                  children: _pains.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _PainCard(item: p),
                  )).toList(),
                ),
        ],
      ),
    );
  }
}

class _PainItem {
  final IconData icon;
  final String title;
  final String desc;
  final Color accent;
  const _PainItem({required this.icon, required this.title, required this.desc, required this.accent});
}

class _PainCard extends StatefulWidget {
  final _PainItem item;
  const _PainCard({required this.item});

  @override
  State<_PainCard> createState() => _PainCardState();
}

class _PainCardState extends State<_PainCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.item.accent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: _hover ? c.withValues(alpha: 0.06) : AurixTokens.surface1,
          border: Border.all(color: _hover ? c.withValues(alpha: 0.25) : AurixTokens.stroke(0.10)),
          boxShadow: [
            BoxShadow(
              color: _hover ? c.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.2),
              blurRadius: _hover ? 30 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: c.withValues(alpha: 0.12),
              ),
              child: Icon(widget.item.icon, color: c, size: 24),
            ),
            const SizedBox(height: 18),
            Text(
              widget.item.title,
              style: const TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w800, height: 1.2),
            ),
            const SizedBox(height: 10),
            Text(
              widget.item.desc,
              style: TextStyle(color: AurixTokens.muted, fontSize: 13.5, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
