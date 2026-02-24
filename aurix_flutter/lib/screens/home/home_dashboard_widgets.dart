import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart';
import 'package:aurix_flutter/features/index/presentation/index_notifier.dart';
import 'package:aurix_flutter/features/index_engine/presentation/providers/artist_insights_provider.dart';
import 'package:aurix_flutter/screens/releases/release_create_flow_screen.dart';

/// V2 Hero — Index как доминанта. Bloomberg/Forbes feel.
class HomeIndexHero extends ConsumerWidget {
  final VoidCallback onImproveIndex;
  final VoidCallback onCreateRelease;

  const HomeIndexHero({super.key, required this.onImproveIndex, required this.onCreateRelease});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indexState = ref.watch(indexProvider);
    final data = indexState.data;
    final score = data?.selectedScore;
    final artists = data?.artists ?? [];
    final artistId = data?.selectedArtistId ?? data?.selectedArtist?.id ?? (artists.isEmpty ? '' : artists.first.id);
    final insights = ref.watch(artistInsightsProvider(artistId)).valueOrNull;
    final myIndex = score?.score ?? 612;
    final myRank = score?.rankOverall ?? 24;
    final growth = score?.trendDelta ?? 56;
    final badges = score?.badges ?? [];
    final levelTitle = insights?.level.title ?? artistLevelFromScore(myIndex, myRank).label;
    final levelProgress = insights?.progressToNext ?? 0.0;
    final pointsToNext = insights?.pointsToNext ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        border: Border.all(color: AurixTokens.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AURIX РЕЙТИНГ',
                  style: TextStyle(
                    color: AurixTokens.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$myIndex',
                      style: TextStyle(
                        color: AurixTokens.text,
                        fontSize: 72,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                        fontFeatures: AurixTokens.tabularFigures,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      '${growth >= 0 ? '+' : ''}$growth',
                      style: TextStyle(
                        color: growth >= 0 ? AurixTokens.positive : AurixTokens.muted,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AurixTokens.tabularFigures,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _Tag(label: levelTitle, accent: true),
                    const SizedBox(width: 12),
                    _Tag(label: '#$myRank', accent: false),
                    if (insights != null && insights.badges.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      ...insights.badges.take(2).map((b) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _Tag(label: b.title, accent: true),
                          )),
                    ] else if (badges.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      ...badges.take(2).map((b) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _Tag(label: b, accent: true),
                          )),
                    ],
                  ],
                ),
                if (insights != null && pointsToNext > 0) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: levelProgress,
                            minHeight: 4,
                            backgroundColor: AurixTokens.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(AurixTokens.accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '+$pointsToNext до следующего',
                        style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontFeatures: AurixTokens.tabularFigures),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  children: [
                    FilledButton(
                      onPressed: onImproveIndex,
                      style: FilledButton.styleFrom(
                        backgroundColor: AurixTokens.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      child: const Text('Улучшить индекс'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: onCreateRelease,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Релиз'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AurixTokens.text,
                        side: const BorderSide(color: AurixTokens.border),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final bool accent;

  const _Tag({required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent ? AurixTokens.accent.withValues(alpha: 0.12) : Colors.transparent,
        border: Border.all(color: accent ? AurixTokens.accent.withValues(alpha: 0.4) : AurixTokens.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent ? AurixTokens.accent : AurixTokens.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// V2 Trajectory — лаконичный line chart.
class HomeCareerTrajectory extends StatelessWidget {
  final VoidCallback? onViewIndex;

  const HomeCareerTrajectory({super.key, this.onViewIndex});

  static List<double> _mockData() => [420.0, 458.0, 512.0, 534.0, 568.0, 612.0];

  @override
  Widget build(BuildContext context) {
    final data = _mockData();

    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ТРАЕКТОРИЯ',
                style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2),
              ),
              if (onViewIndex != null)
                TextButton(
                  onPressed: onViewIndex,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text('Подробнее', style: TextStyle(color: AurixTokens.accent, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 80,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (_, c) => CustomPaint(
                painter: _SparklinePainter(values: data, color: AurixTokens.accent),
                size: Size(c.maxWidth, 80),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'При текущем темпе — Top 10 через 3 месяца',
            style: TextStyle(color: AurixTokens.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final span = (max - min).clamp(0.001, double.infinity);
    final stepX = size.width / (values.length - 1).clamp(1, values.length);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - ((values[i] - min) / span) * size.height * 0.9;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.values != values;
}

/// V2 Next Action — один блок, лаконично.
class HomeNextStepAI extends ConsumerWidget {
  final VoidCallback onHowToRise;

  const HomeNextStepAI({super.key, required this.onHowToRise});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(indexProvider).data;
    final artists = data?.artists ?? [];
    final artistId = data?.selectedArtistId ?? data?.selectedArtist?.id ?? (artists.isEmpty ? '' : artists.first.id);
    final insights = ref.watch(artistInsightsProvider(artistId)).valueOrNull;
    final steps = insights?.nextStepPlan.steps ?? [];
    final hasRealSteps = steps.isNotEmpty;

    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'СЛЕДУЮЩИЙ ШАГ',
            style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          if (insights?.nextStepPlan.forecast != null)
            Text(insights!.nextStepPlan.forecast!, style: TextStyle(color: AurixTokens.accent, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (hasRealSteps)
            ...steps.take(3).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_forward_ios, size: 12, color: AurixTokens.muted),
                      const SizedBox(width: 12),
                      Expanded(child: Text(s.title, style: TextStyle(color: AurixTokens.text, fontSize: 14))),
                    ],
                  ),
                )),
          if (!hasRealSteps) ...[
            _StepRow('+12% completion rate'),
            _StepRow('+300 сохранений'),
            _StepRow('1 новый релиз'),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: onHowToRise,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text('Как увеличить индекс', style: TextStyle(color: AurixTokens.accent, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String text;

  const _StepRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.arrow_forward_ios, size: 12, color: AurixTokens.muted),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: AurixTokens.text, fontSize: 14)),
        ],
      ),
    );
  }
}

/// V2 Leaders — компактная сетка.
class HomeLeadersMinimal extends ConsumerWidget {
  final VoidCallback onViewIndex;

  const HomeLeadersMinimal({super.key, required this.onViewIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(indexProvider).data;
    if (data == null || data.scores.isEmpty) return const SizedBox.shrink();

    final top3 = data.scores.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ТОП-3',
              style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2),
            ),
            TextButton(
              onPressed: onViewIndex,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text('Рейтинг', style: TextStyle(color: AurixTokens.accent, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: top3.asMap().entries.map((e) {
            final artist = data.artistFor(e.value.artistId);
            if (artist == null) return const SizedBox.shrink();
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: e.key < 2 ? 12 : 0),
                child: _LeaderRow(
                  rank: e.key + 1,
                  name: artist.name,
                  score: e.value.score,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final int rank;
  final String name;
  final int score;

  const _LeaderRow({required this.rank, required this.name, required this.score});

  @override
  Widget build(BuildContext context) {
    final rankColor = rank == 1 ? const Color(0xFFE8A317) : rank == 2 ? const Color(0xFF9CA3AF) : const Color(0xFFCD7F32);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        border: Border.all(color: AurixTokens.border),
      ),
      child: Row(
        children: [
          Text('#$rank', style: TextStyle(color: rankColor, fontSize: 18, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures)),
          const SizedBox(width: 16),
          Expanded(child: Text(name, style: TextStyle(color: AurixTokens.text, fontSize: 14), overflow: TextOverflow.ellipsis)),
          Text('$score', style: TextStyle(color: AurixTokens.accent, fontSize: 16, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
        ],
      ),
    );
  }
}

/// V2 Trust Banner — блок доверия и безопасности.
class HomeTrustBanner extends StatelessWidget {
  const HomeTrustBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        border: Border.all(color: AurixTokens.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AurixTokens.positive, size: 20),
              const SizedBox(width: 10),
              Text(
                'БЕЗОПАСНОСТЬ И ДОВЕРИЕ',
                style: TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _TrustItem(
                icon: Icons.lock_outline,
                title: 'Ваши релизы защищены',
                desc: 'Все файлы хранятся в зашифрованном облаке с резервным копированием',
              )),
              const SizedBox(width: 16),
              Expanded(child: _TrustItem(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Заработки в безопасности',
                desc: 'Прозрачная система отчётности и выплат без скрытых комиссий',
              )),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _TrustItem(
                icon: Icons.copyright_outlined,
                title: 'Интеллектуальная собственность',
                desc: '100% прав остаётся у вас. Мы не претендуем на авторские права',
              )),
              const SizedBox(width: 16),
              Expanded(child: _TrustItem(
                icon: Icons.gavel_outlined,
                title: 'Юридическая защита',
                desc: 'Готовые договоры и шаблоны для защиты ваших интересов',
              )),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AurixTokens.positive.withValues(alpha: 0.06),
              border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: AurixTokens.positive, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'AURIX — лицензированный дистрибьютор. Ваша музыка, ваши деньги, ваши права. Мы только помогаем вам расти.',
                    style: TextStyle(color: AurixTokens.text, fontSize: 13, height: 1.5),
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

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _TrustItem({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AurixTokens.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AurixTokens.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(color: AurixTokens.muted, fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

/// V2 Active Release — минималистичный статус.
class HomeActiveRelease extends ConsumerWidget {
  final VoidCallback onViewReleases;
  final VoidCallback? onCreateRelease;

  const HomeActiveRelease({super.key, required this.onViewReleases, this.onCreateRelease});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releases = ref.watch(releasesProvider).valueOrNull ?? [];
    final live = releases.where((r) => r.status == 'live').toList();
    final inReview = releases.where((r) => r.status == 'submitted' || r.status == 'in_review').toList();
    final mainRelease = live.isNotEmpty ? live.first : (inReview.isNotEmpty ? inReview.first : releases.isNotEmpty ? releases.first : null);

    if (mainRelease == null) {
      return AurixGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('АКТИВНЫЙ РЕЛИЗ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2)),
            const SizedBox(height: 12),
            Text('Пока нет релизов', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
            if (onCreateRelease != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(onPressed: onCreateRelease, icon: const Icon(Icons.add, size: 18), label: const Text('Создать релиз'), style: TextButton.styleFrom(foregroundColor: AurixTokens.accent)),
            ],
          ],
        ),
      );
    }

    final status = _releaseStatus(mainRelease.status);

    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('АКТИВНЫЙ РЕЛИЗ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: status.color.withValues(alpha: 0.5))),
                child: Text(status.label, style: TextStyle(color: status.color, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(mainRelease.title, style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${mainRelease.releaseType}', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
          const SizedBox(height: 16),
          TextButton(onPressed: onViewReleases, child: Text('Перейти', style: TextStyle(color: AurixTokens.accent, fontSize: 13))),
        ],
      ),
    );
  }

  ({String label, Color color}) _releaseStatus(String s) {
    switch (s) {
      case 'live':
      case 'scheduled':
        return (label: 'Live', color: AurixTokens.positive);
      case 'submitted':
        return (label: 'На проверке', color: AurixTokens.accent);
      default:
        return (label: 'В работе', color: AurixTokens.muted);
    }
  }
}
