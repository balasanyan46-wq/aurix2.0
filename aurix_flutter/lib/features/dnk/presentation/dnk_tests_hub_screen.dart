import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import '../data/dnk_tests_models.dart';
import '../data/dnk_tests_service.dart';

class _TestVisual {
  final IconData icon;
  final List<Color> gradient;
  final String label;

  const _TestVisual({
    required this.icon,
    required this.gradient,
    required this.label,
  });
}

const Map<String, _TestVisual> _testVisuals = {
  'artist_archetype': _TestVisual(
    icon: Icons.theater_comedy_rounded,
    gradient: [Color(0xFFFF8A3D), Color(0xFFB84DFF)],
    label: 'Сценический образ',
  ),
  'tone_communication': _TestVisual(
    icon: Icons.campaign_rounded,
    gradient: [Color(0xFFFF7A45), Color(0xFFF44336)],
    label: 'Голос в контенте',
  ),
  'story_core': _TestVisual(
    icon: Icons.auto_stories_rounded,
    gradient: [Color(0xFFFFA000), Color(0xFFE53935)],
    label: 'Личный сюжет',
  ),
  'growth_profile': _TestVisual(
    icon: Icons.trending_up_rounded,
    gradient: [Color(0xFFFF8F00), Color(0xFFFF6D00)],
    label: 'Канал роста',
  ),
  'discipline_index': _TestVisual(
    icon: Icons.timer_rounded,
    gradient: [Color(0xFFFF9800), Color(0xFFFF7043)],
    label: 'Рабочий ритм',
  ),
  'career_risk': _TestVisual(
    icon: Icons.shield_moon_rounded,
    gradient: [Color(0xFFFF6F00), Color(0xFFD84315)],
    label: 'Стоп-факторы',
  ),
};

final _dnkTestsCatalogProvider =
    FutureProvider.autoDispose<List<DnkTestCatalogItem>>((ref) async {
  final service = DnkTestsService();
  return service.getCatalog();
});

final _dnkTestsProgressProvider = FutureProvider.autoDispose
    .family<Map<String, DnkTestProgressItem>, String>((ref, userId) async {
  final service = DnkTestsService();
  final rows = await service.getProgress(userId);
  return {for (final x in rows) x.testSlug: x};
});

class DnkTestsHubScreen extends ConsumerWidget {
  const DnkTestsHubScreen({super.key});

  Future<void> _startTest(
    BuildContext context,
    WidgetRef ref,
    DnkTestCatalogItem item,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await context.push('/dnk/tests/${item.slug}');
    ref.invalidate(_dnkTestsProgressProvider(user.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final asyncCatalog = ref.watch(_dnkTestsCatalogProvider);
    final asyncProgress = user == null
        ? const AsyncValue<Map<String, DnkTestProgressItem>>.data(
            <String, DnkTestProgressItem>{})
        : ref.watch(_dnkTestsProgressProvider(user.id));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: asyncCatalog.when(
        loading: () => const _DnkTestsHubLoadingSkeleton(),
        error: (e, _) => Center(
          child: Text('Ошибка: $e',
              style: const TextStyle(color: AurixTokens.negative)),
        ),
        data: (tests) => asyncProgress.when(
          loading: () => const _DnkTestsHubLoadingSkeleton(),
          error: (e, _) => Center(
            child: Text('Ошибка: $e',
                style: const TextStyle(color: AurixTokens.negative)),
          ),
          data: (progressBySlug) {
            if (tests.isEmpty) {
              return const Center(
                child: Text(
                  'Тесты пока недоступны',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 15),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: tests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final t = tests[i];
                final completed = progressBySlug[t.slug];
                final visual = _testVisuals[t.slug] ??
                    const _TestVisual(
                      icon: Icons.psychology_rounded,
                      gradient: [Color(0xFFFF8A3D), Color(0xFFFF6D00)],
                      label: 'Психопрофиль',
                    );
                final width = MediaQuery.sizeOf(context).width;
                final isDesktop = width >= 900;
                final isMobile = width < 640;
                return PremiumHoverLift(
                  enabled: isDesktop,
                  child: PremiumSectionCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isMobile) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TestCover(visual: visual),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AurixTokens.text,
                                        fontSize: 30/2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AurixTokens.bg2.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: AurixTokens.stroke(0.2)),
                                      ),
                                      child: Text(
                                        visual.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AurixTokens.accentMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (completed != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF22C55E),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Тест пройден',
                                            style: TextStyle(
                                              color: const Color(0xFF22C55E)
                                                  .withValues(alpha: 0.95),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton(
                                onPressed: () => _startTest(context, ref, t),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AurixTokens.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                child: Text(completed == null ? 'Пройти тест' : 'Пройти снова'),
                              ),
                              if (completed?.resultId != null)
                                OutlinedButton(
                                  onPressed: () {
                                    context.push('/dnk/tests/result/${completed!.resultId}');
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AurixTokens.textSecondary,
                                    side: const BorderSide(color: AurixTokens.border),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(999)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  child: const Text('Открыть результат'),
                                ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TestCover(visual: visual),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.title,
                                      style: const TextStyle(
                                        color: AurixTokens.text,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                              color: AurixTokens.bg2.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AurixTokens.stroke(0.2)),
                                      ),
                                      child: Text(
                                        visual.label,
                                        style: const TextStyle(
                                          color: AurixTokens.accentMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (completed != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF22C55E),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Тест пройден',
                                            style: TextStyle(
                                              color: const Color(0xFF22C55E).withValues(alpha: 0.95),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  FilledButton(
                                    onPressed: () => _startTest(context, ref, t),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AurixTokens.accent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(999)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                    child: Text(completed == null ? 'Пройти тест' : 'Пройти снова'),
                                  ),
                                  if (completed?.resultId != null) ...[
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: () {
                                        context.push('/dnk/tests/result/${completed!.resultId}');
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AurixTokens.textSecondary,
                                        side: const BorderSide(color: AurixTokens.border),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(999)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      child: const Text('Открыть результат'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          t.description,
                          style: const TextStyle(
                              color: AurixTokens.textSecondary,
                              fontSize: 14,
                              height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Что даёт: ${t.whatGives}',
                          style: const TextStyle(
                              color: AurixTokens.muted, fontSize: 13),
                        ),
                        if (t.exampleResult.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0x16F97316),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0x33F97316)),
                            ),
                            child: Text(
                              'Пример результата: ${t.exampleResult}',
                              style: const TextStyle(
                                  color: AurixTokens.accentMuted, fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DnkTestsHubLoadingSkeleton extends StatelessWidget {
  const _DnkTestsHubLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        return PremiumSectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              PremiumSkeletonBox(height: 68, width: 68, radius: 14),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PremiumSkeletonBox(height: 16, width: 220),
                    SizedBox(height: 8),
                    PremiumSkeletonBox(height: 12, width: 140, radius: 999),
                    SizedBox(height: 12),
                    PremiumSkeletonBox(height: 12),
                    SizedBox(height: 8),
                    PremiumSkeletonBox(height: 12, width: 240),
                  ],
                ),
              ),
              SizedBox(width: 10),
              PremiumSkeletonBox(height: 34, width: 120, radius: 999),
            ],
          ),
        );
      },
    );
  }
}

class _TestCover extends StatelessWidget {
  final _TestVisual visual;

  const _TestCover({required this.visual});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: visual.gradient,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Icon(
            visual.icon,
            color: Colors.white,
            size: 30,
          ),
        ],
      ),
    );
  }
}
