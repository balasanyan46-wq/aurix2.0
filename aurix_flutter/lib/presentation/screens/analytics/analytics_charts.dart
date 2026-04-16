import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

// ═══════════════════════════════════════════════════════════════
// Общие хелперы
// ═══════════════════════════════════════════════════════════════

String _fmtInt(int v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return '$v';
}

String _fmtDouble(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(v < 10 ? 2 : 0);
}

/// Палитра для диаграмм (совместима с AurixTokens).
const _palette = <Color>[
  Color(0xFFFF6A1A), // accent
  Color(0xFF7B5CFF), // aiAccent
  Color(0xFF34D399), // positive
  Color(0xFF60A5FA), // info
  Color(0xFFF472B6), // pink
  Color(0xFFFBBF24), // warning
  Color(0xFFA78BFA), // violet
  Color(0xFF22D3EE), // cyan
  Color(0xFFFB923C), // orange
  Color(0xFF4ADE80), // lime
];

Color _colorFor(int i) => _palette[i % _palette.length];

// ═══════════════════════════════════════════════════════════════
// Section shell (glass card + header)
// ═══════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
        border: Border.all(color: AurixTokens.stroke(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AurixTokens.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title.toUpperCase(), style: const TextStyle(
                    color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 1. PLATFORM DONUT — распределение стримов/дохода по платформам
// ═══════════════════════════════════════════════════════════════

class PlatformDonutChart extends StatefulWidget {
  const PlatformDonutChart({super.key, required this.rows});
  final List<ReportRowModel> rows;

  @override
  State<PlatformDonutChart> createState() => _PlatformDonutChartState();
}

class _PlatformDonutChartState extends State<PlatformDonutChart> {
  int _touchedIndex = -1;
  bool _byRevenue = true; // true = по доходу, false = по стримам

  @override
  Widget build(BuildContext context) {
    final map = <String, ({double revenue, int streams})>{};
    for (final r in widget.rows) {
      final p = (r.platform ?? 'Другое').trim().isEmpty ? 'Другое' : r.platform!;
      final prev = map[p];
      map[p] = (
        revenue: (prev?.revenue ?? 0) + r.revenue,
        streams: (prev?.streams ?? 0) + r.streams,
      );
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => _byRevenue
          ? b.value.revenue.compareTo(a.value.revenue)
          : b.value.streams.compareTo(a.value.streams));

    if (sorted.isEmpty) {
      return _SectionCard(
        title: 'По платформам',
        icon: Icons.apps_rounded,
        child: _empty('Нет данных. Загрузите отчёт дистрибьютора.'),
      );
    }

    final total = _byRevenue
        ? sorted.fold<double>(0, (s, e) => s + e.value.revenue)
        : sorted.fold<double>(0, (s, e) => s + e.value.streams.toDouble());

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < sorted.length; i++) {
      final e = sorted[i];
      final value = _byRevenue ? e.value.revenue : e.value.streams.toDouble();
      final isTouched = i == _touchedIndex;
      sections.add(PieChartSectionData(
        color: _colorFor(i),
        value: value,
        title: total > 0 && value / total > 0.05 ? '${(value / total * 100).toStringAsFixed(0)}%' : '',
        radius: isTouched ? 62 : 54,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ));
    }

    return _SectionCard(
      title: 'По платформам',
      icon: Icons.apps_rounded,
      subtitle: _byRevenue ? 'Доход по источникам' : 'Стримы по источникам',
      trailing: _toggleButton(_byRevenue, onChanged: (v) => setState(() => _byRevenue = v)),
      child: Column(children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 52,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions || response?.touchedSection == null) {
                      _touchedIndex = -1;
                    } else {
                      _touchedIndex = response!.touchedSection!.touchedSectionIndex;
                    }
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Wrap(spacing: 10, runSpacing: 8, children: [
          for (var i = 0; i < sorted.length; i++)
            _legendItem(
              color: _colorFor(i),
              label: sorted[i].key,
              value: _byRevenue
                  ? '₽${_fmtDouble(sorted[i].value.revenue)}'
                  : _fmtInt(sorted[i].value.streams),
              pct: total > 0
                  ? (_byRevenue ? sorted[i].value.revenue : sorted[i].value.streams.toDouble()) / total
                  : 0,
              highlighted: i == _touchedIndex,
            ),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 2. COUNTRIES BAR — топ стран по стримам
// ═══════════════════════════════════════════════════════════════

class CountriesBarChart extends StatelessWidget {
  const CountriesBarChart({super.key, required this.rows});
  final List<ReportRowModel> rows;

  @override
  Widget build(BuildContext context) {
    final map = <String, ({int streams, double revenue})>{};
    for (final r in rows) {
      final c = (r.country ?? '—').trim().isEmpty ? '—' : r.country!;
      final prev = map[c];
      map[c] = (
        streams: (prev?.streams ?? 0) + r.streams,
        revenue: (prev?.revenue ?? 0) + r.revenue,
      );
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.streams.compareTo(a.value.streams));
    final top = sorted.take(8).toList();

    if (top.isEmpty) {
      return _SectionCard(
        title: 'География',
        icon: Icons.public_rounded,
        child: _empty('Нет данных о странах'),
      );
    }

    final maxStreams = top.first.value.streams.toDouble();

    return _SectionCard(
      title: 'География',
      icon: Icons.public_rounded,
      subtitle: 'Топ стран по стримам',
      child: Column(children: [
        for (var i = 0; i < top.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _countryRow(
            rank: i + 1,
            country: top[i].key,
            streams: top[i].value.streams,
            revenue: top[i].value.revenue,
            ratio: maxStreams > 0 ? top[i].value.streams / maxStreams : 0,
            color: _colorFor(i),
          ),
        ],
        if (sorted.length > 8) ...[
          const SizedBox(height: 10),
          Text('И ещё ${sorted.length - 8} стран(ы)',
              style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
        ],
      ]),
    );
  }

  Widget _countryRow({
    required int rank,
    required String country,
    required int streams,
    required double revenue,
    required double ratio,
    required Color color,
  }) {
    return Row(children: [
      SizedBox(
        width: 18,
        child: Text('$rank', style: const TextStyle(
            color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700,
            fontFeatures: AurixTokens.tabularFigures)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(country, style: const TextStyle(
                color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600))),
            Text(_fmtInt(streams), style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700,
                fontFeatures: AurixTokens.tabularFigures)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AurixTokens.glass(0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('₽${_fmtDouble(revenue)}', style: const TextStyle(
                color: AurixTokens.muted, fontSize: 11,
                fontFeatures: AurixTokens.tabularFigures)),
          ]),
        ]),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// 3. USAGE TYPE PIE — подписка vs реклама vs синхронизация
// ═══════════════════════════════════════════════════════════════

class UsageTypeChart extends StatefulWidget {
  const UsageTypeChart({super.key, required this.rows});
  final List<ReportRowModel> rows;

  @override
  State<UsageTypeChart> createState() => _UsageTypeChartState();
}

class _UsageTypeChartState extends State<UsageTypeChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final map = <String, ({double revenue, int streams})>{};
    for (final r in widget.rows) {
      // raw_row_json хранит оригинальную колонку "Вид использования контента"
      final raw = r.rawRowJson;
      String usage = 'Другое';
      if (raw != null) {
        for (final key in raw.keys) {
          final lk = key.toLowerCase();
          if (lk.contains('вид использования') || lk.contains('использ')) {
            final v = raw[key]?.toString().trim();
            if (v != null && v.isNotEmpty) { usage = v; break; }
          }
        }
      }
      final prev = map[usage];
      map[usage] = (
        revenue: (prev?.revenue ?? 0) + r.revenue,
        streams: (prev?.streams ?? 0) + r.streams,
      );
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

    if (sorted.isEmpty || (sorted.length == 1 && sorted.first.key == 'Другое')) {
      return _SectionCard(
        title: 'Типы использования',
        icon: Icons.category_rounded,
        child: _empty('Нет данных о типах использования'),
      );
    }

    final total = sorted.fold<double>(0, (s, e) => s + e.value.revenue);

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < sorted.length; i++) {
      final e = sorted[i];
      final isTouched = i == _touchedIndex;
      sections.add(PieChartSectionData(
        color: _colorFor(i + 2),
        value: e.value.revenue,
        title: total > 0 && e.value.revenue / total > 0.06 ? '${(e.value.revenue / total * 100).toStringAsFixed(0)}%' : '',
        radius: isTouched ? 52 : 44,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
      ));
    }

    return _SectionCard(
      title: 'Типы использования',
      icon: Icons.category_rounded,
      subtitle: 'Откуда приходит доход',
      child: Column(children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions || response?.touchedSection == null) {
                      _touchedIndex = -1;
                    } else {
                      _touchedIndex = response!.touchedSection!.touchedSectionIndex;
                    }
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 6, children: [
          for (var i = 0; i < sorted.length; i++)
            _legendItem(
              color: _colorFor(i + 2),
              label: sorted[i].key,
              value: '₽${_fmtDouble(sorted[i].value.revenue)}',
              pct: total > 0 ? sorted[i].value.revenue / total : 0,
              highlighted: i == _touchedIndex,
            ),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 4. TOP TRACKS BAR — топ треков по доходу
// ═══════════════════════════════════════════════════════════════

class TopTracksChart extends StatelessWidget {
  const TopTracksChart({super.key, required this.rows});
  final List<ReportRowModel> rows;

  @override
  Widget build(BuildContext context) {
    final map = <String, ({double revenue, int streams, String? isrc})>{};
    for (final r in rows) {
      final key = r.trackTitle ?? r.isrc ?? 'Без названия';
      final prev = map[key];
      map[key] = (
        revenue: (prev?.revenue ?? 0) + r.revenue,
        streams: (prev?.streams ?? 0) + r.streams,
        isrc: r.isrc ?? prev?.isrc,
      );
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
    final top = sorted.take(10).toList();

    if (top.isEmpty) {
      return _SectionCard(
        title: 'Топ треков',
        icon: Icons.music_note_rounded,
        child: _empty('Нет треков в отчётах'),
      );
    }

    final maxRevenue = top.first.value.revenue;

    return _SectionCard(
      title: 'Топ треков',
      icon: Icons.music_note_rounded,
      subtitle: 'По доходу',
      child: Column(children: [
        for (var i = 0; i < top.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _trackRow(
            rank: i + 1,
            title: top[i].key,
            isrc: top[i].value.isrc,
            revenue: top[i].value.revenue,
            streams: top[i].value.streams,
            ratio: maxRevenue > 0 ? top[i].value.revenue / maxRevenue : 0,
            color: _colorFor(i),
          ),
        ],
      ]),
    );
  }

  Widget _trackRow({
    required int rank,
    required String title,
    required String? isrc,
    required double revenue,
    required int streams,
    required double ratio,
    required Color color,
  }) {
    return Row(children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: rank <= 3 ? color.withValues(alpha: 0.2) : AurixTokens.glass(0.08),
        ),
        alignment: Alignment.center,
        child: Text('$rank', style: TextStyle(
          color: rank <= 3 ? color : AurixTokens.muted,
          fontSize: 11, fontWeight: FontWeight.w800,
          fontFeatures: AurixTokens.tabularFigures,
        )),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(
                color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
            Text('₽${_fmtDouble(revenue)}', style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700,
                fontFeatures: AurixTokens.tabularFigures)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: AurixTokens.glass(0.08),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${_fmtInt(streams)} стр.', style: const TextStyle(
                color: AurixTokens.muted, fontSize: 11,
                fontFeatures: AurixTokens.tabularFigures)),
          ]),
        ]),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// Shared pieces
// ═══════════════════════════════════════════════════════════════

Widget _legendItem({
  required Color color,
  required String label,
  required String value,
  required double pct,
  bool highlighted = false,
}) {
  return AnimatedContainer(
    duration: AurixTokens.dFast,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: highlighted ? color.withValues(alpha: 0.15) : AurixTokens.glass(0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: highlighted ? color.withValues(alpha: 0.4) : AurixTokens.stroke(0.1)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(width: 6),
      Text('· $value', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(width: 4),
      Text('(${(pct * 100).toStringAsFixed(pct < 0.01 ? 2 : 0)}%)',
          style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
    ]),
  );
}

Widget _empty(String text) => Container(
  padding: const EdgeInsets.all(24),
  alignment: Alignment.center,
  child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.bar_chart_rounded, size: 32, color: AurixTokens.muted.withValues(alpha: 0.4)),
    const SizedBox(height: 8),
    Text(text, style: const TextStyle(color: AurixTokens.muted, fontSize: 12), textAlign: TextAlign.center),
  ]),
);

Widget _toggleButton(bool byRevenue, {required ValueChanged<bool> onChanged}) {
  return Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AurixTokens.bg2,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AurixTokens.stroke(0.1)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      _togglePill('₽', byRevenue, () => onChanged(true)),
      _togglePill('∿', !byRevenue, () => onChanged(false)),
    ]),
  );
}

Widget _togglePill(String label, bool active, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: AnimatedContainer(
      duration: AurixTokens.dFast,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AurixTokens.accent.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(
        color: active ? AurixTokens.accent : AurixTokens.muted,
        fontSize: 12, fontWeight: FontWeight.w800,
      )),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// 5. AI INSIGHTS — AI-анализ статистики с конкретными советами
// ═══════════════════════════════════════════════════════════════

class AiInsightsPanel extends StatefulWidget {
  const AiInsightsPanel({super.key, required this.rows, required this.totalReleases});
  final List<ReportRowModel> rows;
  final int totalReleases;

  @override
  State<AiInsightsPanel> createState() => _AiInsightsPanelState();
}

class _AiInsightsPanelState extends State<AiInsightsPanel> {
  bool _loading = false;
  String? _error;
  _Insights? _insights;

  Future<void> _analyze() async {
    if (widget.rows.isEmpty) return;
    setState(() { _loading = true; _error = null; });

    try {
      // Собираем сводку для отправки
      final byPlatform = <String, ({int streams, double revenue})>{};
      final byCountry = <String, ({int streams, double revenue})>{};
      final byTrack = <String, ({int streams, double revenue})>{};
      final byUsage = <String, double>{};

      for (final r in widget.rows) {
        final p = r.platform ?? 'Другое';
        final prev = byPlatform[p];
        byPlatform[p] = (streams: (prev?.streams ?? 0) + r.streams, revenue: (prev?.revenue ?? 0) + r.revenue);

        final c = r.country ?? '—';
        final prevC = byCountry[c];
        byCountry[c] = (streams: (prevC?.streams ?? 0) + r.streams, revenue: (prevC?.revenue ?? 0) + r.revenue);

        final t = r.trackTitle ?? r.isrc ?? 'Без названия';
        final prevT = byTrack[t];
        byTrack[t] = (streams: (prevT?.streams ?? 0) + r.streams, revenue: (prevT?.revenue ?? 0) + r.revenue);

        final raw = r.rawRowJson;
        if (raw != null) {
          for (final key in raw.keys) {
            if (key.toLowerCase().contains('использ')) {
              final u = raw[key]?.toString() ?? 'Другое';
              byUsage[u] = (byUsage[u] ?? 0) + r.revenue;
              break;
            }
          }
        }
      }

      final totalStreams = widget.rows.fold<int>(0, (s, r) => s + r.streams);
      final totalRevenue = widget.rows.fold<double>(0, (s, r) => s + r.revenue);
      final currencies = widget.rows.map((r) => r.currency).toSet();
      final currency = currencies.length == 1 ? currencies.first : 'RUB';

      final dates = widget.rows.map((r) => r.reportDate).where((d) => d != null).cast<DateTime>().toList();
      dates.sort();
      final periodDays = dates.isNotEmpty ? dates.last.difference(dates.first).inDays + 1 : 0;

      List<Map<String, dynamic>> topN(Iterable<MapEntry<String, ({int streams, double revenue})>> entries, int n) {
        final list = entries.toList()..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
        return list.take(n).map((e) => {
          'name': e.key, 'streams': e.value.streams, 'revenue': e.value.revenue,
        }).toList();
      }

      final payload = {
        'total_streams': totalStreams,
        'total_revenue': totalRevenue,
        'currency': currency,
        'total_releases': widget.totalReleases,
        'period_days': periodDays,
        'top_platforms': topN(byPlatform.entries, 8),
        'top_countries': topN(byCountry.entries, 8),
        'top_tracks': byTrack.entries
            .toList()
            .let((list) { list.sort((a, b) => b.value.revenue.compareTo(a.value.revenue)); return list; })
            .take(8)
            .map((e) => {'title': e.key, 'streams': e.value.streams, 'revenue': e.value.revenue})
            .toList(),
        'usage_types': byUsage.entries.map((e) => {'name': e.key, 'revenue': e.value}).toList(),
      };

      final res = await ApiClient.post('/api/ai/analyze-stats', data: payload);
      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final raw = data['insights']?.toString() ?? '';
      setState(() {
        _insights = _Insights.tryParse(raw);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().length > 140 ? '${e.toString().substring(0, 137)}...' : e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = widget.rows.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AurixTokens.aiAccent.withValues(alpha: 0.1),
            AurixTokens.accent.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
        border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AurixTokens.aiAccent.withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 18, color: AurixTokens.aiAccent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AI-АНАЛИЗ',
                style: TextStyle(color: AurixTokens.aiAccent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 2),
            Text(
              _insights != null ? _insights!.summary : 'Нейросеть смотрит твои цифры и даёт конкретные советы',
              style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ])),
          if (_insights != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AurixTokens.muted),
              tooltip: 'Пересчитать',
              onPressed: _loading ? null : _analyze,
            ),
        ]),
        const SizedBox(height: 16),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AurixTokens.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!, style: const TextStyle(color: AurixTokens.danger, fontSize: 12)),
          ),
          const SizedBox(height: 12),
        ],

        if (_insights == null && !_loading) ...[
          FilledButton.icon(
            onPressed: hasData ? _analyze : null,
            icon: const Icon(Icons.psychology_rounded, size: 18),
            label: const Text('Получить анализ и советы'),
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.aiAccent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AurixTokens.aiAccent.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          ),
          if (!hasData) ...[
            const SizedBox(height: 8),
            const Text(
              'Появится после загрузки отчётов дистрибьютора',
              style: TextStyle(color: AurixTokens.muted, fontSize: 11),
            ),
          ],
        ],

        if (_loading) ...[
          Row(children: [
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.aiAccent),
            ),
            const SizedBox(width: 10),
            const Text('Анализируем цифры...',
                style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
          ]),
        ],

        if (_insights != null) ...[
          if (_insights!.strengths.isNotEmpty) ...[
            _insightsBlock(
              title: 'СИЛЬНЫЕ СТОРОНЫ',
              items: _insights!.strengths,
              color: AurixTokens.positive,
              icon: Icons.trending_up_rounded,
            ),
            const SizedBox(height: 14),
          ],
          if (_insights!.issues.isNotEmpty) ...[
            _insightsBlock(
              title: 'ЧТО УПУСКАЕШЬ',
              items: _insights!.issues,
              color: AurixTokens.warning,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 14),
          ],
          if (_insights!.actions.isNotEmpty) ...[
            _insightsBlock(
              title: 'ЧТО ДЕЛАТЬ',
              items: _insights!.actions,
              color: AurixTokens.accent,
              icon: Icons.bolt_rounded,
            ),
            const SizedBox(height: 14),
          ],
          if (_insights!.nextStep != null && _insights!.nextStep!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AurixTokens.aiAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.3)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.flag_rounded, size: 18, color: AurixTokens.aiAccent),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('СЛЕДУЮЩИЙ ШАГ',
                      style: TextStyle(color: AurixTokens.aiAccent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(_insights!.nextStep!,
                      style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                ])),
              ]),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _insightsBlock({
    required String title,
    required List<String> items,
    required Color color,
    required IconData icon,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
      ]),
      const SizedBox(height: 8),
      ...items.map((text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 10),
            width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(child: Text(text, style: const TextStyle(color: AurixTokens.text, fontSize: 13, height: 1.5))),
        ]),
      )),
    ]);
  }
}

class _Insights {
  final String summary;
  final List<String> strengths;
  final List<String> issues;
  final List<String> actions;
  final String? nextStep;

  _Insights({
    required this.summary,
    required this.strengths,
    required this.issues,
    required this.actions,
    this.nextStep,
  });

  static _Insights tryParse(String raw) {
    // Пытаемся распарсить JSON (возможно обёрнутый в markdown)
    String text = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();

    try {
      final data = jsonDecode(text);
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        List<String> listOf(dynamic v) {
          if (v is List) return v.map((e) => e.toString()).toList();
          return [];
        }
        return _Insights(
          summary: m['summary']?.toString() ?? '',
          strengths: listOf(m['strengths']),
          issues: listOf(m['issues']),
          actions: listOf(m['actions']),
          nextStep: m['next_step']?.toString(),
        );
      }
    } catch (_) {}
    // Fallback — показываем как текст
    return _Insights(
      summary: text.length > 180 ? '${text.substring(0, 177)}...' : text,
      strengths: [], issues: [], actions: [], nextStep: null,
    );
  }
}

// Маленький extension чтобы писать `list.let { it.sort() }`.
extension _Let<T> on T {
  R let<R>(R Function(T) op) => op(this);
}

