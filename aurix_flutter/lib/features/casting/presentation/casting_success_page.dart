import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

class CastingSuccessPage extends StatefulWidget {
  const CastingSuccessPage({super.key});
  @override
  State<CastingSuccessPage> createState() => _CastingSuccessPageState();
}

class _CastingSuccessPageState extends State<CastingSuccessPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _opacity = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _c.forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: FadeTransition(
            opacity: _opacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AurixTokens.positive.withValues(alpha: 0.12),
                      border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.3)),
                      boxShadow: [BoxShadow(color: AurixTokens.positive.withValues(alpha: 0.15), blurRadius: 40, spreadRadius: -10)],
                    ),
                    child: const Icon(Icons.check_rounded, color: AurixTokens.positive, size: 42),
                  ),
                ),
                const SizedBox(height: 32),
                const Text('ОПЛАТА ПРОШЛА', textAlign: TextAlign.center, style: TextStyle(
                  fontFamily: AurixTokens.fontDisplay, color: AurixTokens.text,
                  fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5,
                )),
                const SizedBox(height: 16),
                const Text(
                  'Твой слот забронирован!\nМы свяжемся с тобой по телефону для уточнения деталей выступления.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AurixTokens.textSecondary, fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 40),
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
                    gradient: AurixTokens.cardGradient,
                    border: Border.all(color: AurixTokens.stroke(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow('01', 'Участие оплачено и подтверждено'),
                      const SizedBox(height: 14),
                      _InfoRow('02', 'Мы позвоним для уточнения даты'),
                      const SizedBox(height: 14),
                      _InfoRow('03', 'Готовь выступление — это твой шанс'),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // Audience upsell
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
                    color: AurixTokens.aiAccent.withValues(alpha: 0.06),
                    border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.2)),
                  ),
                  child: Column(children: [
                    const Text('ПОЗОВИ СВОИХ', style: TextStyle(
                      fontFamily: AurixTokens.fontHeading, color: AurixTokens.text,
                      fontSize: 16, fontWeight: FontWeight.w800,
                    )),
                    const SizedBox(height: 8),
                    const Text(
                      'Пусть друзья придут поддержать.\nБилет зрителя — 1 000 ₽',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity, height: 44,
                      child: FilledButton(
                        onPressed: () => context.push('/casting/apply?type=audience'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AurixTokens.aiAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('КУПИТЬ БИЛЕТЫ ДЛЯ ДРУЗЕЙ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Share link
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: AurixTokens.cardGradient,
                    border: Border.all(color: AurixTokens.stroke(0.15)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.share_rounded, color: AurixTokens.accent, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Скинь ссылку друзьям', style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13))),
                    GestureDetector(
                      onTap: () {
                        // Copy share link
                        final link = 'https://aurixmusic.ru/casting';
                        // ignore: deprecated_member_use
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Ссылка скопирована'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AurixTokens.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Копировать', style: TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: 260, height: 50,
                  child: FilledButton(
                    onPressed: () => context.go('/home'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AurixTokens.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AurixTokens.radiusButton)),
                    ),
                    child: const Text('ГОТОВО', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String num;
  final String text;
  const _InfoRow(this.num, this.text);
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(num, style: TextStyle(
          fontFamily: AurixTokens.fontMono, color: AurixTokens.muted,
          fontSize: 11, fontWeight: FontWeight.w700,
        )),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 13, height: 1.5))),
      ],
    );
  }
}
