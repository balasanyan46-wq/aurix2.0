import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';

class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key});

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

            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final cards = [
                _StatCard(
                  label: 'ПОЛЬЗОВАТЕЛИ',
                  value: profilesAsync.when(
                    data: (p) => p.length.toString(),
                    loading: () => '...',
                    error: (_, __) => '—',
                  ),
                  subtitle: profilesAsync.when(
                    data: (p) {
                      final thisMonth = p.where((u) {
                        final now = DateTime.now();
                        return u.createdAt.year == now.year && u.createdAt.month == now.month;
                      }).length;
                      return '+$thisMonth за месяц';
                    },
                    loading: () => '',
                    error: (_, __) => '',
                  ),
                  icon: Icons.people_rounded,
                ),
                _StatCard(
                  label: 'РЕЛИЗЫ',
                  value: releasesAsync.when(
                    data: (r) => r.length.toString(),
                    loading: () => '...',
                    error: (_, __) => '—',
                  ),
                  subtitle: releasesAsync.when(
                    data: (r) {
                      final submitted = r.where((rel) => rel.status == 'submitted').length;
                      return '$submitted ожидают модерации';
                    },
                    loading: () => '',
                    error: (_, __) => '',
                  ),
                  icon: Icons.album_rounded,
                  accentColor: AurixTokens.positive,
                ),
                _StatCard(
                  label: 'ДОХОД',
                  value: rowsAsync.when(
                    data: (rows) {
                      final total = rows.fold<double>(0, (s, r) => s + r.revenue);
                      return '\$${_fmt(total)}';
                    },
                    loading: () => '...',
                    error: (_, __) => '—',
                  ),
                  subtitle: rowsAsync.when(
                    data: (rows) {
                      final now = DateTime.now();
                      final thisMonth = rows.where((r) =>
                        r.reportDate != null &&
                        r.reportDate!.year == now.year &&
                        r.reportDate!.month == now.month
                      ).fold<double>(0, (s, r) => s + r.revenue);
                      return '\$${_fmt(thisMonth)} за месяц';
                    },
                    loading: () => '',
                    error: (_, __) => '',
                  ),
                  icon: Icons.payments_rounded,
                  accentColor: AurixTokens.orange,
                ),
                _StatCard(
                  label: 'ТИКЕТЫ',
                  value: ticketsAsync.when(
                    data: (t) => t.length.toString(),
                    loading: () => '...',
                    error: (_, __) => '—',
                  ),
                  subtitle: ticketsAsync.when(
                    data: (t) {
                      final open = t.where((tk) => tk.status == 'open').length;
                      return '$open открытых';
                    },
                    loading: () => '',
                    error: (_, __) => '',
                  ),
                  icon: Icons.support_agent_rounded,
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

            _SectionHeader('ПОСЛЕДНИЕ РЕЛИЗЫ'),
            const SizedBox(height: 12),
            releasesAsync.when(
              data: (releases) {
                final recent = releases.take(5).toList();
                if (recent.isEmpty) return _emptyCard('Нет релизов');
                return _buildCard(
                  child: Column(
                    children: recent.map((r) => ListTile(
                      dense: true,
                      title: Text(r.title, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        '${r.artist ?? '—'} • ${r.releaseType} • ${r.status}',
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
                      ),
                      trailing: Text(
                        DateFormat('dd.MM.yyyy').format(r.createdAt),
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                      ),
                    )).toList(),
                  ),
                );
              },
              loading: () => _loading(),
              error: (e, _) => _errorWidget(e.toString()),
            ),

            const SizedBox(height: 24),

            _SectionHeader('ПОСЛЕДНИЕ ДЕЙСТВИЯ'),
            const SizedBox(height: 12),
            logsAsync.when(
              data: (logs) {
                final recent = logs.take(5).toList();
                if (recent.isEmpty) return _emptyCard('Нет действий');
                return _buildCard(
                  child: Column(
                    children: recent.map((log) => ListTile(
                      dense: true,
                      leading: Icon(Icons.history, color: AurixTokens.muted, size: 18),
                      title: Text(log.actionLabel, style: const TextStyle(color: AurixTokens.text, fontSize: 13)),
                      subtitle: Text(
                        '${log.targetType} • ${DateFormat('dd.MM HH:mm').format(log.createdAt)}',
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                      ),
                    )).toList(),
                  ),
                );
              },
              loading: () => _loading(),
              error: (e, _) => _errorWidget(e.toString()),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
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
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
