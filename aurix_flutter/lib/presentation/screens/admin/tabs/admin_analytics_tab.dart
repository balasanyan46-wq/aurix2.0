import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/models/release_model.dart';

class AdminAnalyticsTab extends ConsumerWidget {
  const AdminAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final releasesAsync = ref.watch(allReleasesAdminProvider);
    final rowsAsync = ref.watch(allReportRowsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'АНАЛИТИКА',
            style: TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            'Агрегированная статистика по всей платформе',
            style: TextStyle(color: AurixTokens.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),

          rowsAsync.when(
            data: (rows) => profilesAsync.when(
              data: (profiles) => releasesAsync.when(
                data: (releases) => _buildContent(rows, profiles, releases),
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2))),
                error: (e, _) => Text('Ошибка загрузки релизов: $e', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2))),
              error: (e, _) => Text('Ошибка загрузки профилей: $e', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2))),
            error: (e, _) => Text('Ошибка загрузки данных: $e', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<ReportRowModel> rows, List<ProfileModel> profiles, List<ReleaseModel> releases) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRevenueOverview(rows),
        const SizedBox(height: 28),
        _buildRevenueByPlatform(rows),
        const SizedBox(height: 28),
        _buildUsersByPlan(profiles),
        const SizedBox(height: 28),
        _buildReleasesByStatus(releases),
        const SizedBox(height: 28),
        _buildMonthlyRevenueTrend(rows),
        const SizedBox(height: 28),
        _buildTopArtistsByRevenue(rows, profiles),
      ],
    );
  }

  Widget _buildRevenueOverview(List<ReportRowModel> rows) {
    final totalRevenue = rows.fold<double>(0, (s, r) => s + r.revenue);
    final totalStreams = rows.fold<int>(0, (s, r) => s + r.streams);
    final now = DateTime.now();
    final thisMonthRevenue = rows
        .where((r) => r.reportDate != null && r.reportDate!.year == now.year && r.reportDate!.month == now.month)
        .fold<double>(0, (s, r) => s + r.revenue);

    final releases = <String>{};
    for (final r in rows) {
      if (r.releaseId != null && r.releaseId!.isNotEmpty) {
        releases.add(r.releaseId!);
      }
    }
    final avgRevenuePerRelease = releases.isNotEmpty ? totalRevenue / releases.length : 0.0;

    final currencies = rows.map((r) => r.currency).toSet();
    final currencySymbol = currencies.length == 1 && currencies.first == 'RUB' ? '₽' : '\$';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ОБЗОР ДОХОДОВ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            final cards = [
              _SummaryCard(label: 'ВСЕГО ДОХОДОВ', value: '$currencySymbol${_formatNumber(totalRevenue)}', icon: Icons.attach_money_rounded),
              _SummaryCard(label: 'ЗА МЕСЯЦ', value: '$currencySymbol${_formatNumber(thisMonthRevenue)}', icon: Icons.calendar_month_rounded, accentColor: AurixTokens.positive),
              _SummaryCard(label: 'СРЕДНЕЕ НА РЕЛИЗ', value: '$currencySymbol${_formatNumber(avgRevenuePerRelease)}', icon: Icons.album_rounded, accentColor: AurixTokens.orange),
              _SummaryCard(label: 'ПРОСЛУШИВАНИЯ', value: _formatInt(totalStreams), icon: Icons.headphones_rounded),
            ];

            if (isWide) {
              return Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList());
            }
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: c)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRevenueByPlatform(List<ReportRowModel> rows) {
    final byPlatform = <String, double>{};
    for (final r in rows) {
      final platform = r.platform ?? 'Unknown';
      byPlatform[platform] = (byPlatform[platform] ?? 0) + r.revenue;
    }
    final sortedPlatforms = byPlatform.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top10 = sortedPlatforms.take(10).toList();
    final totalRevenue = byPlatform.values.fold<double>(0, (s, v) => s + v);

    final currencies = rows.map((r) => r.currency).toSet();
    final currencySymbol = currencies.length == 1 && currencies.first == 'RUB' ? '₽' : '\$';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ДОХОД ПО ПЛАТФОРМАМ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        if (top10.isEmpty)
          _emptyCard('Нет данных')
        else
          _card(
            child: Column(
              children: top10.map((entry) {
                final percentage = totalRevenue > 0 ? (entry.value / totalRevenue * 100) : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$currencySymbol${_formatNumber(entry.value)}',
                            style: const TextStyle(color: AurixTokens.orange, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(color: AurixTokens.muted, fontSize: 12, fontFeatures: AurixTokens.tabularFigures),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AurixTokens.bg2,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: totalRevenue > 0 ? (entry.value / totalRevenue) : 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AurixTokens.orange,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildUsersByPlan(List<ProfileModel> profiles) {
    final byPlan = <String, int>{};
    for (final p in profiles) {
      if (p.role != 'admin') {
        byPlan[p.plan] = (byPlan[p.plan] ?? 0) + 1;
      }
    }
    final totalUsers = byPlan.values.fold<int>(0, (s, v) => s + v);
    final sortedPlans = [
      if (byPlan.containsKey('start')) MapEntry('start', byPlan['start']!),
      if (byPlan.containsKey('breakthrough')) MapEntry('breakthrough', byPlan['breakthrough']!),
      if (byPlan.containsKey('empire')) MapEntry('empire', byPlan['empire']!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ПОЛЬЗОВАТЕЛИ ПО ПЛАНАМ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        if (sortedPlans.isEmpty)
          _emptyCard('Нет данных')
        else
          _card(
            child: Column(
              children: sortedPlans.map((entry) {
                final count = entry.value;
                final percentage = totalUsers > 0 ? (count / totalUsers * 100) : 0.0;
                final planName = _planName(entry.key);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              planName,
                              style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            count.toString(),
                            style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(color: AurixTokens.muted, fontSize: 12, fontFeatures: AurixTokens.tabularFigures),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AurixTokens.bg2,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: totalUsers > 0 ? (count / totalUsers) : 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AurixTokens.positive,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildReleasesByStatus(List<ReleaseModel> releases) {
    final byStatus = <String, int>{};
    for (final r in releases) {
      final status = r.status;
      byStatus[status] = (byStatus[status] ?? 0) + 1;
    }
    final totalReleases = byStatus.values.fold<int>(0, (s, v) => s + v);
    final statuses = ['draft', 'submitted', 'approved', 'rejected', 'live'];
    final sortedStatuses = statuses.where((s) => byStatus.containsKey(s)).map((s) => MapEntry(s, byStatus[s]!)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('РЕЛИЗЫ ПО СТАТУСАМ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        if (sortedStatuses.isEmpty)
          _emptyCard('Нет данных')
        else
          _card(
            child: Column(
              children: sortedStatuses.map((entry) {
                final count = entry.value;
                final percentage = totalReleases > 0 ? (count / totalReleases * 100) : 0.0;
                final statusColor = _statusColor(entry.key);
                final statusLabel = _statusLabel(entry.key);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              statusLabel,
                              style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            count.toString(),
                            style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(color: AurixTokens.muted, fontSize: 12, fontFeatures: AurixTokens.tabularFigures),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AurixTokens.bg2,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: totalReleases > 0 ? (count / totalReleases) : 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildMonthlyRevenueTrend(List<ReportRowModel> rows) {
    final now = DateTime.now();
    final months = <DateTime, double>{};
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      months[month] = 0.0;
    }

    for (final r in rows) {
      if (r.reportDate != null) {
        final month = DateTime(r.reportDate!.year, r.reportDate!.month, 1);
        if (months.containsKey(month)) {
          months[month] = (months[month] ?? 0) + r.revenue;
        }
      }
    }

    final sortedMonths = months.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxRevenue = sortedMonths.isNotEmpty ? sortedMonths.map((e) => e.value).reduce((a, b) => a > b ? a : b) : 1.0;

    final currencies = rows.map((r) => r.currency).toSet();
    final currencySymbol = currencies.length == 1 && currencies.first == 'RUB' ? '₽' : '\$';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ТРЕНД ДОХОДОВ ПО МЕСЯЦАМ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        if (sortedMonths.isEmpty)
          _emptyCard('Нет данных')
        else
          _card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: sortedMonths.map((entry) {
                  final monthLabel = DateFormat('MMM yyyy', 'ru').format(entry.key);
                  final revenue = entry.value;
                  final widthFactor = maxRevenue > 0 ? (revenue / maxRevenue) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              monthLabel,
                              style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '$currencySymbol${_formatNumber(revenue)}',
                              style: const TextStyle(color: AurixTokens.orange, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AurixTokens.bg2,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: widthFactor,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AurixTokens.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopArtistsByRevenue(List<ReportRowModel> rows, List<ProfileModel> profiles) {
    final byUserId = <String, Map<String, dynamic>>{};
    for (final r in rows) {
      if (r.userId != null && r.userId!.isNotEmpty) {
        if (!byUserId.containsKey(r.userId)) {
          byUserId[r.userId!] = {'revenue': 0.0, 'streams': 0};
        }
        byUserId[r.userId!]!['revenue'] = (byUserId[r.userId!]!['revenue'] as double) + r.revenue;
        byUserId[r.userId!]!['streams'] = (byUserId[r.userId!]!['streams'] as int) + r.streams;
      }
    }

    final artistStats = <Map<String, dynamic>>[];
    for (final entry in byUserId.entries) {
      final profile = profiles.firstWhere((p) => p.userId == entry.key, orElse: () => ProfileModel(userId: entry.key, createdAt: DateTime.now(), updatedAt: DateTime.now()));
      artistStats.add({
        'name': profile.displayNameOrName,
        'revenue': entry.value['revenue'] as double,
        'streams': entry.value['streams'] as int,
      });
    }

    artistStats.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    final top5 = artistStats.take(5).toList();

    final currencies = rows.map((r) => r.currency).toSet();
    final currencySymbol = currencies.length == 1 && currencies.first == 'RUB' ? '₽' : '\$';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ТОП АРТИСТОВ ПО ДОХОДУ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        if (top5.isEmpty)
          _emptyCard('Нет данных')
        else
          _card(
            child: Column(
              children: top5.map((artist) {
                final name = artist['name'] as String;
                final revenue = artist['revenue'] as double;
                final streams = artist['streams'] as int;
                return ListTile(
                  dense: true,
                  title: Text(
                    name,
                    style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${_formatInt(streams)} прослушиваний',
                    style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                  ),
                  trailing: Text(
                    '$currencySymbol${_formatNumber(revenue)}',
                    style: const TextStyle(color: AurixTokens.orange, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  String _planName(String plan) {
    switch (plan) {
      case 'start':
        return 'Старт';
      case 'breakthrough':
        return 'Прорыв';
      case 'empire':
        return 'Империя';
      default:
        return plan;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return AurixTokens.muted;
      case 'submitted':
        return Colors.amber;
      case 'approved':
        return AurixTokens.positive;
      case 'rejected':
        return Colors.redAccent;
      case 'live':
        return Colors.blue;
      default:
        return AurixTokens.muted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Черновик';
      case 'submitted':
        return 'Отправлен';
      case 'approved':
        return 'Одобрен';
      case 'rejected':
        return 'Отклонён';
      case 'live':
        return 'Опубликован';
      default:
        return status;
    }
  }

  static String _formatNumber(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  static String _formatInt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  static Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: AurixTokens.bg1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AurixTokens.border),
        ),
        child: child,
      );

  static Widget _emptyCard(String text) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AurixTokens.bg1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AurixTokens.border),
        ),
        child: Center(child: Text(text, style: const TextStyle(color: AurixTokens.muted, fontSize: 13))),
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.icon, this.accentColor});
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AurixTokens.muted),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: accentColor ?? AurixTokens.text,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
