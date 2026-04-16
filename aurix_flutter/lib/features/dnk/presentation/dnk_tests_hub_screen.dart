import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import '../data/dnk_tests_models.dart';
import '../data/dnk_tests_service.dart';
import 'package:aurix_flutter/design/widgets/section_onboarding.dart';

// ── Test visuals ─────────────────────────────────────────

class _TestVisual {
  final IconData icon;
  final List<Color> gradient;
  final String label;
  final String emoji;

  const _TestVisual({
    required this.icon,
    required this.gradient,
    required this.label,
    required this.emoji,
  });
}

const Map<String, _TestVisual> _testVisuals = {
  'artist_archetype': _TestVisual(
    icon: Icons.theater_comedy_rounded,
    gradient: [Color(0xFFFF6A1A), Color(0xFFB84DFF)],
    label: 'Сценический образ',
    emoji: '\u{1F3AD}',
  ),
  'tone_communication': _TestVisual(
    icon: Icons.campaign_rounded,
    gradient: [Color(0xFFFF7A45), Color(0xFFF44336)],
    label: 'Голос в контенте',
    emoji: '\u{1F399}',
  ),
  'story_core': _TestVisual(
    icon: Icons.auto_stories_rounded,
    gradient: [Color(0xFFFFA000), Color(0xFFE53935)],
    label: 'Личный сюжет',
    emoji: '\u{1F4D6}',
  ),
  'growth_profile': _TestVisual(
    icon: Icons.trending_up_rounded,
    gradient: [Color(0xFF4CAF50), Color(0xFF00BCD4)],
    label: 'Канал роста',
    emoji: '\u{1F680}',
  ),
  'discipline_index': _TestVisual(
    icon: Icons.timer_rounded,
    gradient: [Color(0xFF7B5CFF), Color(0xFF3F51B5)],
    label: 'Рабочий ритм',
    emoji: '\u{23F0}',
  ),
  'career_risk': _TestVisual(
    icon: Icons.shield_moon_rounded,
    gradient: [Color(0xFFFF6F00), Color(0xFFD84315)],
    label: 'Стоп-факторы',
    emoji: '\u{1F6E1}',
  ),
};

// ── Providers ────────────────────────────────────────────

final _dnkTestsCatalogProvider =
    FutureProvider.autoDispose<List<DnkTestCatalogItem>>((ref) async {
  return DnkTestsService().getCatalog();
});

final _dnkTestsProgressProvider = FutureProvider.autoDispose
    .family<Map<String, DnkTestProgressItem>, String>((ref, userId) async {
  final rows = await DnkTestsService().getProgress(userId);
  return {for (final x in rows) x.testSlug: x};
});

// ── Main Screen ──────────────────────────────────────────

class DnkTestsHubScreen extends ConsumerWidget {
  const DnkTestsHubScreen({super.key});

