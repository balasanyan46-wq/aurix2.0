import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

/// Final CTA: urgency + bonus + closing punch.
class NewFinalCtaSection extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onLogin;
  const NewFinalCtaSection({super.key, required this.onRegister, required this.onLogin});

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
            AurixTokens.accent.withValues(alpha: 0.04),
            AurixTokens.aiAccent.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: LandingSection(
        padding: EdgeInsets.symmetric(
          horizontal: desktop ? 40 : 20,
          vertical: desktop ? 100 : 64,
        ),
        child: Column(
          children: [
            // Urgency badge
            _UrgencyBadge(),
            const SizedBox(height: 28),

            // Punch line
            Text(
              'Хватит делать\nмузыку вслепую.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AurixTokens.text,
                fontSize: desktop ? 52 : 34,
                fontWeight: FontWeight.w900,
                height: 1.08,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 12),
            GradientText(
              'Включи систему.',
              style: TextStyle(
                fontSize: desktop ? 52 : 34,
                fontWeight: FontWeight.w900,
                height: 1.08,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AI анализ, стратегия, контент, рост —\nвсё в одном инструменте.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AurixTokens.muted, fontSize: desktop ? 17 : 15, height: 1.6),
            ),
            const SizedBox(height: 36),

            // Bonus card
            Container(
              constraints: BoxConstraints(maxWidth: desktop ? 480 : double.infinity),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AurixTokens.aiAccent.withValues(alpha: 0.08),
                    AurixTokens.accent.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.card_giftcard_rounded, size: 20, color: AurixTokens.aiAccent),
                      const SizedBox(width: 10),
                      Text('Бонус при регистрации', style: TextStyle(color: AurixTokens.aiAccent, fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _BonusItem(icon: Icons.auto_awesome_rounded, text: '50 AI кредитов'),
                      const SizedBox(width: 20),
                      _BonusItem(icon: Icons.image_rounded, text: '3 обложки бесплатно'),
                      const SizedBox(width: 20),
                      _BonusItem(icon: Icons.analytics_rounded, text: '5 анализов треков'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Wrap(
              spacing: 14,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                PrimaryCta(label: 'Создать аккаунт бесплатно', onTap: onRegister),
                OutlineCta(label: 'Уже есть аккаунт', onTap: onLogin),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, size: 14, color: AurixTokens.positive.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Text(
                  'Без привязки карты  ·  Отмена в любой момент  ·  Старт за 30 секунд',
                  style: TextStyle(color: AurixTokens.micro, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BonusItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _BonusItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AurixTokens.text.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// Urgency badge with pulsing dot
class _UrgencyBadge extends StatefulWidget {
  @override
  State<_UrgencyBadge> createState() => _UrgencyBadgeState();
}

class _UrgencyBadgeState extends State<_UrgencyBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AurixTokens.danger.withValues(alpha: 0.06 + _ctrl.value * 0.04),
            border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.2 + _ctrl.value * 0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AurixTokens.danger,
                  boxShadow: [
                    BoxShadow(
                      color: AurixTokens.danger.withValues(alpha: 0.4 + _ctrl.value * 0.4),
                      blurRadius: 6 + _ctrl.value * 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Осталось 47 мест с бесплатным стартом',
                style: TextStyle(color: AurixTokens.danger, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Footer: minimal, clean.
class NewLandingFooter extends StatelessWidget {
  const NewLandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AurixTokens.stroke(0.06))),
      ),
      child: Center(
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AurixTokens.accent, AurixTokens.aiAccent],
              ).createShader(bounds),
              child: const Text(
                'AURIX',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'AI Operating System for Artists',
              style: TextStyle(color: AurixTokens.micro, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _FooterLink('Политика конфиденциальности', '/legal/privacy'),
                _FooterLink('Условия использования', '/legal/terms'),
                _FooterLink('Контакт', 'mailto:support@aurixmusic.ru'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '© ${DateTime.now().year} AURIX. Все права защищены.',
              style: TextStyle(color: AurixTokens.micro.withValues(alpha: 0.6), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String label;
  final String href;
  const _FooterLink(this.label, this.href);

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {},
        child: Text(
          widget.label,
          style: TextStyle(
            color: _hover ? AurixTokens.textSecondary : AurixTokens.micro,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
