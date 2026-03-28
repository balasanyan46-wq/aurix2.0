import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
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

  // Backend returns a single object or null
  if (data == null || data == '' || (data is String && data.isEmpty)) return null;
  if (data is Map<String, dynamic>) return data;

  // Fallback: if it's a list (backward compat)
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
        loading: () => const PremiumLoadingState(message: 'Загрузка DNK профиля…'),
        error: (e, _) => PremiumErrorState(
          title: 'Не удалось загрузить',
          message: 'Проверьте подключение к сети и попробуйте снова.',
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: FadeInSlide(
          child: PremiumSectionCard(
            radius: AurixTokens.radiusHero,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AurixTokens.accent.withValues(alpha: 0.15),
                        AurixTokens.bg2.withValues(alpha: 0.9),
                      ],
                    ),
                    border: Border.all(color: AurixTokens.stroke(0.2)),
                  ),
                  child: const Icon(Icons.fingerprint, size: 38, color: AurixTokens.accent),
                ),
                const SizedBox(height: 24),
                FadeInSlide(
                  delayMs: 100,
                  child: Text(
                    'DNK Артиста',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AurixTokens.text,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeInSlide(
                  delayMs: 150,
                  child: const Text(
                    'Пройди интервью из ~24 ключевых вопросов и получи уникальный '
                    'артистический профиль: стиль, поведение, социальный магнетизм, '
                    'рекомендации по музыке, контенту и визуалу.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14.5, height: 1.55),
                  ),
                ),
                const SizedBox(height: 10),
                FadeInSlide(
                  delayMs: 200,
                  child: Wrap(
                    spacing: 6,
                    children: ['~9 мин', '12 осей', 'AI-профайл', 'Магнетизм'].map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AurixTokens.glass(0.05),
                        borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
                        border: Border.all(color: AurixTokens.stroke(0.12)),
                      ),
                      child: Text(t, style: const TextStyle(color: AurixTokens.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 28),
                FadeInSlide(
                  delayMs: 250,
                  child: SizedBox(
                    width: 260,
                    height: 52,
                    child: PremiumHoverLift(
                      child: FilledButton.icon(
                        onPressed: _starting ? null : _startInterview,
                        icon: _starting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_arrow_rounded),
                        label: Text(_starting ? 'Создаём сессию…' : 'Начать DNK Артиста'),
                      ),
                    ),
                  ),
                ),
                if (kEnableDnkTests) ...[
                  const SizedBox(height: 12),
                  FadeInSlide(
                    delayMs: 300,
                    child: SizedBox(
                      width: 260,
                      height: 48,
                      child: PremiumHoverLift(
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/dnk/tests'),
                          icon: const Icon(Icons.psychology_alt_outlined, size: 18),
                          label: const Text('Проф. тесты DNK'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AurixTokens.textSecondary,
                            side: BorderSide(color: AurixTokens.stroke(0.22)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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

    // social_axes: top-level (direct response) or inside recommendations._social_axes (DB)
    var socialAxesRaw = (raw['social_axes'] as Map<String, dynamic>?) ?? {};
    if (socialAxesRaw.isEmpty && recsRaw['_social_axes'] is Map<String, dynamic>) {
      socialAxesRaw = recsRaw['_social_axes'] as Map<String, dynamic>;
    }

    // social_summary / passport_hero stored inside recommendations in DB
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

    // profile_short / profile_full stored inside recommendations._profile_short/_profile_full in DB
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
            child: FilledButton.icon(
              onPressed: () => context.go('/dnk/tests'),
              icon: const Icon(Icons.psychology_alt_outlined),
              label: const Text('Проф. тесты'),
              style: FilledButton.styleFrom(
                backgroundColor: AurixTokens.bg2,
                foregroundColor: AurixTokens.text,
                side: const BorderSide(color: AurixTokens.border),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _regenerate(String sessionId, String styleLevel) async {
    setState(() => _starting = true);
    try {
      // Re-fetch answers from the session and regenerate via NestJS
      final answersRes = await ApiClient.get('/api/ai/dnk-answers', query: {
        'session_id': sessionId,
      });
      final rows = asList(answersRes.data);
      if (rows.isEmpty) {
        throw Exception('Нет ответов для перегенерации. Пройдите интервью заново.');
      }

      final answers = rows.map<Map<String, dynamic>>((r) {
        final m = r as Map<String, dynamic>;
        // Map DB answer_type back to service type
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
