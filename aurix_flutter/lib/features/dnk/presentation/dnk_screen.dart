import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/core/services/event_tracker.dart';
import '../data/dnk_models.dart';
import 'dnk_interview_screen.dart';
import 'dnk_result_screen.dart';

const bool kEnableDnkTests = true;

/// Fetches the latest finished DNK result for current user
final _latestDnkResultProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final res = await ApiClient.get('/api/ai/dnk-results/latest');
  final data = res.data;

  if (data == null || data == '' || (data is String && data.isEmpty)) return null;
  if (data is Map<String, dynamic>) return data;

  final rows = asList(data);
  if (rows.isEmpty) return null;
  return rows.first;
});

/// Hub screen: shows existing result or start button
class AurixDnkScreen extends ConsumerStatefulWidget {
  const AurixDnkScreen({super.key});

  @override
  ConsumerState<AurixDnkScreen> createState() => _AurixDnkScreenState();
}

class _AurixDnkScreenState extends ConsumerState<AurixDnkScreen> {
  bool _starting = false;

  Future<void> _startInterview() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _starting = true);
    EventTracker.track('started_dnk');
    try {
      if (!mounted) return;

      final result = await Navigator.of(context).push<DnkResult>(
        MaterialPageRoute(
          builder: (_) => const DnkInterviewScreen(),
        ),
      );

      if (result != null && mounted) {
        ref.invalidate(_latestDnkResultProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync = ref.watch(_latestDnkResultProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: resultAsync.when(
        loading: () => const PremiumLoadingState(
          message: '\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430 DNK \u043f\u0440\u043e\u0444\u0438\u043b\u044f\u2026',
        ),
        error: (e, _) => PremiumErrorState(
          title: '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c',
          message: '\u041f\u0440\u043e\u0432\u0435\u0440\u044c\u0442\u0435 \u043f\u043e\u0434\u043a\u043b\u044e\u0447\u0435\u043d\u0438\u0435 \u043a \u0441\u0435\u0442\u0438 \u0438 \u043f\u043e\u043f\u0440\u043e\u0431\u0443\u0439\u0442\u0435 \u0441\u043d\u043e\u0432\u0430.',
          icon: Icons.fingerprint,
          onRetry: () => ref.invalidate(_latestDnkResultProvider),
        ),
        data: (data) {
          if (data != null) {
            return _buildHasResult(data);
          }
          return _buildNoResult();
        },
      ),
    );
  }

  Widget _buildNoResult() {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hero card
              FadeInSlide(
                child: PremiumSectionCard(
                  radius: AurixTokens.radiusHero,
                  padding: const EdgeInsets.all(0),
                  glowColor: AurixTokens.accent,
                  child: Column(
                    children: [
                      // Visual header with animated fingerprint
                      _DnkVisualHeader(),
                      // Content
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                        child: Column(
                          children: [
                            // System label
                            FadeInSlide(
                              delayMs: 60,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AurixTokens.accent.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: AurixTokens.positive,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AurixTokens.positive.withValues(alpha: 0.5),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      'IDENTITY ENGINE',
                                      style: TextStyle(
                                        fontFamily: AurixTokens.fontMono,
                                        color: AurixTokens.accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Title
                            FadeInSlide(
                              delayMs: 100,
                              child: Text(
                                'DNK \u0410\u0440\u0442\u0438\u0441\u0442\u0430',
                                style: TextStyle(
                                  fontFamily: AurixTokens.fontHeading,
                                  color: AurixTokens.text,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Description
                            FadeInSlide(
                              delayMs: 150,
                              child: Text(
                                '\u041f\u0440\u043e\u0439\u0434\u0438 \u0438\u043d\u0442\u0435\u0440\u0432\u044c\u044e \u0438\u0437 ~24 \u043a\u043b\u044e\u0447\u0435\u0432\u044b\u0445 \u0432\u043e\u043f\u0440\u043e\u0441\u043e\u0432 \u0438 \u043f\u043e\u043b\u0443\u0447\u0438 \u0443\u043d\u0438\u043a\u0430\u043b\u044c\u043d\u044b\u0439 '
                                '\u0430\u0440\u0442\u0438\u0441\u0442\u0438\u0447\u0435\u0441\u043a\u0438\u0439 \u043f\u0440\u043e\u0444\u0438\u043b\u044c: \u0441\u0442\u0438\u043b\u044c, \u043f\u043e\u0432\u0435\u0434\u0435\u043d\u0438\u0435, \u0441\u043e\u0446\u0438\u0430\u043b\u044c\u043d\u044b\u0439 \u043c\u0430\u0433\u043d\u0435\u0442\u0438\u0437\u043c, '
                                '\u0440\u0435\u043a\u043e\u043c\u0435\u043d\u0434\u0430\u0446\u0438\u0438 \u043f\u043e \u043c\u0443\u0437\u044b\u043a\u0435, \u043a\u043e\u043d\u0442\u0435\u043d\u0442\u0443 \u0438 \u0432\u0438\u0437\u0443\u0430\u043b\u0443.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AurixTokens.fontBody,
                                  color: AurixTokens.muted,
                                  fontSize: 14,
                                  height: 1.55,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Feature chips
                            FadeInSlide(
                              delayMs: 200,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  _FeatureChip(icon: Icons.timer_rounded, label: '~9 \u043c\u0438\u043d'),
                                  _FeatureChip(icon: Icons.radar_rounded, label: '12 \u043e\u0441\u0435\u0439'),
                                  _FeatureChip(icon: Icons.auto_awesome_rounded, label: 'AI-\u043f\u0440\u043e\u0444\u0430\u0439\u043b'),
                                  _FeatureChip(icon: Icons.whatshot_rounded, label: '\u041c\u0430\u0433\u043d\u0435\u0442\u0438\u0437\u043c'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            // CTA buttons
                            FadeInSlide(
                              delayMs: 250,
                              child: _StartButton(
                                starting: _starting,
                                onTap: _startInterview,
                              ),
                            ),
                            if (kEnableDnkTests) ...[
                              const SizedBox(height: 12),
                              FadeInSlide(
                                delayMs: 300,
                                child: _TestsButton(
                                  onTap: () => context.go('/dnk/tests'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHasResult(Map<String, dynamic> raw) {
    final axesRaw = (raw['axes'] as Map<String, dynamic>?) ?? {};
    final confRaw = (raw['confidence'] as Map<String, dynamic>?) ?? {};
    final recsRaw = (raw['recommendations'] as Map<String, dynamic>?) ?? {};
    final promptsRaw = (raw['prompts'] as Map<String, dynamic>?) ?? {};
    final tagsRaw = (raw['raw_features'] as Map<String, dynamic>?)?['tags'] as List? ?? [];

    var socialAxesRaw = (raw['social_axes'] as Map<String, dynamic>?) ?? {};
    if (socialAxesRaw.isEmpty && recsRaw['_social_axes'] is Map<String, dynamic>) {
      socialAxesRaw = recsRaw['_social_axes'] as Map<String, dynamic>;
    }

    Map<String, dynamic>? socialSummaryRaw;
    if (raw['social_summary'] is Map<String, dynamic>) {
      socialSummaryRaw = raw['social_summary'] as Map<String, dynamic>;
    } else if (recsRaw['social_summary'] is Map<String, dynamic>) {
      socialSummaryRaw = recsRaw['social_summary'] as Map<String, dynamic>;
    }
    Map<String, dynamic>? passportHeroRaw;
    if (raw['passport_hero'] is Map<String, dynamic>) {
      passportHeroRaw = raw['passport_hero'] as Map<String, dynamic>;
    } else if (recsRaw['passport_hero'] is Map<String, dynamic>) {
      passportHeroRaw = recsRaw['passport_hero'] as Map<String, dynamic>;
    }

    final profileShort = (raw['profile_short'] ?? recsRaw['_profile_short'] ?? '').toString();
    final profileFull = (raw['profile_full'] ?? recsRaw['_profile_full'] ?? raw['profile_text'] ?? '').toString();

    final result = DnkResult(
      resultId: raw['id']?.toString(),
      axes: DnkAxes.fromJson(axesRaw, confRaw),
      socialAxes: DnkSocialAxes.fromJson(socialAxesRaw),
      socialSummary: DnkSocialSummary.fromJson(socialSummaryRaw),
      passportHero: DnkPassportHero.fromJson(passportHeroRaw),
      profileText: (raw['profile_text'] ?? '').toString(),
      profileShort: profileShort,
      profileFull: profileFull,
      recommendations: DnkRecommendations.fromJson(recsRaw),
      prompts: DnkPrompts.fromJson(promptsRaw),
      tags: tagsRaw.map((t) => t.toString()).toList(),
      regenCount: (raw['regen_count'] is num) ? (raw['regen_count'] as num).toInt() : 0,
    );

    final sessionId = raw['session_id']?.toString();

    return Stack(
      children: [
        DnkResultScreen(
          result: result,
          sessionId: sessionId,
          onRegenerate: sessionId != null ? () => _regenerate(sessionId, 'normal') : null,
          onRegenerateHard: sessionId != null ? () => _regenerate(sessionId, 'hard') : null,
          onStartNew: _startInterview,
        ),
        if (kEnableDnkTests)
          Positioned(
            right: 20,
            bottom: 20,
            child: _TestsButton(onTap: () => context.go('/dnk/tests')),
          ),
      ],
    );
  }

  Future<void> _regenerate(String sessionId, String styleLevel) async {
    setState(() => _starting = true);
    try {
      final answersRes = await ApiClient.get('/api/ai/dnk-answers', query: {
        'session_id': sessionId,
      });
      final rows = asList(answersRes.data);
      if (rows.isEmpty) {
        throw Exception('\u041d\u0435\u0442 \u043e\u0442\u0432\u0435\u0442\u043e\u0432 \u0434\u043b\u044f \u043f\u0435\u0440\u0435\u0433\u0435\u043d\u0435\u0440\u0430\u0446\u0438\u0438. \u041f\u0440\u043e\u0439\u0434\u0438\u0442\u0435 \u0438\u043d\u0442\u0435\u0440\u0432\u044c\u044e \u0437\u0430\u043d\u043e\u0432\u043e.');
      }

      final answers = rows.map<Map<String, dynamic>>((r) {
        final m = r as Map<String, dynamic>;
        String answerType = (m['answer_type'] ?? 'open_text').toString();
        if (answerType == 'choice') answerType = 'forced_choice';
        if (answerType == 'open_text') answerType = 'open';
        return {
          'question_id': m['question_id'],
          'answer_type': answerType,
          'answer_json': m['answer_json'] is Map ? m['answer_json'] : {},
        };
      }).toList();

      await ApiClient.post('/api/ai/dnk', data: {
        'answers': answers,
        'style_level': styleLevel,
      });

      ref.invalidate(_latestDnkResultProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Visual Header with animated fingerprint
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _DnkVisualHeader extends StatefulWidget {
  @override
  State<_DnkVisualHeader> createState() => _DnkVisualHeaderState();
}

class _DnkVisualHeaderState extends State<_DnkVisualHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
          child: SizedBox(
            height: 160,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AurixTokens.accent.withValues(alpha: 0.06),
                          AurixTokens.bg0.withValues(alpha: 0.8),
                          AurixTokens.aiAccent.withValues(alpha: 0.04),
                        ],
                      ),
                    ),
                  ),
                ),
                // Animated glow
                Positioned(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AurixTokens.accent.withValues(
                            alpha: 0.08 + math.sin(_pulse.value * math.pi * 2) * 0.04,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Grid overlay
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPainter(opacity: 0.04),
                  ),
                ),
                // Fingerprint icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AurixTokens.bg0.withValues(alpha: 0.4),
                    border: Border.all(
                      color: AurixTokens.accent.withValues(
                        alpha: 0.2 + math.sin(_pulse.value * math.pi * 2) * 0.1,
                      ),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AurixTokens.accent.withValues(
                          alpha: 0.12 + math.sin(_pulse.value * math.pi * 2) * 0.06,
                        ),
                        blurRadius: 24,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: 36,
                    color: AurixTokens.accent.withValues(
                      alpha: 0.7 + math.sin(_pulse.value * math.pi * 2) * 0.15,
                    ),
                  ),
                ),
                // Orbiting dots
                for (int i = 0; i < 3; i++)
                  Positioned(
                    left: 50 + math.cos((_pulse.value * math.pi * 2) + i * math.pi * 2 / 3) * 55 +
                        (MediaQuery.sizeOf(context).width / 2 - 50),
                    top: 80 + math.sin((_pulse.value * math.pi * 2) + i * math.pi * 2 / 3) * 40,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: [
                          AurixTokens.accent,
                          AurixTokens.aiAccent,
                          AurixTokens.positive,
                        ][i]
                            .withValues(alpha: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: [
                              AurixTokens.accent,
                              AurixTokens.aiAccent,
                              AurixTokens.positive,
                            ][i]
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Feature Chip
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AurixTokens.surface1.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
        border: Border.all(color: AurixTokens.stroke(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AurixTokens.accent.withValues(alpha: 0.6)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AurixTokens.fontBody,
              color: AurixTokens.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Start & Tests Buttons
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _StartButton extends StatefulWidget {
  const _StartButton({required this.starting, required this.onTap});
  final bool starting;
  final VoidCallback onTap;

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.starting ? null : widget.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dMedium,
          curve: AurixTokens.cEase,
          width: 260,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                AurixTokens.accent.withValues(alpha: _hovered ? 0.25 : 0.18),
                AurixTokens.aiAccent.withValues(alpha: _hovered ? 0.18 : 0.1),
              ],
            ),
            border: Border.all(
              color: AurixTokens.accent.withValues(alpha: _hovered ? 0.45 : 0.3),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AurixTokens.accent.withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.starting)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AurixTokens.accent.withValues(alpha: 0.7),
                  ),
                )
              else
                Icon(Icons.play_arrow_rounded, size: 20, color: AurixTokens.accent),
              const SizedBox(width: 8),
              Text(
                widget.starting
                    ? '\u0421\u043e\u0437\u0434\u0430\u0451\u043c \u0441\u0435\u0441\u0441\u0438\u044e\u2026'
                    : '\u041d\u0430\u0447\u0430\u0442\u044c DNK \u0410\u0440\u0442\u0438\u0441\u0442\u0430',
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: AurixTokens.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestsButton extends StatefulWidget {
  const _TestsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_TestsButton> createState() => _TestsButtonState();
}

class _TestsButtonState extends State<_TestsButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _hovered
                ? AurixTokens.surface2.withValues(alpha: 0.5)
                : Colors.transparent,
            border: Border.all(
              color: _hovered
                  ? AurixTokens.stroke(0.25)
                  : AurixTokens.stroke(0.14),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology_alt_outlined,
                size: 16,
                color: _hovered ? AurixTokens.text : AurixTokens.muted,
              ),
              const SizedBox(width: 6),
              Text(
                '\u041f\u0440\u043e\u0444. \u0442\u0435\u0441\u0442\u044b DNK',
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: _hovered ? AurixTokens.text : AurixTokens.muted,
                  fontSize: 13,
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

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Grid Painter
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AurixTokens.text.withValues(alpha: opacity)
      ..strokeWidth = 0.5;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.opacity != opacity;
}
