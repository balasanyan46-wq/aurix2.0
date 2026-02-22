import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';

/// Статистика — только отображение аналитики. Импорт отчётов — только в Admin Panel.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final asyncReleases = ref.watch(releasesProvider);
    final releases = asyncReleases.valueOrNull ?? [];
    final hasData = releases.isNotEmpty;

    if (!hasData) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInSlide(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L10n.t(context, 'statistics'),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(
                    'Аналитика обновляется после того, как администратор импортирует отчёты дистрибьютора.',
                    style: TextStyle(color: AurixTokens.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  AurixGlassCard(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.analytics_outlined, size: 64, color: AurixTokens.muted),
                          const SizedBox(height: 24),
                          Text(
                            'Пока нет данных',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600, color: AurixTokens.text),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Когда появятся отчёты от дистрибьютора, здесь отобразятся стримы, выручка и статистика по релизам.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AurixTokens.muted, fontSize: 16, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInSlide(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L10n.t(context, 'statistics'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  'Аналитика по релизам. Отчёты импортирует администратор.',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (releases.isNotEmpty)
            FadeInSlide(
              delayMs: 50,
              child: AurixGlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Релизы',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    ...releases.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(r.title,
                                  style: TextStyle(
                                      color: AurixTokens.text, fontSize: 14)),
                              Text(r.releaseType,
                                  style: TextStyle(
                                      color: AurixTokens.muted, fontSize: 12)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
