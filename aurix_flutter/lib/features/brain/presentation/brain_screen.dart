import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/core/services/event_tracker.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/providers/brain_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Local providers \u2014 real data from existing endpoints
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

final _userEventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/user-events', query: {'limit': '50'});
    final data = res.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    return <Map<String, dynamic>>[];
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
});

final _growthStateProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final res = await ApiClient.get('/growth/me');
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : {};
  } catch (_) {
    return {};
  }
});

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// BRAIN SCREEN
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class BrainScreen extends ConsumerStatefulWidget {
  const BrainScreen({super.key});

  @override
  ConsumerState<BrainScreen> createState() => _BrainScreenState();
}

class _BrainScreenState extends ConsumerState<BrainScreen> {
  bool _strategyLoading = false;

  @override
  void initState() {
    super.initState();
    EventTracker.track('viewed_brain');
  }

  void _refreshAll() {
    ref.invalidate(brainProfileProvider);
    ref.invalidate(brainStrategyProvider);
    ref.invalidate(releasesProvider);
    ref.invalidate(_userEventsProvider);
    ref.invalidate(_growthStateProvider);
  }

  Future<void> _regenerateStrategy() async {
    if (_strategyLoading) return;
    setState(() => _strategyLoading = true);
    try {
      await ApiClient.post('/brain/strategy/generate');
      ref.invalidate(brainStrategyProvider);
      ref.invalidate(brainProfileProvider);
    } catch (_) {}
    if (mounted) setState(() => _strategyLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(brainProfileProvider);
    final strategyAsync = ref.watch(brainStrategyProvider);
    final releasesAsync = ref.watch(releasesProvider);
    final eventsAsync = ref.watch(_userEventsProvider);
    final growthAsync = ref.watch(_growthStateProvider);

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: RefreshIndicator(
        color: AurixTokens.accent,
        onRefresh: () async => _refreshAll(),
        child: PremiumPageScaffold(
          title: 'AURIX BRAIN',
          subtitle: '\u0421\u0438\u0441\u0442\u0435\u043c\u0430, \u043a\u043e\u0442\u043e\u0440\u0430\u044f \u0443\u043f\u0440\u0430\u0432\u043b\u044f\u0435\u0442 \u0442\u0432\u043e\u0438\u043c \u0440\u043e\u0441\u0442\u043e\u043c',
          systemLabel: 'BRAIN ENGINE',
          systemColor: AurixTokens.aiAccent,
          children: [
            // \u2500\u2500 Section 1: User Status
            FadeInSlide(
              delayMs: 60,
              child: _UserStatusCard(
                profile: profileAsync.valueOrNull ?? {},
                growth: growthAsync.valueOrNull ?? {},
                releases: releasesAsync.valueOrNull ?? [],
                isLoading: profileAsync.isLoading,
              ),
            ),

            // \u2500\u2500 Section 2: AI Insights
            const SizedBox(height: 16),
            FadeInSlide(
              delayMs: 120,
              child: _InsightsBlock(
                strategy: strategyAsync.valueOrNull ?? {},
                isLoading: strategyAsync.isLoading || _strategyLoading,
                hasError: strategyAsync.hasError,
                onRegenerate: _regenerateStrategy,
              ),
            ),

            // \u2500\u2500 Section 3: Recommendations
            const SizedBox(height: 16),
            FadeInSlide(
              delayMs: 180,
              child: _RecommendationsBlock(
                strategy: strategyAsync.valueOrNull ?? {},
                profile: profileAsync.valueOrNull ?? {},
                releases: releasesAsync.valueOrNull ?? [],
                isLoading: strategyAsync.isLoading,
              ),
            ),

            // \u2500\u2500 Section 4: Daily Plan
            const SizedBox(height: 16),
            FadeInSlide(
              delayMs: 240,
              child: _DailyPlanBlock(
                strategy: strategyAsync.valueOrNull ?? {},
                isLoading: strategyAsync.isLoading,
              ),
            ),

            // \u2500\u2500 Section 5: Quick Actions
            const SizedBox(height: 16),
            FadeInSlide(
              delayMs: 300,
              child: _QuickActionsBlock(
                strategy: strategyAsync.valueOrNull ?? {},
                isLoading: strategyAsync.isLoading,
                onNavigate: (path) => context.push(path),
              ),
            ),

            // \u2500\u2500 Section 6: Activity Timeline
            const SizedBox(height: 16),
            FadeInSlide(
              delayMs: 360,
              child: _ActivityTimeline(
                events: eventsAsync.valueOrNull ?? [],
                isLoading: eventsAsync.isLoading,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// 1. USER STATUS CARD
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _UserStatusCard extends StatelessWidget {
  const _UserStatusCard({
    required this.profile,
    required this.growth,
    required this.releases,
    required this.isLoading,
  });
  final Map<String, dynamic> profile;
  final Map<String, dynamic> growth;
  final List<dynamic> releases;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && profile.isEmpty) {
      return PremiumSectionCard(
        glowColor: AurixTokens.aiAccent,
        child: SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(
              color: AurixTokens.aiAccent,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    final growthStatus = _safeStr(profile, 'growth_status', 'new');
    final activityLevel = _safeStr(profile, 'activity_level', 'low');
    final events7d = _safeInt(profile, 'events_7d');
    final events30d = _safeInt(profile, 'events_30d');
    final lastReleaseDays = profile['last_release_days'];
    final xpState = growth['xp'] is Map ? Map<String, dynamic>.from(growth['xp'] as Map) : <String, dynamic>{};
    final level = _safeInt(xpState, 'level', 1);
    final levelName = _safeStr(xpState, 'level_name', 'Rookie');
    final xp = _safeInt(xpState, 'xp');
    final streak = growth['streak'] is Map ? Map<String, dynamic>.from(growth['streak'] as Map) : <String, dynamic>{};
    final currentStreak = _safeInt(streak, 'current_streak');

    final statusInfo = _growthStatusInfo(growthStatus);
    final activityInfo = _activityLevelInfo(activityLevel);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return PremiumSectionCard(
      glowColor: statusInfo.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _SystemBadge(label: 'USER STATUS', color: statusInfo.color),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusInfo.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusInfo.color.withValues(alpha: 0.2)),
                ),
                child: Text(
                  statusInfo.label,
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: statusInfo.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Metrics grid
          Wrap(
            spacing: isDesktop ? 16 : 10,
            runSpacing: 10,
            children: [
              _MetricChip(
                label: '\u0423\u0440\u043e\u0432\u0435\u043d\u044c',
                value: '$level \u00b7 $levelName',
                icon: Icons.diamond_rounded,
                color: AurixTokens.accent,
              ),
              _MetricChip(
                label: '\u0410\u043a\u0442\u0438\u0432\u043d\u043e\u0441\u0442\u044c',
                value: activityInfo.label,
                icon: Icons.bolt_rounded,
                color: activityInfo.color,
              ),
              _MetricChip(
                label: 'XP',
                value: '$xp',
                icon: Icons.star_rounded,
                color: AurixTokens.warning,
              ),
              _MetricChip(
                label: '\u0421\u0442\u0440\u0438\u043a',
                value: '$currentStreak \u0434\u043d.',
                icon: Icons.local_fire_department_rounded,
                color: currentStreak >= 7
                    ? AurixTokens.accent
                    : currentStreak >= 3
                        ? AurixTokens.warning
                        : AurixTokens.muted,
              ),
              _MetricChip(
                label: '\u0420\u0435\u043b\u0438\u0437\u044b',
                value: '${releases.length}',
                icon: Icons.album_rounded,
                color: AurixTokens.aiAccent,
              ),
              _MetricChip(
                label: '\u041f\u043e\u0441\u043b. \u0440\u0435\u043b\u0438\u0437',
                value: lastReleaseDays != null ? '$lastReleaseDays \u0434\u043d. \u043d\u0430\u0437\u0430\u0434' : '\u2014',
                icon: Icons.schedule_rounded,
                color: lastReleaseDays != null && (lastReleaseDays as num) > 30
                    ? AurixTokens.danger
                    : AurixTokens.positive,
              ),
            ],
          ),

          // Activity bar
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '7\u0434: $events7d',
                style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  color: AurixTokens.micro,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '30\u0434: $events30d',
                style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  color: AurixTokens.micro,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              Text(
                '\u0421\u043e\u0431\u044b\u0442\u0438\u0439 \u0437\u0430 \u043f\u0435\u0440\u0438\u043e\u0434',
                style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  color: AurixTokens.micro,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// 2. AI INSIGHTS BLOCK
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _InsightsBlock extends StatelessWidget {
  const _InsightsBlock({
    required this.strategy,
    required this.isLoading,
    required this.hasError,
    required this.onRegenerate,
  });
  final Map<String, dynamic> strategy;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final problem = _safeStr(strategy, 'problem', '');
    final opportunity = _safeStr(strategy, 'opportunity', '');
    final strategyFocus = _safeStr(strategy, 'strategy', '');

    return PremiumSectionCard(
      glowColor: AurixTokens.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SystemBadge(label: 'AI \u0410\u041d\u0410\u041b\u0418\u0417', color: AurixTokens.warning),
              const Spacer(),
              _RefreshButton(
                isLoading: isLoading,
                onTap: onRegenerate,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isLoading && problem.isEmpty)
            _LoadingPlaceholder(message: 'AI \u0430\u043d\u0430\u043b\u0438\u0437\u0438\u0440\u0443\u0435\u0442 \u043f\u0430\u0442\u0442\u0435\u0440\u043d\u044b...')
          else if (hasError && problem.isEmpty)
            _ErrorPlaceholder(
              message: '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c \u0430\u043d\u0430\u043b\u0438\u0437',
              onRetry: onRegenerate,
            )
          else ...[
            // Problem
            if (problem.isNotEmpty)
              _InsightRow(
                icon: Icons.warning_amber_rounded,
                color: AurixTokens.danger,
                label: '\u041f\u0420\u041e\u0411\u041b\u0415\u041c\u0410',
                text: problem,
              ),

            if (problem.isNotEmpty && opportunity.isNotEmpty)
              const SizedBox(height: 14),

            // Opportunity
            if (opportunity.isNotEmpty)
              _InsightRow(
                icon: Icons.rocket_launch_rounded,
                color: AurixTokens.positive,
                label: '\u0412\u041e\u0417\u041c\u041e\u0416\u041d\u041e\u0421\u0422\u042c',
                text: opportunity,
              ),

            if (strategyFocus.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AurixTokens.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.gps_fixed_rounded, size: 14, color: AurixTokens.accent),
                    const SizedBox(width: 8),
                    Text(
                      '\u0424\u043e\u043a\u0443\u0441: ${_strategyFocusLabel(strategyFocus)}',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontMono,
                        color: AurixTokens.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// 3. RECOMMENDATIONS
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _RecommendationsBlock extends StatelessWidget {
  const _RecommendationsBlock({
    required this.strategy,
    required this.profile,
    required this.releases,
    required this.isLoading,
  });
  final Map<String, dynamic> strategy;
  final Map<String, dynamic> profile;
  final List<dynamic> releases;
  final bool isLoading;

  List<_Recommendation> _buildRecommendations() {
    final recs = <_Recommendation>[];

    // From AI strategy
    final todayTasks = _safeList(strategy, 'today_tasks');
    for (final t in todayTasks) {
      if (t is Map) {
        recs.add(_Recommendation(
          title: _safeStr(t, 'title', ''),
          description: _safeStr(t, 'description', ''),
          category: _safeStr(t, 'category', 'content'),
          priority: 'high',
        ));
      }
    }

    // Local intelligence: generate if AI didn't return anything
    if (recs.isEmpty) {
      final lastReleaseDays = profile['last_release_days'];
      final activityLevel = _safeStr(profile, 'activity_level', 'low');
      final promoUsage = profile['promo_usage'] == true;
      final aiUsage = profile['ai_usage'] == true;

      if (releases.isEmpty) {
        recs.add(const _Recommendation(
          title: '\u0421\u043e\u0437\u0434\u0430\u0439 \u043f\u0435\u0440\u0432\u044b\u0439 \u0440\u0435\u043b\u0438\u0437',
          description: '\u0411\u0435\u0437 \u0440\u0435\u043b\u0438\u0437\u043e\u0432 \u0440\u043e\u0441\u0442 \u043d\u0435\u0432\u043e\u0437\u043c\u043e\u0436\u0435\u043d. \u041d\u0430\u0447\u043d\u0438 \u0441 \u043e\u0434\u043d\u043e\u0433\u043e \u0442\u0440\u0435\u043a\u0430.',
          category: 'release',
          priority: 'high',
        ));
      }

      if (lastReleaseDays != null && (lastReleaseDays as num) > 21) {
        recs.add(_Recommendation(
          title: '\u0422\u044b \u043d\u0435 \u0432\u044b\u043f\u0443\u0441\u043a\u0430\u043b \u0442\u0440\u0435\u043a $lastReleaseDays \u0434\u043d\u0435\u0439',
          description: '\u042d\u0442\u043e \u0443\u0431\u0438\u0432\u0430\u0435\u0442 \u0440\u043e\u0441\u0442. \u0412\u044b\u043f\u0443\u0441\u0442\u0438 \u0445\u043e\u0442\u044f \u0431\u044b \u0434\u0435\u043c\u043e.',
          category: 'release',
          priority: 'high',
        ));
      }

      if (!promoUsage) {
        recs.add(const _Recommendation(
          title: '\u041f\u0440\u043e\u043c\u043e \u043d\u0435 \u0438\u0441\u043f\u043e\u043b\u044c\u0437\u0443\u0435\u0442\u0441\u044f',
          description: '\u041c\u0443\u0437\u044b\u043a\u0430 \u0431\u0435\u0437 \u043f\u0440\u043e\u0434\u0432\u0438\u0436\u0435\u043d\u0438\u044f \u043d\u0435 \u0440\u0430\u0441\u0442\u0451\u0442. \u041e\u0442\u043a\u0440\u043e\u0439 \u0440\u0430\u0437\u0434\u0435\u043b \u041f\u0440\u043e\u043c\u043e.',
          category: 'promo',
          priority: 'medium',
        ));
      }

      if (!aiUsage) {
        recs.add(const _Recommendation(
          title: '\u041f\u043e\u043f\u0440\u043e\u0431\u0443\u0439 AI Studio',
          description: 'AI \u043f\u043e\u043c\u043e\u0436\u0435\u0442 \u0441 \u0442\u0435\u043a\u0441\u0442\u0430\u043c\u0438, \u0438\u0434\u0435\u044f\u043c\u0438 \u0438 \u0441\u0442\u0440\u0430\u0442\u0435\u0433\u0438\u0435\u0439.',
          category: 'ai',
          priority: 'medium',
        ));
      }

      if (activityLevel == 'low') {
        recs.add(const _Recommendation(
          title: '\u041d\u0438\u0437\u043a\u0430\u044f \u0430\u043a\u0442\u0438\u0432\u043d\u043e\u0441\u0442\u044c',
          description: '\u0417\u0430\u0445\u043e\u0434\u0438 \u043a\u0430\u0436\u0434\u044b\u0439 \u0434\u0435\u043d\u044c \u2014 \u044d\u0442\u043e \u0443\u0436\u0435 \u0440\u043e\u0441\u0442.',
          category: 'content',
          priority: 'low',
        ));
      }
    }

    return recs;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && strategy.isEmpty) {
      return PremiumSectionCard(
        child: _LoadingPlaceholder(message: '\u0413\u0435\u043d\u0435\u0440\u0438\u0440\u0443\u0435\u043c \u0440\u0435\u043a\u043e\u043c\u0435\u043d\u0434\u0430\u0446\u0438\u0438...'),
      );
    }

    final recs = _buildRecommendations();
    if (recs.isEmpty) return const SizedBox.shrink();

    return PremiumSectionCard(
      glowColor: AurixTokens.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SystemBadge(label: '\u0420\u0415\u041a\u041e\u041c\u0415\u041d\u0414\u0410\u0426\u0418\u0418', color: AurixTokens.accent),
          const SizedBox(height: 14),
          for (int i = 0; i < recs.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _RecommendationCard(rec: recs[i]),
          ],
        ],
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// 4. DAILY PLAN
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _DailyPlanBlock extends StatelessWidget {
  const _DailyPlanBlock({required this.strategy, required this.isLoading});
  final Map<String, dynamic> strategy;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final weekPlan = _safeList(strategy, 'week_plan');

    if (isLoading && weekPlan.isEmpty) {
      return PremiumSectionCard(
        child: _LoadingPlaceholder(message: '\u0421\u043e\u0441\u0442\u0430\u0432\u043b\u044f\u0435\u043c \u043f\u043b\u0430\u043d...'),
      );
    }

    if (weekPlan.isEmpty) return const SizedBox.shrink();

    return PremiumSectionCard(
      glowColor: AurixTokens.positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SystemBadge(label: '\u041f\u041b\u0410\u041d \u041d\u0410 7 \u0414\u041d\u0415\u0419', color: AurixTokens.positive),
          const SizedBox(height: 14),
          for (int i = 0; i < weekPlan.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AurixTokens.stroke(0.08)),
            _WeekDayRow(
              day: i + 1,
              task: weekPlan[i] is Map
                  ? _safeStr(weekPlan[i] as Map, 'task', '')
                  : weekPlan[i]?.toString() ?? '',
              category: weekPlan[i] is Map
                  ? _safeStr(weekPlan[i] as Map, 'category', '')
                  : '',
              isToday: i == 0,
            ),
          ],
        ],
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// 5. QUICK ACTIONS
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _QuickActionsBlock extends StatelessWidget {
  const _QuickActionsBlock({
    required this.strategy,
    required this.isLoading,
    required this.onNavigate,
  });
  final Map<String, dynamic> strategy;
  final bool isLoading;
  final void Function(String) onNavigate;

  @override
  Widget build(BuildContext context) {
    final quickActions = _safeList(strategy, 'quick_actions');
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return PremiumSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SystemBadge(label: '\u0411\u042b\u0421\u0422\u0420\u042b\u0415 \u0414\u0415\u0419\u0421\u0422\u0412\u0418\u042f', color: AurixTokens.aiAccent),
          const SizedBox(height: 14),

          // AI quick actions
          if (quickActions.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in quickActions)
                  if (a is Map)
                    _QuickActionChip(
                      title: _safeStr(a, 'title', ''),
                      description: _safeStr(a, 'description', ''),
                    ),
              ],
            ),

          if (quickActions.isNotEmpty) const SizedBox(height: 14),

          // System actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _NavActionChip(
                label: 'AI Studio',
                icon: Icons.auto_awesome_rounded,
                color: AurixTokens.accent,
                onTap: () => onNavigate('/studio-ai'),
              ),
              _NavActionChip(
                label: '\u0420\u0435\u043b\u0438\u0437\u044b',
                icon: Icons.album_rounded,
                color: AurixTokens.aiAccent,
                onTap: () => onNavigate('/releases'),
              ),
              _NavActionChip(
                label: '\u041f\u0440\u043e\u043c\u043e',
                icon: Icons.campaign_rounded,
                color: AurixTokens.warning,
                onTap: () => onNavigate('/promo'),
              ),
              _NavActionChip(
                label: '\u0421\u0442\u0430\u0442\u0438\u0441\u0442\u0438\u043a\u0430',
                icon: Icons.analytics_rounded,
                color: AurixTokens.positive,
                onTap: () => onNavigate('/stats'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// 6. ACTIVITY TIMELINE
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({required this.events, required this.isLoading});
  final List<Map<String, dynamic>> events;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SystemBadge(label: '\u0418\u0421\u0422\u041e\u0420\u0418\u042f \u0414\u0415\u0419\u0421\u0422\u0412\u0418\u0419', color: AurixTokens.muted),
              const Spacer(),
              if (events.isNotEmpty)
                Text(
                  '${events.length} \u0441\u043e\u0431\u044b\u0442\u0438\u0439',
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.micro,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (isLoading && events.isEmpty)
            _LoadingPlaceholder(message: '\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430 \u0438\u0441\u0442\u043e\u0440\u0438\u0438...')
          else if (events.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AurixTokens.surface1.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history_rounded, size: 28, color: AurixTokens.micro),
                    const SizedBox(height: 8),
                    Text(
                      '\u041f\u043e\u043a\u0430 \u043d\u0435\u0442 \u0441\u043e\u0431\u044b\u0442\u0438\u0439',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\u041d\u0430\u0447\u043d\u0438 \u0438\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u044c AURIX \u2014 \u0432\u0441\u0451 \u043e\u0442\u043e\u0431\u0440\u0430\u0437\u0438\u0442\u0441\u044f \u0437\u0434\u0435\u0441\u044c',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.micro,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (int i = 0; i < min(15, events.length); i++) ...[
              if (i > 0) Divider(height: 1, color: AurixTokens.stroke(0.06)),
              _EventRow(event: events[i]),
            ],
        ],
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// SHARED WIDGETS
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _SystemBadge extends StatelessWidget {
  const _SystemBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(Icons.auto_awesome_rounded, size: 12, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: AurixTokens.fontMono,
            color: AurixTokens.text,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatefulWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  State<_MetricChip> createState() => _MetricChipState();
}

class _MetricChipState extends State<_MetricChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AurixTokens.dFast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: _hovered
              ? widget.color.withValues(alpha: 0.08)
              : AurixTokens.surface1.withValues(alpha: 0.4),
          border: Border.all(
            color: _hovered
                ? widget.color.withValues(alpha: 0.25)
                : AurixTokens.stroke(0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 14, color: widget.color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.micro,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.value,
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFeatures: AurixTokens.tabularFigures,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String label, text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.04),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              fontFamily: AurixTokens.fontBody,
              color: AurixTokens.text,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Recommendation {
  final String title, description, category, priority;
  const _Recommendation({
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
  });
}

class _RecommendationCard extends StatefulWidget {
  const _RecommendationCard({required this.rec});
  final _Recommendation rec;

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(widget.rec.category);
    final priorityColor = widget.rec.priority == 'high'
        ? AurixTokens.danger
        : widget.rec.priority == 'medium'
            ? AurixTokens.warning
            : AurixTokens.muted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AurixTokens.dFast,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _hovered ? color.withValues(alpha: 0.08) : AurixTokens.surface1.withValues(alpha: 0.3),
              AurixTokens.bg1.withValues(alpha: 0.9),
            ],
          ),
          border: Border.all(
            color: _hovered ? color.withValues(alpha: 0.3) : AurixTokens.stroke(0.1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(_categoryIcon(widget.rec.category), size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.rec.title,
                          style: TextStyle(
                            fontFamily: AurixTokens.fontBody,
                            color: AurixTokens.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  if (widget.rec.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.rec.description,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDayRow extends StatelessWidget {
  const _WeekDayRow({
    required this.day,
    required this.task,
    required this.category,
    required this.isToday,
  });
  final int day;
  final String task, category;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final color = isToday ? AurixTokens.accent : AurixTokens.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isToday
                  ? AurixTokens.accent.withValues(alpha: 0.15)
                  : AurixTokens.surface1.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: isToday
                  ? Border.all(color: AurixTokens.accent.withValues(alpha: 0.3))
                  : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task,
                  style: TextStyle(
                    fontFamily: AurixTokens.fontBody,
                    color: isToday ? AurixTokens.text : AurixTokens.textSecondary,
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    _categoryLabel(category),
                    style: TextStyle(
                      fontFamily: AurixTokens.fontMono,
                      color: _categoryColor(category).withValues(alpha: 0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AurixTokens.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '\u0421\u0415\u0413\u041e\u0414\u041d\u042f',
                style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  color: AurixTokens.accent,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final eventName = _safeStr(event, 'event', 'unknown');
    final createdAt = event['created_at']?.toString() ?? '';
    final timeAgo = _formatTimeAgo(createdAt);
    final info = _eventInfo(eventName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: info.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(info.icon, size: 13, color: info.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              info.label,
              style: TextStyle(
                fontFamily: AurixTokens.fontBody,
                color: AurixTokens.text,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            timeAgo,
            style: TextStyle(
              fontFamily: AurixTokens.fontMono,
              color: AurixTokens.micro,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatefulWidget {
  const _QuickActionChip({required this.title, required this.description});
  final String title, description;

  @override
  State<_QuickActionChip> createState() => _QuickActionChipState();
}

class _QuickActionChipState extends State<_QuickActionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.description,
        child: AnimatedContainer(
          duration: AurixTokens.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _hovered
                ? AurixTokens.aiAccent.withValues(alpha: 0.1)
                : AurixTokens.surface1.withValues(alpha: 0.4),
            border: Border.all(
              color: _hovered
                  ? AurixTokens.aiAccent.withValues(alpha: 0.3)
                  : AurixTokens.stroke(0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flash_on_rounded, size: 13, color: AurixTokens.aiAccent),
              const SizedBox(width: 6),
              Text(
                widget.title,
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: _hovered ? AurixTokens.aiAccent : AurixTokens.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavActionChip extends StatefulWidget {
  const _NavActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_NavActionChip> createState() => _NavActionChipState();
}

class _NavActionChipState extends State<_NavActionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _hovered
                ? widget.color.withValues(alpha: 0.1)
                : AurixTokens.surface1.withValues(alpha: 0.3),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.3)
                  : AurixTokens.stroke(0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: _hovered ? widget.color : AurixTokens.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dFast,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hovered && !widget.isLoading
                ? AurixTokens.accent.withValues(alpha: 0.1)
                : AurixTokens.surface1.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AurixTokens.stroke(0.1)),
          ),
          child: widget.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AurixTokens.accent,
                  ),
                )
              : Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: _hovered ? AurixTokens.accent : AurixTokens.muted,
                ),
        ),
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: AurixTokens.accent,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontFamily: AurixTokens.fontBody,
                color: AurixTokens.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: AurixTokens.danger.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: AurixTokens.fontBody,
                color: AurixTokens.muted,
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              '\u041f\u043e\u0432\u0442\u043e\u0440\u0438\u0442\u044c',
              style: TextStyle(
                fontFamily: AurixTokens.fontBody,
                color: AurixTokens.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// HELPERS
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

String _safeStr(Map<dynamic, dynamic> m, String key, [String fallback = '']) {
  final v = m[key];
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

int _safeInt(Map<dynamic, dynamic> m, String key, [int fallback = 0]) {
  final v = m[key];
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

List<dynamic> _safeList(Map<dynamic, dynamic> m, String key) {
  final v = m[key];
  if (v is List) return v;
  return [];
}

class _StatusInfo {
  final String label;
  final Color color;
  const _StatusInfo(this.label, this.color);
}

_StatusInfo _growthStatusInfo(String status) {
  switch (status) {
    case 'growing':
      return const _StatusInfo('\u0420\u041e\u0421\u0422', AurixTokens.positive);
    case 'active':
      return const _StatusInfo('\u0410\u041a\u0422\u0418\u0412\u0415\u041d', AurixTokens.accent);
    case 'exploring':
      return const _StatusInfo('\u0418\u0417\u0423\u0427\u0410\u0415\u0422', AurixTokens.aiAccent);
    case 'stagnation':
      return const _StatusInfo('\u0421\u0422\u0410\u0413\u041d\u0410\u0426\u0418\u042f', AurixTokens.danger);
    case 'inactive':
      return const _StatusInfo('\u041d\u0415\u0410\u041a\u0422\u0418\u0412\u0415\u041d', AurixTokens.muted);
    default:
      return const _StatusInfo('\u041d\u041e\u0412\u042b\u0419', AurixTokens.warning);
  }
}

_StatusInfo _activityLevelInfo(String level) {
  switch (level) {
    case 'high':
      return const _StatusInfo('\u0412\u044b\u0441\u043e\u043a\u0430\u044f', AurixTokens.positive);
    case 'medium':
      return const _StatusInfo('\u0421\u0440\u0435\u0434\u043d\u044f\u044f', AurixTokens.warning);
    default:
      return const _StatusInfo('\u041d\u0438\u0437\u043a\u0430\u044f', AurixTokens.danger);
  }
}

Color _categoryColor(String cat) {
  switch (cat) {
    case 'release':
      return AurixTokens.aiAccent;
    case 'promo':
      return AurixTokens.warning;
    case 'ai':
      return AurixTokens.accent;
    case 'analytics':
      return AurixTokens.positive;
    default:
      return AurixTokens.muted;
  }
}

IconData _categoryIcon(String cat) {
  switch (cat) {
    case 'release':
      return Icons.album_rounded;
    case 'promo':
      return Icons.campaign_rounded;
    case 'ai':
      return Icons.auto_awesome_rounded;
    case 'analytics':
      return Icons.analytics_rounded;
    default:
      return Icons.lightbulb_rounded;
  }
}

String _categoryLabel(String cat) {
  switch (cat) {
    case 'release':
      return '\u0420\u0415\u041b\u0418\u0417';
    case 'promo':
      return '\u041f\u0420\u041e\u041c\u041e';
    case 'ai':
      return 'AI';
    case 'analytics':
      return '\u0410\u041d\u0410\u041b\u0418\u0422\u0418\u041a\u0410';
    default:
      return '\u041a\u041e\u041d\u0422\u0415\u041d\u0422';
  }
}

String _strategyFocusLabel(String s) {
  switch (s) {
    case 'release':
      return '\u0420\u0435\u043b\u0438\u0437\u044b';
    case 'promo':
      return '\u041f\u0440\u043e\u0434\u0432\u0438\u0436\u0435\u043d\u0438\u0435';
    case 'analytics':
      return '\u0410\u043d\u0430\u043b\u0438\u0442\u0438\u043a\u0430';
    default:
      return '\u041a\u043e\u043d\u0442\u0435\u043d\u0442';
  }
}

class _EventInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _EventInfo(this.label, this.icon, this.color);
}

_EventInfo _eventInfo(String event) {
  if (event.contains('login')) return const _EventInfo('\u0412\u0445\u043e\u0434 \u0432 \u0441\u0438\u0441\u0442\u0435\u043c\u0443', Icons.login_rounded, AurixTokens.positive);
  if (event.contains('release')) return const _EventInfo('\u0420\u0430\u0431\u043e\u0442\u0430 \u0441 \u0440\u0435\u043b\u0438\u0437\u043e\u043c', Icons.album_rounded, AurixTokens.aiAccent);
  if (event.contains('track') || event.contains('upload')) return const _EventInfo('\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430 \u0442\u0440\u0435\u043a\u0430', Icons.music_note_rounded, AurixTokens.accent);
  if (event.contains('ai') || event.contains('chat')) return const _EventInfo('AI Studio', Icons.auto_awesome_rounded, AurixTokens.accent);
  if (event.contains('cover')) return const _EventInfo('\u0413\u0435\u043d\u0435\u0440\u0430\u0446\u0438\u044f \u043e\u0431\u043b\u043e\u0436\u043a\u0438', Icons.palette_rounded, AurixTokens.warning);
  if (event.contains('promo')) return const _EventInfo('\u041f\u0440\u043e\u043c\u043e', Icons.campaign_rounded, AurixTokens.warning);
  if (event.contains('dnk')) return const _EventInfo('DNK \u0430\u043d\u0430\u043b\u0438\u0437', Icons.fingerprint_rounded, AurixTokens.aiAccent);
  if (event.contains('analytic') || event.contains('stat')) return const _EventInfo('\u0410\u043d\u0430\u043b\u0438\u0442\u0438\u043a\u0430', Icons.analytics_rounded, AurixTokens.positive);
  if (event.contains('brain')) return const _EventInfo('BRAIN', Icons.psychology_rounded, AurixTokens.aiAccent);
  return _EventInfo(event, Icons.circle, AurixTokens.muted);
}

String _formatTimeAgo(String iso) {
  if (iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return '\u0441\u0435\u0439\u0447\u0430\u0441';
  if (diff.inMinutes < 60) return '${diff.inMinutes}\u043c';
  if (diff.inHours < 24) return '${diff.inHours}\u0447';
  if (diff.inDays < 7) return '${diff.inDays}\u0434';
  return '${diff.inDays ~/ 7}\u043d';
}
