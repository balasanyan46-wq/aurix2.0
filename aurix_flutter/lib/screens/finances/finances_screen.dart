import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

final _userReportRowsProvider = FutureProvider.autoDispose<List<ReportRowModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(reportRepositoryProvider).getRowsByUser(user.id);
});

enum _Period { all, year, quarter, month }

class FinancesScreen extends ConsumerStatefulWidget {
  const FinancesScreen({super.key});

  @override
  ConsumerState<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends ConsumerState<FinancesScreen> {
  _Period _period = _Period.all;

  List<ReportRowModel> _filter(List<ReportRowModel> rows) {
    if (_period == _Period.all) return rows;
    final now = DateTime.now();
    final cutoff = switch (_period) {
      _Period.month => DateTime(now.year, now.month - 1, now.day),
      _Period.quarter => DateTime(now.year, now.month - 3, now.day),
      _Period.year => DateTime(now.year - 1, now.month, now.day),
      _Period.all => DateTime(2000),
    };
    return rows.where((r) => (r.reportDate ?? r.createdAt).isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_userReportRowsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
      error: (e, _) => Center(child: Text('Ошибка: $e', style: TextStyle(color: AurixTokens.muted))),
      data: (allRows) {
        final rows = _filter(allRows);
        final totalRevenue = rows.fold<double>(0, (s, r) => s + r.revenue);
        final totalStreams = rows.fold<int>(0, (s, r) => s + r.streams);

        final currencies = rows.map((r) => r.currency).toSet();
        final currSymbol = currencies.length == 1 && currencies.first == 'RUB' ? '₽' : '\$';

        final byPlatform = <String, ({double revenue, int streams})>{};
        for (final r in rows) {
          final p = r.platform ?? 'Другое';
          final prev = byPlatform[p];
          byPlatform[p] = (
            revenue: (prev?.revenue ?? 0) + r.revenue,
            streams: (prev?.streams ?? 0) + r.streams,
          );
        }
        final platforms = byPlatform.entries.toList()
          ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInSlide(child: _buildPeriodSelector()),
              const SizedBox(height: 20),
              FadeInSlide(
                delayMs: 50,
                child: rows.isEmpty
                    ? _buildEmpty(context)
                    : _buildContent(context, totalRevenue, totalStreams, platforms, rows, currSymbol),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: _Period.values.map((p) {
        final label = switch (p) {
          _Period.all => 'Всё время',
          _Period.year => 'Год',
          _Period.quarter => 'Квартал',
          _Period.month => 'Месяц',
        };
        final selected = _period == p;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => setState(() => _period = p),
            selectedColor: AurixTokens.orange.withValues(alpha: 0.2),
            backgroundColor: AurixTokens.bg2,
            labelStyle: TextStyle(
              color: selected ? AurixTokens.orange : AurixTokens.muted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
            side: BorderSide(color: selected ? AurixTokens.orange : AurixTokens.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: AurixTokens.muted),
            const SizedBox(height: 24),
            Text('Пока нет данных', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              'Здесь появятся начисления после того, как администратор импортирует отчёт дистрибьютора.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    double totalRevenue,
    int totalStreams,
    List<MapEntry<String, ({double revenue, int streams})>> platforms,
    List<ReportRowModel> rows,
    String currSymbol,
  ) {
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final streamFmt = NumberFormat('#,##0', 'en_US');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(label: 'Общий доход', value: '$currSymbol${fmt.format(totalRevenue)}', icon: Icons.attach_money, color: AurixTokens.orange),
            _StatCard(label: 'Стримы', value: streamFmt.format(totalStreams), icon: Icons.headphones_rounded, color: Colors.blueAccent),
            _StatCard(label: 'Платформы', value: '${platforms.length}', icon: Icons.apps_rounded, color: Colors.purpleAccent),
          ],
        ),
        const SizedBox(height: 24),
        AurixGlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Доход по платформам', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (platforms.isEmpty)
                Text('Нет данных', style: TextStyle(color: AurixTokens.muted))
              else
                ...platforms.take(10).map((e) {
                  final pct = totalRevenue > 0 ? e.value.revenue / totalRevenue : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w500)),
                            Text('$currSymbol${fmt.format(e.value.revenue)}  •  ${streamFmt.format(e.value.streams)} стримов',
                                style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: AurixTokens.glass(0.1),
                            valueColor: const AlwaysStoppedAnimation(AurixTokens.orange),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 200,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