  Future<void> _startTest(BuildContext context, WidgetRef ref, DnkTestCatalogItem item) async {
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
        ? const AsyncValue<Map<String, DnkTestProgressItem>>.data({})
        : ref.watch(_dnkTestsProgressProvider(user.id));
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: asyncCatalog.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
        error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.danger))),
        data: (tests) => asyncProgress.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
          error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.danger))),
          data: (progressBySlug) {
            final completedCount = progressBySlug.values.where((p) => p.resultId != null).length;
            return SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 28 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionOnboarding(tip: OnboardingTips.dnk),
                      // ── Hero section ──
                      FadeInSlide(
                        delayMs: 0,
                        child: _HeroSection(completedCount: completedCount, totalTests: tests.length),
                      ),
                      const SizedBox(height: 24),
                      // ── Test cards ──
                      if (isDesktop)
                        _DesktopGrid(
                          tests: tests,
                          progress: progressBySlug,
                          onStart: (t) => _startTest(context, ref, t),
                        )
                      else
                        ...tests.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FadeInSlide(
                            delayMs: 100 + e.key * 60,
                            child: _TestCard(
                              test: e.value,
                              progress: progressBySlug[e.value.slug],
                              onStart: () => _startTest(context, ref, e.value),
                            ),
                          ),
                        )),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Hero Section ─────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final int completedCount;
  final int totalTests;

  const _HeroSection({required this.completedCount, required this.totalTests});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusHero),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0F2E), Color(0xFF0D0A14)],
        ),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AurixTokens.accent.withValues(alpha: 0.08),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AurixTokens.accent, AurixTokens.accent.withValues(alpha: 0.6)],
                  ),
                  boxShadow: AurixTokens.accentGlowShadow,
                ),
                child: const Icon(Icons.fingerprint, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aurix DNK',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontHeading,
                        color: AurixTokens.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Узнай свою артистическую ДНК',
                      style: TextStyle(color: AurixTokens.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Каждый артист уникален. DNK-тесты раскроют твой сценический архетип, '
            'стиль коммуникации, внутренний сюжет и скрытые суперсилы. '
            'Это не просто тесты — это зеркало, которое покажет, '
            'кто ты на сцене и за её пределами.',
            style: TextStyle(
              color: AurixTokens.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$completedCount из $totalTests',
                          style: TextStyle(
                            fontFamily: AurixTokens.fontHeading,
                            color: AurixTokens.accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'тестов пройдено',
                          style: TextStyle(color: AurixTokens.muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalTests > 0 ? completedCount / totalTests : 0,
                        minHeight: 6,
                        backgroundColor: AurixTokens.surface2,
                        valueColor: const AlwaysStoppedAnimation(AurixTokens.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Feature chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('5-7 мин на тест'),
              _chip('AI-анализ личности'),
              _chip('План действий'),
              _chip('Контент-идеи'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AurixTokens.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
      ),
      child: Text(text, style: TextStyle(
        color: AurixTokens.accent.withValues(alpha: 0.9),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      )),
    );
  }
}

// ── Desktop Grid ─────────────────────────────────────────

class _DesktopGrid extends StatelessWidget {
  final List<DnkTestCatalogItem> tests;
  final Map<String, DnkTestProgressItem> progress;
  final void Function(DnkTestCatalogItem) onStart;

  const _DesktopGrid({required this.tests, required this.progress, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: tests.asMap().entries.map((e) {
        return SizedBox(
          width: (MediaQuery.sizeOf(context).width.clamp(0, 900) - 56 - 28) / 2,
          child: FadeInSlide(
            delayMs: 100 + e.key * 60,
            child: _TestCard(
              test: e.value,
              progress: progress[e.value.slug],
              onStart: () => onStart(e.value),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Test Card ────────────────────────────────────────────

class _TestCard extends StatefulWidget {
  final DnkTestCatalogItem test;
  final DnkTestProgressItem? progress;
  final VoidCallback onStart;

  const _TestCard({required this.test, this.progress, required this.onStart});

  @override
  State<_TestCard> createState() => _TestCardState();
}

class _TestCardState extends State<_TestCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final visual = _testVisuals[widget.test.slug] ?? const _TestVisual(
      icon: Icons.psychology_rounded,
      gradient: [Color(0xFFFF8A3D), Color(0xFFFF6D00)],
      label: 'Тест',
      emoji: '\u{1F9E0}',
    );
    final completed = widget.progress?.resultId != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AurixTokens.dFast,
        curve: AurixTokens.cEase,
        transform: Matrix4.identity()..scale(_hovered ? 1.02 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
          gradient: AurixTokens.cardGradient,
          border: Border.all(
            color: completed
                ? AurixTokens.positive.withValues(alpha: 0.3)
                : _hovered
                    ? AurixTokens.accent.withValues(alpha: 0.3)
                    : AurixTokens.stroke(0.18),
          ),
          boxShadow: [
            ...AurixTokens.subtleShadow,
            if (_hovered)
              BoxShadow(
                color: visual.gradient[0].withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: -8,
              ),
          ],
        ),
        child: InkWell(
          onTap: widget.onStart,
          borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon with gradient background
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: visual.gradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: visual.gradient[0].withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(visual.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.test.title,
                            style: TextStyle(
                              fontFamily: AurixTokens.fontHeading,
                              color: AurixTokens.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: visual.gradient[0].withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              visual.label,
                              style: TextStyle(
                                color: visual.gradient[0],
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (completed)
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AurixTokens.positive.withValues(alpha: 0.12),
                        ),
                        child: const Icon(Icons.check_rounded, color: AurixTokens.positive, size: 16),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.test.description,
                  style: const TextStyle(
                    color: AurixTokens.muted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Что даёт: ${widget.test.whatGives}',
                  style: TextStyle(
                    color: AurixTokens.textSecondary,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (false) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AurixTokens.surface1,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AurixTokens.stroke(0.1)),
                    ),
                    child: Text(
                      '',
                      style: TextStyle(
                        color: AurixTokens.micro,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: FilledButton(
                          onPressed: widget.onStart,
                          style: FilledButton.styleFrom(
                            backgroundColor: completed
                                ? AurixTokens.surface2
                                : visual.gradient[0],
                            foregroundColor: completed ? AurixTokens.text : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: TextStyle(
                              fontFamily: AurixTokens.fontHeading,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(completed ? 'Пройти снова' : 'Пройти тест'),
                        ),
                      ),
                    ),
                    if (completed && widget.progress?.resultId != null) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 38,
                        child: OutlinedButton(
                          onPressed: () {
                            context.push('/dnk/tests/result/${widget.progress!.resultId}');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AurixTokens.accent,
                            side: BorderSide(color: AurixTokens.accent.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Результат'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
