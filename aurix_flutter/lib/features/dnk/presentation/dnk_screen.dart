import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import '../data/dnk_models.dart';
import '../data/dnk_service.dart';
import 'dnk_interview_screen.dart';
import 'dnk_result_screen.dart';

/// Fetches the latest finished DNK result for current user
final _latestDnkResultProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final rows = await supabase
      .from('dnk_results')
      .select('*, dnk_sessions!inner(user_id, status)')
      .eq('dnk_sessions.user_id', user.id)
      .eq('dnk_sessions.status', 'finished')
      .order('created_at', ascending: false)
      .limit(1);

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
      final service = DnkService();
      final sessionId = await service.startSession(user.id);
      if (!mounted) return;

      final result = await Navigator.of(context).push<DnkResult>(
        MaterialPageRoute(
          builder: (_) => DnkInterviewScreen(sessionId: sessionId),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.negative)),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AurixTokens.accent, AurixTokens.accentMuted],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.fingerprint, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'Aurix DNK',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Пройди интервью из 37 вопросов и получи уникальный '
              'артистический профиль: стиль, поведение, социальный магнетизм, '
              'рекомендации по музыке, контенту и визуалу.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AurixTokens.textSecondary, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              '~15 минут • 12 осей • AI-профайл • Социальный магнетизм',
              style: TextStyle(color: AurixTokens.muted, fontSize: 13),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 260,
              height: 52,
              child: FilledButton.icon(
                onPressed: _starting ? null : _startInterview,
                icon: _starting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_starting ? 'Создаём сессию…' : 'Начать Aurix DNK'),
                style: FilledButton.styleFrom(
                  backgroundColor: AurixTokens.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
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

    return DnkResultScreen(
      result: result,
      sessionId: sessionId,
      onRegenerate: sessionId != null ? () => _regenerate(sessionId, 'normal') : null,
      onRegenerateHard: sessionId != null ? () => _regenerate(sessionId, 'hard') : null,
      onStartNew: _startInterview,
    );
  }

  Future<void> _regenerate(String sessionId, String styleLevel) async {
    setState(() => _starting = true);
    try {
      final service = DnkService();
      await service.finishAndWait(sessionId, styleLevel: styleLevel);
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
