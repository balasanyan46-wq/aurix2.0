import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/data/providers/referral_provider.dart';
import 'package:aurix_flutter/design/widgets/section_onboarding.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(referralStatsProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

    return RefreshIndicator(
      color: AurixTokens.accent,
      onRefresh: () async => ref.invalidate(referralStatsProvider),
      child: PremiumPageScaffold(
        title: 'Пригласи друга',
        subtitle: 'Получай 10% от каждого платежа приглашённых — навсегда',
        systemLabel: 'REFERRAL',
        systemColor: AurixTokens.accent,
        children: [
          SectionOnboarding(tip: OnboardingTips.referral),
          statsAsync.when(
            data: (stats) => _ReferralContent(stats: stats, isDesktop: isDesktop),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(60),
                child: CircularProgressIndicator(color: AurixTokens.accent),
              ),
            ),
            error: (e, _) => PremiumSectionCard(
              child: Center(
                child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.danger)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralContent extends StatelessWidget {
  final ReferralStats stats;
  final bool isDesktop;

  const _ReferralContent({required this.stats, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Referral link card
        _ReferralLinkCard(code: stats.code, link: stats.referralLink),
        const SizedBox(height: 16),
        // Stats cards
        if (isDesktop)
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: Icons.people_rounded,
                label: 'Рефералов',
                value: stats.referralsCount.toString(),
                color: AurixTokens.aiAccent,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: Icons.payments_rounded,
                label: 'Всего заработано',
                value: '${stats.totalEarned} \u20BD',
                color: AurixTokens.positive,
              )),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Текущий баланс',
                value: '${stats.currentBalance} \u20BD',
                color: AurixTokens.accent,
              )),
            ],
          )
        else ...[
          _StatCard(
            icon: Icons.people_rounded,
            label: 'Рефералов',
            value: stats.referralsCount.toString(),
            color: AurixTokens.aiAccent,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _StatCard(
                icon: Icons.payments_rounded,
                label: 'Заработано',
                value: '${stats.totalEarned} \u20BD',
                color: AurixTokens.positive,
              )),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Баланс',
                value: '${stats.currentBalance} \u20BD',
                color: AurixTokens.accent,
              )),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // How it works
        _HowItWorksCard(),
        const SizedBox(height: 16),
        // Recent rewards
        if (stats.recentRewards.isNotEmpty) ...[
          _RewardsHistoryCard(rewards: stats.recentRewards),
          const SizedBox(height: 16),
        ],
        // Referral list
        if (stats.referrals.isNotEmpty)
          _ReferralsListCard(referrals: stats.referrals),
      ],
    );
  }
}

class _ReferralLinkCard extends StatelessWidget {
  final String code;
  final String link;

  const _ReferralLinkCard({required this.code, required this.link});

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      glowColor: AurixTokens.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AurixTokens.accent.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.link_rounded, color: AurixTokens.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Твоя реферальная ссылка', style: TextStyle(
                      fontFamily: AurixTokens.fontHeading,
                      color: AurixTokens.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    )),
                    Text('Код: $code', style: const TextStyle(
                      color: AurixTokens.muted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AurixTokens.surface1,
              borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
              border: Border.all(color: AurixTokens.stroke(0.18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    link,
                    style: TextStyle(
                      fontFamily: AurixTokens.fontMono,
                      color: AurixTokens.text,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ссылка скопирована!'),
                          backgroundColor: AurixTokens.positive,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Копировать'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AurixTokens.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
                      ),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(
                  fontFamily: AurixTokens.fontHeading,
                  color: AurixTokens.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
                Text(label, style: const TextStyle(
                  color: AurixTokens.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  static const _steps = [
    ('Поделись ссылкой', 'Отправь реферальную ссылку друзьям-артистам', Icons.share_rounded),
    ('Друг регистрируется', 'Новый пользователь привязывается к твоему аккаунту', Icons.person_add_rounded),
    ('Получай 10% навсегда', 'С каждого платежа реферала ты получаешь пассивный доход', Icons.trending_up_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'Как это работает',
            subtitle: '3 простых шага к пассивному доходу',
          ),
          const SizedBox(height: 16),
          ...List.generate(_steps.length, (i) {
            final (title, desc, icon) = _steps[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i < _steps.length - 1 ? 12 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AurixTokens.accent.withValues(alpha: 0.1),
                      border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.25)),
                    ),
                    child: Center(child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontHeading,
                        color: AurixTokens.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(
                          fontFamily: AurixTokens.fontHeading,
                          color: AurixTokens.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )),
                        const SizedBox(height: 2),
                        Text(desc, style: const TextStyle(
                          color: AurixTokens.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(icon, color: AurixTokens.accent.withValues(alpha: 0.4), size: 20),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RewardsHistoryCard extends StatelessWidget {
  final List<ReferralReward> rewards;

  const _RewardsHistoryCard({required this.rewards});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yy HH:mm');
    return PremiumSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'История начислений',
          ),
          const SizedBox(height: 12),
          ...rewards.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AurixTokens.positive.withValues(alpha: 0.1),
                  ),
                  child: const Icon(Icons.add_rounded, color: AurixTokens.positive, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '+${r.amount} \u20BD',
                        style: TextStyle(
                          fontFamily: AurixTokens.fontHeading,
                          color: AurixTokens.positive,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${r.fromName} \u2022 ${_typeLabel(r.type)}',
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Text(
                  df.format(r.date.toLocal()),
                  style: const TextStyle(color: AurixTokens.micro, fontSize: 11),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'subscription': return 'Подписка';
      case 'credits': return 'Кредиты';
      case 'beat_purchase': return 'Покупка бита';
      default: return 'Платёж';
    }
  }
}

class _ReferralsListCard extends StatelessWidget {
  final List<ReferralUser> referrals;

  const _ReferralsListCard({required this.referrals});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yy');
    return PremiumSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeader(
            title: 'Мои рефералы',
            subtitle: '${referrals.length} приглашённых',
          ),
          const SizedBox(height: 12),
          ...referrals.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AurixTokens.aiAccent.withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Text(
                      r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontHeading,
                        color: AurixTokens.aiAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(r.name, style: const TextStyle(
                    color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                Text(
                  df.format(r.joinedAt.toLocal()),
                  style: const TextStyle(color: AurixTokens.micro, fontSize: 11),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
