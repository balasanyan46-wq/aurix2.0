import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';

/// Safely parse a value that may be int, String, or null to int.
int _safeInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key, this.onGoToTab});
  final void Function(String tabKey)? onGoToTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(adminDashboardProvider);
    final dauAsync = ref.watch(adminDauProvider);
    final eventsAsync = ref.watch(adminEventsBreakdownProvider);
    final aiAsync = ref.watch(adminAiInsightsProvider);
    final aiActionsAsync = ref.watch(adminAiActionsProvider);
    final billingAsync = ref.watch(adminBillingStatsProvider);
    final signalsAsync = ref.watch(adminSignalsProvider);

    return RefreshIndicator(
      color: AurixTokens.orange,
      onRefresh: () async {
        ref.invalidate(adminSignalsProvider);
        ref.invalidate(adminDashboardProvider);
        ref.invalidate(adminDauProvider);
        ref.invalidate(adminEventsBreakdownProvider);
        ref.invalidate(adminAiInsightsProvider);
        ref.invalidate(adminAiActionsProvider);
        ref.invalidate(adminBillingStatsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: [AurixTokens.accent, AurixTokens.accent.withValues(alpha: 0.6)]),
                  ),
                  child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Панель управления', style: TextStyle(
                      fontFamily: AurixTokens.fontHeading,
                      color: AurixTokens.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    )),
                    Text('Обзор платформы в реальном времени', style: TextStyle(
                      color: AurixTokens.muted, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── SIGNALS — "Что происходит сейчас" ────────
            signalsAsync.when(
              data: (data) => data.signals.isEmpty
                  ? const SizedBox.shrink()
                  : _SignalsBlock(signals: data.signals, onGoToUser: (id) {
                      final uid = int.tryParse(id);
                      if (uid != null) {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => _UserQuickAction(userId: uid),
                        ));
                      }
                    }),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Monetization targets ──────────────────────
            signalsAsync.when(
              data: (data) => data.monetizationTargets.isEmpty
                  ? const SizedBox.shrink()
                  : _MonetizationBlock(targets: data.monetizationTargets),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Retention targets ─────────────────────────
            signalsAsync.when(
              data: (data) => data.retentionTargets.isEmpty
                  ? const SizedBox.shrink()
                  : _RetentionBlock(targets: data.retentionTargets),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // ── KPI cards ────────────────────────────────
            dashAsync.when(
              data: (d) => _buildKpiCards(context, d, ref),
              loading: () => _loading(),
              error: (e, _) => _errorWidget(e.toString()),
            ),

            const SizedBox(height: 32),

            // ── DAU chart ────────────────────────────────
            _SectionHeader('АКТИВНОСТЬ (DAU — 30 ДНЕЙ)'),
            const SizedBox(height: 12),
            dauAsync.when(
              data: (rows) => _buildDauChart(rows),
              loading: () => _loading(),
              error: (_, __) => _emptyCard('Нет данных'),
            ),

            const SizedBox(height: 32),

            // ── Event breakdown ──────────────────────────
            _SectionHeader('СОБЫТИЯ (30 ДНЕЙ)'),
            const SizedBox(height: 12),
            eventsAsync.when(
              data: (rows) => _buildEventsBreakdown(rows),
              loading: () => _loading(),
              error: (_, __) => _emptyCard('Нет данных'),
            ),

            const SizedBox(height: 32),

            // ── AI Insights ──────────────────────────────
            _SectionHeader('AI АНАЛИТИКА'),
            const SizedBox(height: 12),
            aiAsync.when(
              data: (ai) => _buildAiInsights(ai, ref),
              loading: () => _buildCard(
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.accent)),
                      SizedBox(width: 12),
                      Text('AI анализирует платформу...', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              error: (_, __) => _emptyCard('AI аналитика недоступна'),
            ),

            const SizedBox(height: 32),

            // ── AI Actions (operator) ─────────────────────
            _SectionHeader('AI ОПЕРАТОР'),
            const SizedBox(height: 12),
            aiActionsAsync.when(
              data: (aiData) => _AiActionsCard(data: aiData),
              loading: () => _buildCard(
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange)),
                      SizedBox(width: 12),
                      Text('AI анализирует паттерны...', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              error: (_, __) => _emptyCard('AI оператор недоступен'),
            ),

            const SizedBox(height: 32),

            // ── Billing stats ─────────────────────────────
            _SectionHeader('МОНЕТИЗАЦИЯ'),
            const SizedBox(height: 12),
            billingAsync.when(
              data: (stats) => _buildBillingStats(stats),
              loading: () => _loading(),
              error: (_, __) => _emptyCard('Нет данных'),
            ),

            const SizedBox(height: 32),

            // ── Releases by status ───────────────────────
            _SectionHeader('РЕЛИЗЫ ПО СТАТУСАМ'),
            const SizedBox(height: 12),
            dashAsync.when(
              data: (d) => _buildStatusBreakdown(d, ref),
              loading: () => _loading(),
              error: (e, _) => _emptyCard('Ошибка загрузки'),
            ),

            const SizedBox(height: 32),

            // ── Users by plan ────────────────────────────
            _SectionHeader('ПОЛЬЗОВАТЕЛИ ПО ПЛАНАМ'),
            const SizedBox(height: 12),
            dashAsync.when(
              data: (d) => _buildPlanBreakdown(d),
              loading: () => _loading(),
              error: (e, _) => _emptyCard('Ошибка загрузки'),
            ),

            const SizedBox(height: 32),

            // ── Recent users ─────────────────────────────
            _SectionHeader('ПОСЛЕДНИЕ РЕГИСТРАЦИИ'),
            const SizedBox(height: 12),
            dashAsync.when(
              data: (d) => _buildRecentUsers(d),
              loading: () => _loading(),
              error: (e, _) => _emptyCard('Ошибка загрузки'),
            ),

            const SizedBox(height: 32),

            // ── Recent admin actions ─────────────────────
            _SectionHeader('ПОСЛЕДНИЕ ДЕЙСТВИЯ'),
            const SizedBox(height: 12),
            dashAsync.when(
              data: (d) => _buildRecentActions(d),
              loading: () => _loading(),
              error: (e, _) => _emptyCard('Ошибка загрузки'),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCards(BuildContext context, AdminDashboardData d, WidgetRef ref) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 700;
      final cards = [
        _StatCard(
          label: 'ПОЛЬЗОВАТЕЛИ',
          value: d.totalUsers.toString(),
          subtitle: '+${d.newUsers30d} за 30 дней',
          icon: Icons.people_rounded,
        ),
        _StatCard(
          label: 'РЕЛИЗЫ',
          value: d.totalReleases.toString(),
          subtitle: '${d.openTickets} тикетов',
          icon: Icons.album_rounded,
          accentColor: AurixTokens.positive,
        ),
        _StatCard(
          label: 'ЗАКАЗЫ',
          value: d.activeOrders.toString(),
          subtitle: 'активных',
          icon: Icons.precision_manufacturing_rounded,
          accentColor: AurixTokens.orange,
        ),
        _StatCard(
          label: 'СОБЫТИЯ 24ч',
          value: d.events24h.toString(),
          subtitle: 'user events',
          icon: Icons.bolt_rounded,
          accentColor: AurixTokens.accent,
        ),
      ];

      if (isWide) {
        return Row(
          children: cards
              .map((c) => Expanded(
                  child: Padding(padding: const EdgeInsets.only(right: 12), child: c)))
              .toList(),
        );
      }
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards
            .map((c) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: c))
            .toList(),
      );
    });
  }

  Widget _buildDauChart(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return _emptyCard('Нет данных об активности. События начнут появляться после включения трекинга.');

    final maxDau = rows.fold<int>(0, (m, r) => _safeInt(r['dau']) > m ? _safeInt(r['dau']) : m);
    final barMax = maxDau > 0 ? maxDau.toDouble() : 1.0;

    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: rows.map((r) {
            final day = r['day']?.toString() ?? '';
            final dau = _safeInt(r['dau']);
            final shortDay = day.length >= 10 ? day.substring(5, 10) : day;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(shortDay, style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontFeatures: AurixTokens.tabularFigures)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: dau / barMax,
                        minHeight: 18,
                        backgroundColor: AurixTokens.bg2,
                        valueColor: AlwaysStoppedAnimation(AurixTokens.accent.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(dau.toString(), textAlign: TextAlign.right, style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEventsBreakdown(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return _emptyCard('Нет событий');
    final top = rows.take(10).toList();

    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: top.map((r) {
            final event = r['event']?.toString() ?? '';
            final count = _safeInt(r['count']);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(_eventIcon(event), size: 16, color: AurixTokens.accent),
                        const SizedBox(width: 8),
                        Flexible(child: Text(event, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ),
                  Text(count.toString(), style: const TextStyle(color: AurixTokens.muted, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBreakdown(AdminDashboardData d, WidgetRef ref) {
    if (d.releasesByStatus.isEmpty) return _emptyCard('Нет данных');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: d.releasesByStatus.map((r) {
        final status = r['status']?.toString() ?? '';
        final count = _safeInt(r['count']);
        return _StatusChip(
          label: _getStatusLabel(status),
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

  Widget _buildPlanBreakdown(AdminDashboardData d) {
    if (d.usersByPlan.isEmpty) return _emptyCard('Нет данных');

    return Row(
      children: d.usersByPlan.take(4).map((r) {
        final plan = r['plan']?.toString() ?? 'none';
        final count = _safeInt(r['count']);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _PlanCard(label: _planLabel(plan), count: count),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentUsers(AdminDashboardData d) {
    if (d.recentUsers.isEmpty) return _emptyCard('Нет регистраций');

    return _buildCard(
      child: Column(
        children: d.recentUsers.take(5).map((u) {
          final email = u['email']?.toString() ?? '';
          final created = u['created_at']?.toString() ?? '';
          final date = DateTime.tryParse(created);
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: AurixTokens.accent.withValues(alpha: 0.15),
              child: Text(email.isNotEmpty ? email[0].toUpperCase() : '?', style: const TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            title: Text(email, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w500)),
            trailing: date != null
                ? Text(DateFormat('dd.MM.yy').format(date), style: const TextStyle(color: AurixTokens.muted, fontSize: 11))
                : null,
            onTap: () {
              final id = u['id'];
              if (id != null) onGoToTab?.call('users');
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentActions(AdminDashboardData d) {
    if (d.recentAdminActions.isEmpty) return _emptyCard('Нет действий');

    return _buildCard(
      child: Column(
        children: d.recentAdminActions.take(5).map((log) {
          final action = log['action']?.toString() ?? '';
          final targetType = log['target_type']?.toString() ?? '';
          final created = log['created_at']?.toString() ?? '';
          final date = DateTime.tryParse(created);
          return ListTile(
            dense: true,
            leading: const Icon(Icons.history, color: AurixTokens.muted, size: 18),
            title: Text(action, style: const TextStyle(color: AurixTokens.text, fontSize: 13)),
            subtitle: Text(
              '$targetType${date != null ? ' • ${DateFormat('dd.MM HH:mm').format(date)}' : ''}',
              style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBillingStats(Map<String, dynamic> stats) {
    if (stats.isEmpty) return _emptyCard('Нет данных');

    final totalOps = stats['total_spend_ops'] ?? 0;
    final totalSpent = stats['total_credits_spent'] ?? 0;
    final todayOps = stats['today_ops'] ?? 0;
    final todayCredits = stats['today_credits'] ?? 0;
    final topSpenders = (stats['top_spenders_30d'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AurixTokens.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.monetization_on_rounded, size: 18, color: AurixTokens.orange),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('Credits Economy', style: TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _miniStat('Всего списаний', totalOps.toString())),
                Expanded(child: _miniStat('Кредитов потрачено', totalSpent.toString())),
                Expanded(child: _miniStat('Сегодня', '$todayOps ($todayCredits cr)')),
              ],
            ),
            if (topSpenders.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('ТОП РАСХОДОВ (30 ДН)', style: TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 8),
              ...topSpenders.take(5).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(s['email']?.toString() ?? '#${s['user_id']}', style: const TextStyle(color: AurixTokens.text, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    Text('${s['spent']} cr', style: const TextStyle(color: AurixTokens.orange, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _miniStat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w800)),
    ],
  );

  Widget _buildAiInsights(AiInsightsData ai, WidgetRef ref) {
    if (ai.insights.isEmpty) return _emptyCard('Нет данных для анализа');

    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AurixTokens.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, size: 18, color: AurixTokens.accent),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('AI Insights', style: TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AurixTokens.muted),
                  onPressed: () => ref.invalidate(adminAiInsightsProvider),
                  tooltip: 'Обновить AI анализ',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(ai.insights, style: const TextStyle(color: AurixTokens.text, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }

  static IconData _eventIcon(String event) => switch (event) {
    'login' => Icons.login_rounded,
    'register' => Icons.person_add_rounded,
    'release_created' => Icons.album_rounded,
    'release_submitted' => Icons.send_rounded,
    'track_uploaded' => Icons.music_note_rounded,
    'ai_chat' => Icons.smart_toy_rounded,
    'subscription_changed' => Icons.workspace_premium_rounded,
    _ => Icons.bolt_rounded,
  };

  static String _getStatusLabel(String status) => switch (status) {
    'draft' => 'Черновик',
    'submitted' => 'На модерации',
    'approved' => 'Одобрен',
    'rejected' => 'Отклонён',
    'live' => 'Опубликован',
    'review' => 'На проверке',
    _ => status,
  };

  static String _planLabel(String plan) => switch (plan) {
    'start' => 'Старт',
    'breakthrough' => 'Прорыв',
    'empire' => 'Империя',
    'none' => 'Без плана',
    _ => plan,
  };

  static Widget _loading() => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2),
        ),
      );

  static Widget _errorWidget(String msg) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AurixTokens.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('Ошибка: $msg', style: const TextStyle(color: AurixTokens.danger, fontSize: 13)),
      );

  static Widget _emptyCard(String text) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
          gradient: AurixTokens.cardGradient,
          border: Border.all(color: AurixTokens.stroke(0.18)),
          boxShadow: AurixTokens.subtleShadow,
        ),
        child: Center(child: Text(text, style: const TextStyle(color: AurixTokens.muted, fontSize: 13))),
      );

  static Widget _buildCard({required Widget child}) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
          gradient: AurixTokens.cardGradient,
          border: Border.all(color: AurixTokens.stroke(0.18)),
          boxShadow: AurixTokens.subtleShadow,
        ),
        child: child,
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(
            color: AurixTokens.accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            color: AurixTokens.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          )),
        ],
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.subtitle, required this.icon, this.accentColor});

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AurixTokens.accent;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
        gradient: AurixTokens.cardGradient,
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          ...AurixTokens.subtleShadow,
          BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 16, spreadRadius: -6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: color.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(
              fontFamily: AurixTokens.fontHeading,
              color: AurixTokens.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            )),
          ]),
          const SizedBox(height: 14),
          Text(value, style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            color: AurixTokens.text,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            fontFeatures: AurixTokens.tabularFigures,
          )),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        gradient: AurixTokens.cardGradient,
        border: Border.all(color: AurixTokens.stroke(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            color: AurixTokens.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          )),
          const SizedBox(height: 8),
          Text(count.toString(), style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            color: AurixTokens.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFeatures: AurixTokens.tabularFigures,
          )),
        ],
      ),
    );
  }
}

class _AiActionsCard extends ConsumerStatefulWidget {
  const _AiActionsCard({required this.data});
  final AiActionsData data;

  @override
  ConsumerState<_AiActionsCard> createState() => _AiActionsCardState();
}

class _AiActionsCardState extends ConsumerState<_AiActionsCard> {
  final Set<int> _applying = {};

  Future<void> _apply(int index, Map<String, dynamic> action) async {
    setState(() => _applying.add(index));
    try {
      await ApiClient.post('/admin/ai-actions/apply', data: {'action': action});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Действие применено: ${action['title'] ?? action['type']}'),
          backgroundColor: AurixTokens.positive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: AurixTokens.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _applying.remove(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.data.actions;
    if (actions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AurixTokens.bg1.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AurixTokens.stroke(0.24)),
        ),
        child: const Center(child: Text('AI не обнаружил проблем', style: TextStyle(color: AurixTokens.muted, fontSize: 13))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: -10, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AurixTokens.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.auto_fix_high_rounded, size: 18, color: AurixTokens.orange),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('AI Suggestions', style: TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700))),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AurixTokens.muted),
                  onPressed: () => ref.invalidate(adminAiActionsProvider),
                ),
              ],
            ),
          ),
          ...actions.asMap().entries.map((entry) {
            final i = entry.key;
            final a = entry.value;
            final problem = a['problem']?.toString() ?? '';
            final suggestion = a['suggestion']?.toString() ?? '';
            final severity = a['severity']?.toString() ?? 'low';
            final action = a['action'] as Map<String, dynamic>?;
            final sevColor = switch (severity) {
              'high' => AurixTokens.danger,
              'medium' => AurixTokens.orange,
              _ => AurixTokens.muted,
            };

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AurixTokens.bg0.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sevColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: sevColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text(severity.toUpperCase(), style: TextStyle(color: sevColor, fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(problem, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(suggestion, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 12, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
                    if (action != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: _applying.contains(i) ? null : () => _apply(i, action),
                          icon: _applying.contains(i)
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.play_arrow_rounded, size: 16),
                          label: Text(action['type']?.toString().toUpperCase() ?? 'APPLY', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sevColor.withValues(alpha: 0.8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
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
    final chipColor = switch (status) {
      'submitted' || 'review' => AurixTokens.orange,
      'approved' || 'live' => AurixTokens.positive,
      'rejected' => AurixTokens.muted,
      _ => AurixTokens.textSecondary,
    };

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
              Text(label, style: TextStyle(color: chipColor, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text(count.toString(), style: TextStyle(color: chipColor, fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SIGNALS BLOCK — "Что происходит сейчас"
// ═══════════════════════════════════════════════════════════

class _SignalsBlock extends StatelessWidget {
  const _SignalsBlock({required this.signals, this.onGoToUser});
  final List<AdminSignal> signals;
  final void Function(String userId)? onGoToUser;

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AurixTokens.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.notifications_active_rounded, size: 16, color: AurixTokens.danger),
            ),
            const SizedBox(width: 8),
            const Text('ЧТО ПРОИСХОДИТ СЕЙЧАС', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ],
        ),
        const SizedBox(height: 10),
        ...signals.take(8).map((s) {
          final color = switch (s.type) { 'risk' => AurixTokens.danger, 'money' => AurixTokens.orange, 'growth' => AurixTokens.positive, _ => AurixTokens.muted };
          final icon = switch (s.type) { 'risk' => Icons.warning_rounded, 'money' => Icons.monetization_on_rounded, 'growth' => Icons.trending_up_rounded, _ => Icons.info_rounded };
          final borderColor = switch (s.priority) { 'high' => color.withValues(alpha: 0.4), 'medium' => color.withValues(alpha: 0.2), _ => AurixTokens.stroke(0.16) };

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: s.userId != null ? () => onGoToUser?.call(s.userId!) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(s.message, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      if (s.userId != null)
                        const Icon(Icons.chevron_right_rounded, size: 16, color: AurixTokens.muted),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  MONETIZATION BLOCK
// ═══════════════════════════════════════════════════════════

class _MonetizationBlock extends ConsumerWidget {
  const _MonetizationBlock({required this.targets});
  final List<Map<String, dynamic>> targets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AurixTokens.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.attach_money_rounded, size: 16, color: AurixTokens.orange),
            ),
            const SizedBox(width: 8),
            const Text('КОГО МОЖНО МОНЕТИЗИРОВАТЬ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ],
        ),
        const SizedBox(height: 10),
        ...targets.take(5).map((t) {
          final email = t['email']?.toString() ?? '#${t['id']}';
          final credits = t['credits'] ?? 0;
          final plan = t['plan']?.toString() ?? 'none';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AurixTokens.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AurixTokens.orange.withValues(alpha: 0.15),
                    child: Text(email.isNotEmpty ? email[0].toUpperCase() : '?', style: const TextStyle(color: AurixTokens.orange, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email, style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        Text('$credits cr • $plan', style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () async {
                        final userId = t['id'];
                        if (userId == null) return;
                        try {
                          await ApiClient.post('/admin/notifications/send', data: {
                            'user_id': userId,
                            'title': 'Специальное предложение',
                            'message': 'Пополните баланс кредитов и получите бонус! Доступные планы ждут вас.',
                            'type': 'promo',
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Оффер отправлен: $email'), backgroundColor: AurixTokens.positive, behavior: SnackBarBehavior.floating));
                          }
                        } catch (_) {}
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AurixTokens.orange.withValues(alpha: 0.8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Оффер', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  RETENTION BLOCK
// ═══════════════════════════════════════════════════════════

class _RetentionBlock extends ConsumerWidget {
  const _RetentionBlock({required this.targets});
  final List<Map<String, dynamic>> targets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AurixTokens.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.person_off_rounded, size: 16, color: AurixTokens.danger),
            ),
            const SizedBox(width: 8),
            const Text('ПОТЕРЯННЫЕ ПОЛЬЗОВАТЕЛИ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ],
        ),
        const SizedBox(height: 10),
        ...targets.take(5).map((t) {
          final email = t['email']?.toString() ?? '#${t['id']}';
          final lastActive = DateTime.tryParse(t['last_active']?.toString() ?? t['created_at']?.toString() ?? '');
          final daysAgo = lastActive != null ? DateTime.now().difference(lastActive).inDays : 0;
          final reason = t['last_active'] != null ? 'Не заходил $daysAgo дн.' : 'Не завершил онбординг';

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AurixTokens.danger.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AurixTokens.danger.withValues(alpha: 0.15),
                    child: Text(email.isNotEmpty ? email[0].toUpperCase() : '?', style: const TextStyle(color: AurixTokens.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email, style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        Text(reason, style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () async {
                        final userId = t['id'];
                        if (userId == null) return;
                        try {
                          await ApiClient.post('/admin/notifications/send', data: {
                            'user_id': userId,
                            'title': 'Мы скучаем!',
                            'message': 'Вернитесь в AURIX — у вас есть незавершённые проекты и новые инструменты ждут!',
                            'type': 'retention',
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Напоминание отправлено: $email'), backgroundColor: AurixTokens.positive, behavior: SnackBarBehavior.floating));
                          }
                        } catch (_) {}
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AurixTokens.accent.withValues(alpha: 0.8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Вернуть', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  USER QUICK ACTION (navigated from signal click)
// ═══════════════════════════════════════════════════════════

class _UserQuickAction extends ConsumerStatefulWidget {
  const _UserQuickAction({required this.userId});
  final int userId;

  @override
  ConsumerState<_UserQuickAction> createState() => _UserQuickActionState();
}

class _UserQuickActionState extends ConsumerState<_UserQuickAction> {
  bool _loading = false;

  Future<void> _action(String label, Future<void> Function() fn) async {
    setState(() => _loading = true);
    try {
      await fn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label), backgroundColor: AurixTokens.positive, behavior: SnackBarBehavior.floating));
        ref.invalidate(adminUserDetailProvider(widget.userId));
        ref.invalidate(adminUserBalanceProvider(widget.userId));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(adminUserDetailProvider(widget.userId));
    final balanceAsync = ref.watch(adminUserBalanceProvider(widget.userId));

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AurixTokens.text), onPressed: () => Navigator.of(context).pop()),
        title: Text('User #${widget.userId}', style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile info
            detailAsync.when(
              data: (data) {
                final user = data['user'] as Map<String, dynamic>?;
                final profile = data['profile'] as Map<String, dynamic>?;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AurixTokens.bg1.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(10), border: Border.all(color: AurixTokens.stroke(0.24))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?['email']?.toString() ?? 'N/A', style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Роль: ${profile?['role'] ?? 'artist'}  •  План: ${profile?['plan'] ?? 'none'}  •  Статус: ${profile?['account_status'] ?? 'active'}',
                          style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
              error: (e, _) => Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted)),
            ),

            const SizedBox(height: 12),

            // Balance
            balanceAsync.when(
              data: (balance) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AurixTokens.bg1.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(10), border: Border.all(color: AurixTokens.stroke(0.24))),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on_rounded, size: 20, color: AurixTokens.orange),
                    const SizedBox(width: 10),
                    Text('$balance кредитов', style: const TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures)),
                  ],
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            // Action buttons
            const Text('БЫСТРЫЕ ДЕЙСТВИЯ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ActionBtn(
                  icon: Icons.add_circle_rounded,
                  label: '+20 кредитов',
                  color: AurixTokens.positive,
                  loading: _loading,
                  onTap: () => _action('Кредиты начислены', () async {
                    await ApiClient.post('/admin/billing/bonus', data: {'user_id': widget.userId, 'amount': 20, 'reason': 'Бонус от админа'});
                  }),
                ),
                _ActionBtn(
                  icon: Icons.block_rounded,
                  label: 'Заблокировать',
                  color: AurixTokens.danger,
                  loading: _loading,
                  onTap: () => _action('Пользователь заблокирован', () async {
                    await ApiClient.post('/admin/users/${widget.userId}/block', data: {});
                  }),
                ),
                _ActionBtn(
                  icon: Icons.lock_open_rounded,
                  label: 'Разблокировать',
                  color: AurixTokens.positive,
                  loading: _loading,
                  onTap: () => _action('Пользователь разблокирован', () async {
                    await ApiClient.post('/admin/users/${widget.userId}/unblock', data: {});
                  }),
                ),
                _ActionBtn(
                  icon: Icons.restart_alt_rounded,
                  label: 'Сбросить лимиты',
                  color: AurixTokens.accent,
                  loading: _loading,
                  onTap: () => _action('Лимиты сброшены', () async {
                    await ApiClient.post('/admin/users/${widget.userId}/reset-limits', data: {});
                  }),
                ),
                _ActionBtn(
                  icon: Icons.send_rounded,
                  label: 'Сообщение',
                  color: AurixTokens.aiAccent,
                  loading: _loading,
                  onTap: () => _showNotifyDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifyDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Отправить сообщение', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, style: const TextStyle(color: AurixTokens.text, fontSize: 13), decoration: const InputDecoration(hintText: 'Заголовок')),
            const SizedBox(height: 10),
            TextField(controller: msgCtrl, style: const TextStyle(color: AurixTokens.text, fontSize: 13), decoration: const InputDecoration(hintText: 'Текст сообщения'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _action('Сообщение отправлено', () async {
                await ApiClient.post('/admin/notifications/send', data: {
                  'user_id': widget.userId,
                  'title': titleCtrl.text.isNotEmpty ? titleCtrl.text : 'Сообщение от администратора',
                  'message': msgCtrl.text,
                });
              });
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.loading, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.85),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
