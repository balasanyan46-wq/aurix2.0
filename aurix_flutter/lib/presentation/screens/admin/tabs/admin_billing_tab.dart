import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/models/billing_subscription_model.dart';

class AdminBillingTab extends ConsumerStatefulWidget {
  const AdminBillingTab({super.key});

  @override
  ConsumerState<AdminBillingTab> createState() => _AdminBillingTabState();
}

class _AdminBillingTabState extends ConsumerState<AdminBillingTab> {
  int _section = 0;
  String _subSearch = '';
  String _subFilter = 'all';
  String _txSearch = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AurixTokens.bg1.withValues(alpha: 0.84),
          child: Row(
            children: [
              _seg(0, 'Обзор', Icons.pie_chart_rounded),
              const SizedBox(width: 8),
              _seg(1, 'Подписки', Icons.workspace_premium_rounded),
              const SizedBox(width: 8),
              _seg(2, 'Транзакции', Icons.receipt_long_rounded),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _section,
            children: [
              _buildOverview(),
              _buildSubscriptions(),
              _buildTransactions(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seg(int idx, String label, IconData icon) {
    final selected = _section == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _section = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AurixTokens.accent.withValues(alpha: 0.2)
                : AurixTokens.bg2.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AurixTokens.accent.withValues(alpha: 0.36)
                  : AurixTokens.stroke(0.12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? AurixTokens.accent : AurixTokens.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AurixTokens.text : AurixTokens.muted,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Overview ───────────────────────────────────────────

  Widget _buildOverview() {
    final statsAsync = ref.watch(adminBillingStatsProvider);

    return RefreshIndicator(
      color: AurixTokens.orange,
      onRefresh: () async => ref.invalidate(adminBillingStatsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const Text('МОНЕТИЗАЦИЯ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            statsAsync.when(
              data: (stats) => _buildStatsCards(stats),
              loading: () => _loading(),
              error: (e, _) => _errorWidget(e.toString()),
            ),
            const SizedBox(height: 28),
            const Text('ТОП РАСХОДОВ (30 ДНЕЙ)', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            statsAsync.when(
              data: (stats) => _buildTopSpenders(stats),
              loading: () => _loading(),
              error: (_, __) => _emptyCard('Нет данных'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> stats) {
    if (stats.isEmpty) return _emptyCard('Нет данных о биллинге');

    final totalOps = stats['total_spend_ops'] ?? 0;
    final totalSpent = stats['total_credits_spent'] ?? 0;
    final todayOps = stats['today_ops'] ?? 0;
    final todayCredits = stats['today_credits'] ?? 0;

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 600;
      final cards = [
        _StatCard(label: 'ВСЕГО ОПЕРАЦИЙ', value: totalOps.toString(), icon: Icons.sync_rounded),
        _StatCard(label: 'КРЕДИТОВ ПОТРАЧЕНО', value: totalSpent.toString(), icon: Icons.monetization_on_rounded, accentColor: AurixTokens.orange),
        _StatCard(label: 'СЕГОДНЯ ОПС', value: todayOps.toString(), icon: Icons.today_rounded, accentColor: AurixTokens.positive),
        _StatCard(label: 'СЕГОДНЯ КРЕДИТОВ', value: todayCredits.toString(), icon: Icons.bolt_rounded, accentColor: AurixTokens.accent),
      ];

      if (isWide) {
        return Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList());
      }
      return Wrap(
        spacing: 12, runSpacing: 12,
        children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: c)).toList(),
      );
    });
  }

  Widget _buildTopSpenders(Map<String, dynamic> stats) {
    final spenders = (stats['top_spenders_30d'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (spenders.isEmpty) return _emptyCard('Нет данных о расходах');

    return _card(
      child: Column(
        children: spenders.take(10).map((s) {
          final email = s['email']?.toString() ?? '#${s['user_id']}';
          final spent = s['spent'] ?? 0;
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: AurixTokens.orange.withValues(alpha: 0.15),
              child: Text(email.isNotEmpty ? email[0].toUpperCase() : '?', style: const TextStyle(color: AurixTokens.orange, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            title: Text(email, style: const TextStyle(color: AurixTokens.text, fontSize: 13), overflow: TextOverflow.ellipsis),
            trailing: Text('$spent cr', style: const TextStyle(color: AurixTokens.orange, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
          );
        }).toList(),
      ),
    );
  }

  // ── Subscriptions ──────────────────────────────────────

  Widget _buildSubscriptions() {
    final subsAsync = ref.watch(adminBillingSubscriptionsProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AurixTokens.bg1.withValues(alpha: 0.5),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: AurixTokens.text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Поиск по User ID...',
                    hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AurixTokens.muted, size: 18),
                    filled: true,
                    fillColor: AurixTokens.bg2.withValues(alpha: 0.9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _subSearch = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              _filterChip(_subFilter, ['all', 'active', 'expired', 'trial'], (v) => setState(() => _subFilter = v)),
            ],
          ),
        ),
        Expanded(
          child: subsAsync.when(
            data: (subs) {
              final filtered = subs.where((s) {
                if (_subSearch.isNotEmpty && !s.userId.toLowerCase().contains(_subSearch)) return false;
                if (_subFilter != 'all' && s.status != _subFilter) return false;
                return true;
              }).toList();

              if (filtered.isEmpty) return Center(child: Text('Нет подписок', style: TextStyle(color: AurixTokens.muted)));

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _SubscriptionCard(sub: filtered[i]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
            error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted))),
          ),
        ),
      ],
    );
  }

  // ── Transactions ───────────────────────────────────────

  Widget _buildTransactions() {
    final txAsync = ref.watch(adminBillingTransactionsProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AurixTokens.bg1.withValues(alpha: 0.5),
          child: TextField(
            style: const TextStyle(color: AurixTokens.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Поиск по user, type...',
              hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AurixTokens.muted, size: 18),
              filled: true,
              fillColor: AurixTokens.bg2.withValues(alpha: 0.9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _txSearch = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: txAsync.when(
            data: (txList) {
              var filtered = txList;
              if (_txSearch.isNotEmpty) {
                filtered = txList.where((t) {
                  final user = t['user_id']?.toString().toLowerCase() ?? '';
                  final type = t['type']?.toString().toLowerCase() ?? '';
                  final email = t['email']?.toString().toLowerCase() ?? '';
                  return user.contains(_txSearch) || type.contains(_txSearch) || email.contains(_txSearch);
                }).toList();
              }

              if (filtered.isEmpty) return Center(child: Text('Нет транзакций', style: TextStyle(color: AurixTokens.muted)));

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final tx = filtered[i];
                  final type = tx['type']?.toString() ?? '';
                  final amount = tx['amount'] ?? tx['credits'] ?? 0;
                  final userId = tx['user_id']?.toString() ?? '';
                  final email = tx['email']?.toString() ?? '';
                  final created = DateTime.tryParse(tx['created_at']?.toString() ?? '');
                  final isCredit = type.contains('grant') || type.contains('bonus') || type.contains('purchase');

                  return _card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (isCredit ? AurixTokens.positive : AurixTokens.orange).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isCredit ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                              size: 18, color: isCredit ? AurixTokens.positive : AurixTokens.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(type, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(email.isNotEmpty ? email : 'User #$userId', style: const TextStyle(color: AurixTokens.muted, fontSize: 11), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isCredit ? "+" : "-"}$amount cr',
                                style: TextStyle(color: isCredit ? AurixTokens.positive : AurixTokens.orange, fontSize: 14, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures),
                              ),
                              if (created != null)
                                Text(DateFormat('dd.MM HH:mm').format(created), style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
            error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted))),
          ),
        ),
      ],
    );
  }

  // ── Shared ─────────────────────────────────────────────

  Widget _filterChip(String current, List<String> options, ValueChanged<String> onSelect) {
    return PopupMenuButton<String>(
      onSelected: onSelect,
      color: AurixTokens.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (_) => options.map((o) => PopupMenuItem(value: o, child: Text(_statusLabel(o), style: TextStyle(color: current == o ? AurixTokens.orange : AurixTokens.text, fontSize: 13)))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: AurixTokens.bg2, borderRadius: BorderRadius.circular(8), border: Border.all(color: AurixTokens.border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_statusLabel(current), style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: AurixTokens.muted),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String s) => switch (s) { 'all' => 'Все', 'active' => 'Активные', 'expired' => 'Истекшие', 'trial' => 'Триал', _ => s };

  static Widget _loading() => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)));

  static Widget _errorWidget(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AurixTokens.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
    child: Text('Ошибка: $msg', style: const TextStyle(color: AurixTokens.danger, fontSize: 13)),
  );

  static Widget _emptyCard(String text) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AurixTokens.bg1.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(10), border: Border.all(color: AurixTokens.stroke(0.24))),
    child: Center(child: Text(text, style: const TextStyle(color: AurixTokens.muted, fontSize: 13))),
  );

  static Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(color: AurixTokens.bg1.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(10), border: Border.all(color: AurixTokens.stroke(0.24))),
    child: child,
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, this.accentColor});
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AurixTokens.text;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AurixTokens.bg1.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(10), border: Border.all(color: AurixTokens.stroke(0.24))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: AurixTokens.muted),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2))),
          ]),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures)),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.sub});
  final BillingSubscriptionModel sub;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (sub.status) { 'active' => AurixTokens.positive, 'trial' => AurixTokens.accent, 'expired' || 'cancelled' => AurixTokens.muted, _ => AurixTokens.textSecondary };
    final statusLabel = switch (sub.status) { 'active' => 'Активна', 'trial' => 'Триал', 'expired' => 'Истекла', 'cancelled' => 'Отменена', _ => sub.status };
    final planLabel = switch (sub.planId) { 'start' => 'Старт', 'breakthrough' => 'Прорыв', 'empire' => 'Империя', _ => sub.planId };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AurixTokens.bg1.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(10), border: Border.all(color: AurixTokens.stroke(0.24))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.workspace_premium_rounded, size: 20, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('User #${sub.userId}', style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('$planLabel  •  до ${DateFormat('dd.MM.yy').format(sub.currentPeriodEnd)}', style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
              ],
            ),
          ),
          if (sub.cancelAtPeriodEnd)
            const Tooltip(message: 'Отмена в конце периода', child: Icon(Icons.cancel_outlined, size: 18, color: AurixTokens.danger)),
        ],
      ),
    );
  }
}
