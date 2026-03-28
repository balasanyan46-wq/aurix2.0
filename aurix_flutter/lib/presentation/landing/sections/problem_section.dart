import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class ProblemSection extends StatelessWidget {
  const ProblemSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return LandingSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SectionLabel(text: 'ПРОБЛЕМА'),
          const SizedBox(height: 24),
          Text(
            'Сегодня артист работает вслепую',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: desktop ? 40 : 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: desktop ? 48 : 32),
          // 3 visual cards
          LayoutBuilder(
            builder: (context, constraints) {
              if (desktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(
                      child: _ProblemCard(
                        icon: Icons.help_outline_rounded,
                        title: 'Релиз вслепую',
                        text: 'Ты выпускаешь трек и не знаешь, зайдёт ли он.',
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: _ProblemCard(
                        icon: Icons.shuffle_rounded,
                        title: 'Контент без данных',
                        text: 'Ты снимаешь видео и не понимаешь, что реально работает.',
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: _ProblemCard(
                        icon: Icons.money_off_rounded,
                        title: 'Продвижение без стратегии',
                        text: 'Ты тратишь деньги на рекламу без чёткого плана.',
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: const [
                  _ProblemCard(
                    icon: Icons.help_outline_rounded,
                    title: 'Релиз вслепую',
                    text: 'Ты выпускаешь трек и не знаешь, зайдёт ли он.',
                  ),
                  SizedBox(height: 14),
                  _ProblemCard(
                    icon: Icons.shuffle_rounded,
                    title: 'Контент без данных',
                    text: 'Ты снимаешь видео и не понимаешь, что реально работает.',
                  ),
                  SizedBox(height: 14),
                  _ProblemCard(
                    icon: Icons.money_off_rounded,
                    title: 'Продвижение без стратегии',
                    text: 'Ты тратишь деньги на рекламу без чёткого плана.',
                  ),
                ],
              );
            },
          ),
          SizedBox(height: desktop ? 48 : 32),
          // Transition
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: desktop ? 28 : 20, horizontal: desktop ? 36 : 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  AurixTokens.accent.withValues(alpha: 0.06),
                  AurixTokens.aiAccent.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.12)),
            ),
            child: GradientText(
              'AURIX превращает музыку в систему, а не в удачу.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: desktop ? 22 : 18,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String text;
  const _ProblemCard({required this.icon, required this.title, required this.text});

  @override
  State<_ProblemCard> createState() => _ProblemCardState();
}

class _ProblemCardState extends State<_ProblemCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _hover ? AurixTokens.surface2 : AurixTokens.surface1,
          border: Border.all(
            color: _hover
                ? AurixTokens.danger.withValues(alpha: 0.25)
                : AurixTokens.stroke(0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.35 : 0.2),
              blurRadius: _hover ? 20 : 10,
              offset: const Offset(0, 6),
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
                borderRadius: BorderRadius.circular(12),
                color: AurixTokens.danger.withValues(alpha: 0.08),
                border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.15)),
              ),
              child: Icon(widget.icon, color: AurixTokens.danger.withValues(alpha: 0.7), size: 22),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.text,
              style: TextStyle(
                color: AurixTokens.muted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
