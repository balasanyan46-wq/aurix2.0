import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/providers/reports_provider.dart';
import 'package:aurix_flutter/config/responsive.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releasesAsync = ref.watch(releasesProvider);
    final rowsAsync = ref.watch(userReportRowsProvider);
    final releases = releasesAsync.valueOrNull ?? [];
    final rows = rowsAsync.valueOrNull ?? [];

    final fmt = NumberFormat('#,##0', 'en_US');

    final live = releases.where((r) => r.status == 'approved').length;
    final inReview = releases.where((r) => r.status == 'submitted' || r.status == 'in_review').length;
    final draft = releases.where((r) => r.status == 'draft').length;

    final byTrack = <String, ({int streams, double revenue})>{};
    for (final r in rows) {
      final t = r.trackTitle ?? 'Неизвестный трек';
      final prev = byTrack[t];
      byTrack[t] = (
        streams: (prev?.streams ?? 0) + r.streams,
        revenue: (prev?.revenue ?? 0) + r.revenue,
      );
    }
    final topTracks = byTrack.entries.toList()..sort((a, b) => b.value.streams.compareTo(a.value.streams));

    final byCountry = <String, int>{};
    for (final r in rows) {
      final c = r.country ?? '—';
      byCountry[c] = (byCountry[c] ?? 0) + r.streams;
    }
    final topCountries = byCountry.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final byMonth = <String, int>{};
    for (final r in rows) {
      final d = r.reportDate ?? r.createdAt;
      final key = DateFormat('yyyy-MM').format(d);
      byMonth[key] = (byMonth[key] ?? 0) + r.streams;
    }
    final months = byMonth.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    final hasData = releases.isNotEmpty || rows.isNotEmpty;

    final mobilePad = MediaQuery.sizeOf(context).width < kDesktopBreakpoint ? 16.0 : 24.0;

    if (!hasData) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(mobilePad),
        child: FadeInSlide(
          child: AurixGlassCard(
            padding: const EdgeInsets.all(48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: AurixTokens.muted),
                  const SizedBox(height: 24),
                  Text('Пока нет данных', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(
                    'Загрузите релиз, и когда появятся отчёты дистрибьютора — здесь отобразится аналитика.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(mobilePad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInSlide(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MiniStat(label: 'Релизы Live', value: '$live', icon: Icons.check_circle, color: Colors.green),
                _MiniStat(label: 'На проверке', value: '$inReview', icon: Icons.hourglass_top_rounded, color: Colors.amber),
                _MiniStat(label: 'Черновики', value: '$draft', icon: Icons.edit_note, color: AurixTokens.muted),
                if (rows.isNotEmpty)
                  _MiniStat(
                    label: 'Всего стримов',
                    value: fmt.format(rows.fold<int>(0, (s, r) => s + r.streams)),
                    icon: Icons.headphones_rounded,
                    color: AurixTokens.orange,
                  ),
              ],
            ),
          ),
          if (topTracks.isNotEmpty) ...[
            const SizedBox(height: 24),
            FadeInSlide(
              delayMs: 50,
              child: AurixGlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Топ треков по стримам', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    ...topTracks.take(10).toList().asMap().entries.map((e) {
                      final i = e.key;
                      final t = e.value;
                      final maxStreams = topTracks.first.value.streams;
                      final pct = maxStreams > 0 ? t.value.streams / maxStreams : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text('${i + 1}', style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w700, fontSize: 14)),
                                ),
                                Expanded(
                                  child: Text(t.key, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                                ),
                                Text(fmt.format(t.value.streams), style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: AurixTokens.glass(0.1), valueColor: const AlwaysStoppedAnimation(AurixTokens.orange)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
          if (topCountries.isNotEmpty) ...[
            const SizedBox(height: 24),
            FadeInSlide(
              delayMs: 100,
              child: AurixGlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Топ стран', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    ...topCountries.take(8).map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_compactStreams(e.value)} стримов',
                                style: TextStyle(color: AurixTokens.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
          if (months.isNotEmpty) ...[
            const SizedBox(height: 24),
            FadeInSlide(
              delayMs: 150,
              child: AurixGlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Стримы по месяцам', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: _BarChart(data: months),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _compactStreams(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 10000) return '${(value / 1000).toStringAsFixed(0)}K';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(color: AurixTokens.text, fontSize: 17, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<MapEntry<String, int>> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxVal = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final fmt = NumberFormat('#,##0', 'en_US');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((e) {
        final h = maxVal > 0 ? (e.value / maxVal) * 80.0 : 0.0;
        final label = e.key.length >= 7 ? e.key.substring(5) : e.key;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(fmt.format(e.value), style: TextStyle(color: AurixTokens.muted, fontSize: 9)),
                const SizedBox(height: 4),
                Container(
                  height: h,
                  decoration: BoxDecoration(
                    color: AurixTokens.orange.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 10)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
