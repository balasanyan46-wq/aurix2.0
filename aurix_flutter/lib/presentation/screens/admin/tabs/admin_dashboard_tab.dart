import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/models/admin_log_model.dart';
import 'package:aurix_flutter/data/models/support_ticket_model.dart';

class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key, this.onGoToTab});
  final void Function(String tabKey)? onGoToTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final releasesAsync = ref.watch(allReleasesAdminProvider);
    final rowsAsync = ref.watch(allReportRowsProvider);
    final logsAsync = ref.watch(adminLogsProvider);
    final ticketsAsync = ref.watch(allTicketsProvider);

    return RefreshIndicator(
      color: AurixTokens.orange,
      onRefresh: () async {
        ref.invalidate(allProfilesProvider);
        ref.invalidate(allReleasesAdminProvider);
        ref.invalidate(allReportRowsProvider);
        ref.invalidate(adminLogsProvider);
        ref.invalidate(allTicketsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ОБЗОР',
              style: TextStyle(
                color: AurixTokens.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),

            // 1. Top stats row
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final cards = [
                profilesAsync.when(
                  data: (profiles) {
                    final now = DateTime.now();
                    final thisMonth = profiles.where((p) =>
                      p.createdAt.year == now.year && p.createdAt.month == now.month
                    ).length;
                    return _StatCard(
                      label: 'ПОЛЬЗОВАТЕЛИ',
                      value: profiles.length.toString(),
                      subtitle: '+$thisMonth за месяц',
                      icon: Icons.people_rounded,
                    );
                  },
                  loading: () => _StatCard(
                    label: 'ПОЛЬЗОВАТЕЛИ',
                    value: '...',
                    subtitle: '',
                    icon: Icons.people_rounded,
                  ),
                  error: (_, __) => _StatCard(
                    label: 'ПОЛЬЗОВАТЕЛИ',
                    value: '—',
                    subtitle: '',
                    icon: Icons.people_rounded,
                  ),
                ),
                releasesAsync.when(
                  data: (releases) {
                    final pending = releases.where((r) => r.status == 'submitted').length;
                    return _StatCard(
                      label: 'РЕЛИЗЫ',
                      value: releases.length.toString(),
                      subtitle: '$pending ожидают модерации',
                      icon: Icons.album_rounded,
                      accentColor: AurixTokens.positive,
                    );
                  },
                  loading: () => _StatCard(
                    label: 'РЕЛИЗЫ',
                    value: '...',
                    subtitle: '',
                    icon: Icons.album_rounded,
                    accentColor: AurixTokens.positive,
                  ),
                  error: (_, __) => _StatCard(
                    label: 'РЕЛИЗЫ',
                    value: '—',
                    subtitle: '',
                    icon: Icons.album_rounded,
                    accentColor: AurixTokens.positive,
                  ),
                ),
                rowsAsync.when(
                  data: (rows) {
                    final total = rows.fold<double>(0, (s, r) => s + r.revenue);
                    final now = DateTime.now();
                    final thisMonth = rows.where((r) =>
                      r.reportDate != null &&
                      r.reportDate!.year == now.year &&
                      r.reportDate!.month == now.month
                    ).fold<double>(0, (s, r) => s + r.revenue);
                    return _StatCard(
                      label: 'ДОХОД',
                      value: '\$${_fmt(total)}',
                      subtitle: '\$${_fmt(thisMonth)} за месяц',
                      icon: Icons.payments_rounded,
                      accentColor: AurixTokens.orange,
                    );
                  },
                  loading: () => _StatCard(
                    label: 'ДОХОД',
                    value: '...',
                    subtitle: '',
                    icon: Icons.payments_rounded,
                    accentColor: AurixTokens.orange,
                  ),
                  error: (_, __) => _StatCard(
                    label: 'ДОХОД',
                    value: '—',
                    subtitle: '',
                    icon: Icons.payments_rounded,
                    accentColor: AurixTokens.orange,
                  ),
                ),
                ticketsAsync.when(
                  data: (tickets) {
                    final open = tickets.where((t) => t.status == 'open').length;
                    return _StatCard(
                      label: 'ТИКЕТЫ',
                      value: tickets.length.toString(),
                      subtitle: '$open открытых',
                      icon: Icons.support_agent_rounded,
                    );
                  },
                  loading: () => _StatCard(
                    label: 'ТИКЕТЫ',
                    value: '...',
                    subtitle: '',
                    icon: Icons.support_agent_rounded,
                  ),
                  error: (_, __) => _StatCard(
                    label: 'ТИКЕТЫ',
                    value: '—',
                    subtitle: '',
                    icon: Icons.support_agent_rounded,
                  ),
                ),
              ];

              if (isWide) {
                return Row(
                  children: cards
                      .map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c)))
                      .toList(),
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: c)).toList(),
              );
            }),

            const SizedBox(height: 32),

            // 2. ТРЕБУЮТ ВНИМАНИЯ (Action Required)
            _SectionHeader('ТРЕБУЮТ ВНИМАНИЯ'),
            const SizedBox(height: 12),
            _buildActionRequiredSection(context, ref, releasesAsync, ticketsAsync, profilesAsync),

            const SizedBox(height: 32),

            // 3. Users by plan breakdown
            _SectionHeader('ПОЛЬЗОВАТЕЛИ ПО ПЛАНАМ'),
            const SizedBox(height: 12),
            profilesAsync.when(
              data: (profiles) => _buildPlanBreakdown(profiles),
              loading: () => _loading(),
              error: (e, _) => _errorWidget(e.toString()),
            ),

            const SizedBox(height: 32),

            // 4. Releases by status breakdown
            _SectionHeader('РЕЛИЗЫ ПО СТАТУСАМ'),
            const SizedBox(height: 12),
            releasesAsync.when(
              data: (releases) => _buildStatusBreakdown(releases, ref),
              loading: () => _loading(),
              error: (e, _) => _errorWidget(e.toString()),
            ),

            const SizedBox(height: 32),

            // 5. Top platforms by revenue
            _SectionHeader('ТОП ПЛАТФОРМ ПО ДОХОДУ'),
            const SizedBox(height: 12),
            rowsAsync.when(
              data: (rows) => _buildTopPlatforms(rows),
              loading: () => _loading(),
              error: (e, _) => _errorWidget(e.toString()),
            ),

            const SizedBox(height: 32),

            // 6. Recent registrations
            _SectionHeader('ПОСЛЕДНИЕ РЕГИСТРАЦИИ'),
            const SizedBox(height: 12),
            profilesAsync.when(
              data: (profiles) => _buildRecentRegistrations(profiles),
              loading: () => _loading(),
              error: (e, _) => _errorWidget(e.toString()),
            ),

            const SizedBox(height: 32),

            // 7. Recent admin actions
            _SectionHeader('ПОСЛЕДНИЕ ДЕЙСТВИЯ'),
            const SizedBox(height: 12),
            logsAsync.when(
              data: (logs) => _buildRecentActions(logs),
              loading: () => _loading(),
              error: (e, _) => _errorWidget(e.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRequiredSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ReleaseModel>> releasesAsync,
    AsyncValue<List<SupportTicketModel>> ticketsAsync,
    AsyncValue<List<ProfileModel>> profilesAsync,
  ) {
    return releasesAsync.when(
      data: (releases) {
        final pendingReleases = releases.where((r) => r.status == 'submitted').length;
        return ticketsAsync.when(
          data: (tickets) {
            final openTickets = tickets.where((t) => t.status == 'open').length;
            return profilesAsync.when(
              data: (profiles) {
                final startPlanUsers = profiles.where((p) => p.plan == 'start').length;
                return _buildCard(
                  child: Column(
                    children: [
                      if (pendingReleases > 0)
                        _ActionItem(
                          icon: Icons.album_rounded,
                          label: 'Релизы ожидают модерации',
                          count: pendingReleases,
                          badgeColor: AurixTokens.orange,
                          onTap: () => onGoToTab?.call('releases'),
                        ),
                      if (openTickets > 0)
                        _ActionItem(
                          icon: Icons.support_agent_rounded,
                          label: 'Открытые тикеты',
                          count: openTickets,
                          badgeColor: Colors.amber,
                          onTap: () => onGoToTab?.call('support'),
                        ),
                      if (startPlanUsers > 0)
                        _ActionItem(
                          icon: Icons.trending_up_rounded,
                          label: 'Пользователи на плане Старт',
                          count: startPlanUsers,
                          badgeColor: AurixTokens.muted,
                          onTap: () => onGoToTab?.call('users'),
                        ),
                      if (pendingReleases == 0 && openTickets == 0 && startPlanUsers == 0)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Всё в порядке',
                            style: TextStyle(color: AurixTokens.muted, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => _loading(),
              error: (_, __) => _emptyCard('Ошибка загрузки'),
            );
          },
          loading: () => _loading(),
          error: (_, __) => _emptyCard('Ошибка загрузки'),
        );
      },
      loading: () => _loading(),
      error: (_, __) => _emptyCard('Ошибка загрузки'),
    );
  }

  Widget _buildPlanBreakdown(List<ProfileModel> profiles) {
    final start = profiles.where((p) => p.plan == 'start').length;
    final breakthrough = profiles.where((p) => p.plan == 'breakthrough').length;
    final empire = profiles.where((p) => p.plan == 'empire').length;

    return Row(
      children: [
        Expanded(
          child: _PlanCard(label: 'Старт', count: start),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlanCard(label: 'Прорыв', count: breakthrough),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlanCard(label: 'Империя', count: empire),
        ),
      ],
    );
  }

  Widget _buildStatusBreakdown(List<ReleaseModel> releases, WidgetRef ref) {
    final statuses = ['draft', 'submitted', 'approved', 'rejected', 'live'];
    final counts = <String, int>{};
    for (final status in statuses) {
      counts[status] = releases.where((r) => r.status == status).length;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((status) {
        final count = counts[status] ?? 0;
        final label = _getStatusLabel(status);
        return _StatusChip(
          label: label,
          count: count,
          status: status,
          onTap: () {
            ref.read(adminReleasesFilterProvider.notifier).state = status;
            onGoToTab?.call('releases');
          },
        );
      }).toList(),
    );
  }

  Widget _buildTopPlatforms(List<ReportRowModel> rows) {
    final platformRevenue = <String, double>{};
    for (final row in rows) {
      if (row.platform != null && row.platform!.isNotEmpty) {
        platformRevenue[row.platform!] = (platformRevenue[row.platform!] ?? 0) + row.revenue;
      }
    }

    final sorted = platformRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top5 = sorted.take(5).toList();

    if (top5.isEmpty) {
      return _emptyCard('Нет данных по платформам');
    }

    return _buildCard(
      child: Column(
        children: top5.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  '\$${_fmt(entry.value)}',
                  style: TextStyle(
                    color: AurixTokens.textSecondary,
                    fontSize: 14,
                    fontFeatures: AurixTokens.tabularFigures,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentRegistrations(List<ProfileModel> profiles) {
    final sorted = List<ProfileModel>.from(profiles)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recent = sorted.take(5).toList();

    if (recent.isEmpty) {
      return _emptyCard('Нет регистраций');
    }

    return _buildCard(
      child: Column(
        children: recent.map((profile) {
          return ListTile(
            dense: true,
            title: Text(
              profile.displayNameOrName,
              style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              profile.email,
              style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
            ),
            trailing: Text(
              DateFormat('dd.MM.yyyy').format(profile.createdAt),
              style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentActions(List<AdminLogModel> logs) {
    final recent = logs.take(5).toList();

    if (recent.isEmpty) {
      return _emptyCard('Нет действий');
    }

    return _buildCard(
      child: Column(
        children: recent.map((log) {
          return ListTile(
            dense: true,
            leading: Icon(Icons.history, color: AurixTokens.muted, size: 18),
            title: Text(
              log.actionLabel,
              style: const TextStyle(color: AurixTokens.text, fontSize: 13),
            ),
            subtitle: Text(
              '${log.targetType} • ${DateFormat('dd.MM HH:mm').format(log.createdAt)}',
              style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  static String _getStatusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Черновик';
      case 'submitted':
        return 'На модерации';
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

  static Widget _loading() => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2),
    ),
  );

  static Widget _errorWidget(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text('Ошибка: $msg', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
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

  static Widget _buildCard({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: AurixTokens.bg1,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AurixTokens.border),
    ),
    child: child,
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AurixTokens.muted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.accentColor,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AurixTokens.text;
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
              Text(
                label,
                style: const TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.badgeColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color badgeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AurixTokens.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AurixTokens.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AurixTokens.tabularFigures,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Text(
                'Перейти',
                style: TextStyle(
                  color: AurixTokens.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AurixTokens.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.count, required this.status, this.onTap});

  final String label;
  final int count;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    switch (status) {
      case 'submitted':
        chipColor = AurixTokens.orange;
        break;
      case 'approved':
      case 'live':
        chipColor = AurixTokens.positive;
        break;
      case 'rejected':
        chipColor = AurixTokens.muted;
        break;
      default:
        chipColor = AurixTokens.textSecondary;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: chipColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: chipColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                count.toString(),
                style: TextStyle(
                  color: chipColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AurixTokens.tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

