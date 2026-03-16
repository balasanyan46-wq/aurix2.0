import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/providers/reports_provider.dart';
import 'package:aurix_flutter/config/responsive.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String? _selectedReleaseId;

  @override
  Widget build(BuildContext context) {
    final releasesAsync = ref.watch(releasesProvider);
    final rowsAsync = ref.watch(userReportRowsProvider);
    final releases = releasesAsync.valueOrNull ?? [];
    final rows = rowsAsync.valueOrNull ?? [];
    final loading = (releasesAsync.isLoading || rowsAsync.isLoading) &&
        releases.isEmpty &&
        rows.isEmpty;
    final rowsByRelease = <String, List<ReportRowModel>>{};
    for (final row in rows) {
      final releaseId = row.releaseId;
      if (releaseId == null || releaseId.isEmpty) continue;
      rowsByRelease.putIfAbsent(releaseId, () => <ReportRowModel>[]).add(row);
    }

    if (_selectedReleaseId == null && releases.isNotEmpty) {
      String initial = releases.first.id;
      for (final release in releases) {
        if ((rowsByRelease[release.id] ?? const []).isNotEmpty) {
          initial = release.id;
          break;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedReleaseId = initial);
      });
    }

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
    final selectedReleaseRows = _selectedReleaseId == null
        ? const <ReportRowModel>[]
        : (rowsByRelease[_selectedReleaseId!] ?? const <ReportRowModel>[]);
    final selectedRelease = (() {
      for (final release in releases) {
        if (release.id == _selectedReleaseId) return release;
      }
      return null;
    })();
    final aiAdvice = _buildAiAdvice(
      releaseTitle: selectedRelease?.title,
      releaseRows: selectedReleaseRows,
    );

    final hasData = releases.isNotEmpty || rows.isNotEmpty;

    final mobilePad = MediaQuery.sizeOf(context).width < kDesktopBreakpoint ? 16.0 : 24.0;

    if (loading) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(mobilePad),
        child: const _AnalyticsLoadingSkeleton(),
      );
    }

    if (!hasData) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(mobilePad),
        child: FadeInSlide(
          child: PremiumSectionCard(
            padding: const EdgeInsets.all(48),
            child: const PremiumEmptyState(
              title: 'Пока нет данных',
              description: 'Загрузите релиз, и когда появятся отчёты дистрибьютора — здесь отобразится аналитика.',
              icon: Icons.analytics_outlined,
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
            child: const PremiumSectionCard(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: PremiumSectionHeader(
                title: 'Статистика релизов',
                subtitle: 'Общий обзор по аккаунту и детальная аналитика по выбранному релизу.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeInSlide(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MiniStat(label: 'Релизы Live', value: '$live', icon: Icons.check_circle, color: AurixTokens.positive),
                _MiniStat(label: 'На проверке', value: '$inReview', icon: Icons.hourglass_top_rounded, color: AurixTokens.warning),
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
              child: PremiumSectionCard(
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
              child: PremiumSectionCard(
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
              child: PremiumSectionCard(
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
          const SizedBox(height: 24),
          FadeInSlide(
            delayMs: 200,
            child: PremiumSectionCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumSectionHeader(
                    title: 'Статистика по релизу',
                    subtitle: selectedRelease == null
                        ? 'Выбери релиз для детализации.'
                        : 'Трековая структура и AI-рекомендация для «${selectedRelease.title}».',
                  ),
                  const SizedBox(height: 12),
                  if (releases.isEmpty)
                    Text(
                      'У вас пока нет релизов для детальной аналитики.',
                      style: TextStyle(color: AurixTokens.muted, fontSize: 13),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedReleaseId,
                      decoration: InputDecoration(
                        labelText: 'Выберите релиз',
                        labelStyle: TextStyle(color: AurixTokens.muted, fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AurixTokens.stroke(0.2)),
                        ),
                      ),
                      dropdownColor: AurixTokens.bg1,
                      items: releases
                          .map(
                            (r) => DropdownMenuItem<String>(
                              value: r.id,
                              child: Text(
                                r.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AurixTokens.text),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedReleaseId = v),
                    ),
                    const SizedBox(height: 14),
                    if (selectedReleaseRows.isEmpty)
                      Text(
                        'По выбранному релизу пока нет строк отчёта.',
                        style: TextStyle(color: AurixTokens.muted, fontSize: 13),
                      )
                    else ...[
                      _ReleaseTracksTable(rows: selectedReleaseRows),
                      const SizedBox(height: 14),
                      _AiRecommendationCard(advice: aiAdvice),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

_AiAdvice _buildAiAdvice({
  required String? releaseTitle,
  required List<ReportRowModel> releaseRows,
}) {
  if (releaseRows.isEmpty) {
    return const _AiAdvice(
      title: 'AI-рекомендация',
      bullets: [
        'Загрузите отчёт по релизу, чтобы получить персональные рекомендации.',
      ],
    );
  }

  final byTrack = <String, int>{};
  final byCountry = <String, int>{};
  final byPlatform = <String, int>{};
  final byMonth = <String, int>{};
  var totalStreams = 0;

  for (final row in releaseRows) {
    final streams = row.streams;
    totalStreams += streams;
    byTrack[row.trackTitle ?? 'Неизвестный трек'] = (byTrack[row.trackTitle ?? 'Неизвестный трек'] ?? 0) + streams;
    byCountry[row.country ?? 'Неизвестная страна'] = (byCountry[row.country ?? 'Неизвестная страна'] ?? 0) + streams;
    byPlatform[row.platform ?? 'Неизвестная платформа'] = (byPlatform[row.platform ?? 'Неизвестная платформа'] ?? 0) + streams;
    final d = row.reportDate ?? row.createdAt;
    final month = DateFormat('yyyy-MM').format(d);
    byMonth[month] = (byMonth[month] ?? 0) + streams;
  }

  final tracksSorted = byTrack.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final countriesSorted = byCountry.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final monthsSorted = byMonth.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

  final bullets = <String>[];
  final topTrack = tracksSorted.first;
  final topTrackShare = totalStreams > 0 ? topTrack.value / totalStreams : 0.0;
  if (topTrackShare >= 0.7) {
    bullets.add(
      'У релиза сильная зависимость от одного трека («${topTrack.key}»). Поддержите второй трек контентом, чтобы выровнять каталог.',
    );
  } else {
    bullets.add(
      'Стримы распределены относительно равномерно. Закрепите это серией контента на 2–3 трека релиза.',
    );
  }

  final topCountry = countriesSorted.first;
  final topCountryShare = totalStreams > 0 ? topCountry.value / totalStreams : 0.0;
  if (topCountryShare >= 0.65) {
    bullets.add(
      'Основной спрос в регионе «${topCountry.key}». Сфокусируйте рекламу и короткие видео на этой аудитории в ближайшие 7 дней.',
    );
  } else {
    bullets.add(
      'Аудитория распределена по странам. Тестируйте креативы с разной локализацией и оставляйте только лучшие CTR-варианты.',
    );
  }

  if (monthsSorted.length >= 2) {
    final last = monthsSorted.last.value;
    final prev = monthsSorted[monthsSorted.length - 2].value;
    if (prev > 0) {
      final delta = (last - prev) / prev;
      if (delta <= -0.2) {
        bullets.add(
          'Темп просел на ${(delta.abs() * 100).round()}%. Рекомендация: обновить промо-угол и запустить новый контент-хук для релиза.',
        );
      } else if (delta >= 0.2) {
        bullets.add(
          'Есть рост ${(delta * 100).round()}% к прошлому периоду. Зафиксируйте импульс: удвойте рабочий канал продвижения.',
        );
      } else {
        bullets.add(
          'Динамика стабильна. Проверьте новую связку «обложка + тизер + призыв к сохранению», чтобы сдвинуть релиз в рост.',
        );
      }
    }
  } else {
    bullets.add(
      'Пока мало временных точек для оценки тренда. Нужны ещё 1–2 отчётных периода по этому релизу.',
    );
  }

  if (byPlatform.length == 1) {
    bullets.add('Почти все стримы идут с одной платформы. Добавьте кроссплатформенное продвижение для снижения риска.');
  }

  return _AiAdvice(
    title: releaseTitle == null ? 'AI-рекомендация' : 'AI-рекомендация для «$releaseTitle»',
    bullets: bullets.take(4).toList(),
  );
}

class _ReleaseTracksTable extends StatelessWidget {
  const _ReleaseTracksTable({required this.rows});
  final List<ReportRowModel> rows;

  @override
  Widget build(BuildContext context) {
    final byTrack = <String, ({int streams, double revenue})>{};
    for (final row in rows) {
      final key = row.trackTitle ?? 'Неизвестный трек';
      final prev = byTrack[key];
      byTrack[key] = (
        streams: (prev?.streams ?? 0) + row.streams,
        revenue: (prev?.revenue ?? 0) + row.revenue,
      );
    }
    final sorted = byTrack.entries.toList()
      ..sort((a, b) => b.value.streams.compareTo(a.value.streams));
    final fmtStreams = NumberFormat('#,##0', 'en_US');
    final fmtRevenue = NumberFormat('#,##0.00', 'en_US');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Треки релиза',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AurixTokens.text,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        ...sorted.take(8).map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AurixTokens.bg2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AurixTokens.stroke(0.16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${fmtStreams.format(e.value.streams)} стримов',
                    style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '\$${fmtRevenue.format(e.value.revenue)}',
                    style: const TextStyle(
                      color: AurixTokens.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: AurixTokens.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _AiAdvice {
  const _AiAdvice({required this.title, required this.bullets});
  final String title;
  final List<String> bullets;
}

class _AiRecommendationCard extends StatelessWidget {
  const _AiRecommendationCard({required this.advice});
  final _AiAdvice advice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AurixTokens.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                advice.title,
                style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...advice.bullets.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 6, color: AurixTokens.orange),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line,
                      style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    return PremiumHoverLift(
      enabled: isDesktop,
      child: PremiumSectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        radius: 14,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AurixTokens.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AurixTokens.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsLoadingSkeleton extends StatelessWidget {
  const _AnalyticsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        PremiumSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSkeletonBox(height: 18, width: 220),
              SizedBox(height: 8),
              PremiumSkeletonBox(height: 12, width: 300),
            ],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: PremiumSectionCard(child: PremiumSkeletonBox(height: 54))),
            SizedBox(width: 12),
            Expanded(child: PremiumSectionCard(child: PremiumSkeletonBox(height: 54))),
          ],
        ),
        SizedBox(height: 16),
        PremiumSectionCard(child: PremiumSkeletonBox(height: 120)),
        SizedBox(height: 16),
        PremiumSectionCard(child: PremiumSkeletonBox(height: 220)),
      ],
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
