import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/providers/artist_provider.dart';
import 'package:aurix_flutter/ai/ai_service.dart';
import 'models/track_analysis.dart';
import 'models/artist_profile.dart';
import 'models/ai_character.dart';
import 'models/ai_session.dart';
import 'models/audio_analysis_result.dart';
import 'services/track_analysis_service.dart';
import 'widgets/energy_graph.dart';
import 'character_screen.dart';

/// Track analysis screen — text OR audio upload → AI producer analysis.
class TrackAnalysisScreen extends ConsumerStatefulWidget {
  final String? pipelineContent;
  final AiSession? session;

  const TrackAnalysisScreen({super.key, this.pipelineContent, this.session});

  @override
  ConsumerState<TrackAnalysisScreen> createState() =>
      _TrackAnalysisScreenState();
}

class _TrackAnalysisScreenState extends ConsumerState<TrackAnalysisScreen>
    with TickerProviderStateMixin {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _xpAwarded = false;

  // Text-based analysis result
  TrackAnalysis? _textResult;

  // Audio-based analysis result
  AudioAnalysisResult? _audioResult;

  // Loading state
  int _loadingStep = 0;
  Timer? _loadingTimer;
  late AnimationController _pulseCtrl;

  static const _loadingSteps = [
    'AI слушает трек...',
    'Анализирую структуру...',
    'Ищу хук и слабые места...',
    'Оцениваю продакшн...',
    'Формирую продюсерский разбор...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    if (widget.pipelineContent != null && widget.pipelineContent!.isNotEmpty) {
      _ctrl.text = widget.pipelineContent!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _analyzeText());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _loadingTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Text-based analysis ──
  Future<void> _analyzeText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _textResult = null;
      _audioResult = null;
      _xpAwarded = false;
    });

    try {
      final profile = ref.read(artistProfileProvider);
      final memory = ref.read(aiMemoryProvider);
      final result = await TrackAnalysisService.analyze(
        inputText: text,
        profile: profile,
        memory: memory,
      );
      if (!mounted) return;
      if (!_xpAwarded) {
        _xpAwarded = true;
        if (result.isPotentialHit) {
          ref.read(artistProfileProvider.notifier).awardXp(XpAction.hitAnalysis);
        } else if (result.isHit) {
          ref.read(artistProfileProvider.notifier).awardXp(XpAction.pipeline);
        }
        ref.read(aiMemoryProvider.notifier).addEntry(
          'analysis',
          'Анализ трека: ${text.length > 80 ? '${text.substring(0, 80)}...' : text}',
          'Score: ${result.score}/10 — ${result.verdict}',
        );
      }
      setState(() {
        _textResult = result;
        _loading = false;
      });
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Ошибка анализа'; _loading = false; });
    }
  }

  // ── Audio upload + analysis ──
  Future<void> _pickAndAnalyzeAudio() async {
    if (_loading) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      setState(() => _error = 'Не удалось прочитать файл');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _textResult = null;
      _audioResult = null;
      _loadingStep = 0;
    });

    // Animate loading steps
    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _loadingStep = (_loadingStep + 1) % _loadingSteps.length;
      });
    });

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        ),
        if (_ctrl.text.trim().isNotEmpty) 'lyrics': _ctrl.text.trim(),
      });

      final response = await ApiClient.dio.post(
        '/api/ai/analyze-track',
        data: formData,
        options: Options(
          receiveTimeout: const Duration(minutes: 3),
          sendTimeout: const Duration(minutes: 2),
        ),
      );

      if (!mounted) return;

      final data = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : <String, dynamic>{};
      final audioResult = AudioAnalysisResult.fromApiResponse(data);

      setState(() {
        _audioResult = audioResult;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      setState(() {
        _error = msg ?? 'Ошибка анализа аудио';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка: $e';
        _loading = false;
      });
    } finally {
      _loadingTimer?.cancel();
    }
  }

  void _goToCharacter(String characterId) {
    final char = aiCharacters.firstWhere((c) => c.id == characterId);
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              CharacterScreen(character: char, session: widget.session)),
    );
  }

  void _reset() => setState(() {
        _textResult = null;
        _audioResult = null;
        _xpAwarded = false;
        _error = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.insights_rounded, size: 20, color: AurixTokens.accent),
          SizedBox(width: 10),
          Text('Анализ трека',
              style: TextStyle(
                  color: AurixTokens.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
        ]),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _audioResult != null
              ? _buildAudioResult()
              : _textResult != null
                  ? _buildTextResult()
                  : _loading
                      ? _buildLoading()
                      : _buildInput(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // INPUT — text + audio upload
  // ══════════════════════════════════════════════════════════════

  Widget _buildInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // Icon
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AurixTokens.accent
                    .withValues(alpha: 0.12 + _pulseCtrl.value * 0.08),
                AurixTokens.accent.withValues(alpha: 0.03),
              ]),
              boxShadow: [
                BoxShadow(
                    color: AurixTokens.accent.withValues(alpha: 0.1),
                    blurRadius: 32,
                    spreadRadius: -8)
              ],
            ),
            child: const Icon(Icons.graphic_eq_rounded,
                size: 36, color: AurixTokens.accent),
          ),
        ),
        const SizedBox(height: 16),
        Text('Продюсерский анализ',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AurixTokens.accent.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          'Загрузи аудио или вставь текст',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 13),
        ),

        const SizedBox(height: 24),

        // ── AUDIO UPLOAD BUTTON ──
        _AudioUploadCard(onTap: _pickAndAnalyzeAudio),

        const SizedBox(height: 16),

        // Divider
        Row(children: [
          Expanded(
              child:
                  Divider(color: AurixTokens.stroke(0.1), thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('или текст',
                style: TextStyle(
                    color: AurixTokens.muted.withValues(alpha: 0.4),
                    fontSize: 12)),
          ),
          Expanded(
              child:
                  Divider(color: AurixTokens.stroke(0.1), thickness: 0.5)),
        ]),

        const SizedBox(height: 16),

        // Text input
        TextField(
          controller: _ctrl,
          maxLines: 6,
          minLines: 3,
          style: const TextStyle(color: AurixTokens.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Концепция, текст, хук, описание трека...',
            hintStyle:
                TextStyle(color: AurixTokens.muted.withValues(alpha: 0.45)),
            filled: true,
            fillColor: AurixTokens.glass(0.06),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AurixTokens.stroke(0.12))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: AurixTokens.accent.withValues(alpha: 0.4))),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),

        const SizedBox(height: 16),

        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AurixTokens.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AurixTokens.danger.withValues(alpha: 0.15)),
            ),
            child: Text(_error!,
                style: TextStyle(
                    color: AurixTokens.danger.withValues(alpha: 0.9),
                    fontSize: 13)),
          ),
          const SizedBox(height: 16),
        ],

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed:
                _ctrl.text.trim().isEmpty ? null : _analyzeText,
            icon: const Icon(Icons.insights_rounded, size: 20),
            label: const Text('Анализировать текст',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AurixTokens.glass(0.1),
              disabledForegroundColor:
                  AurixTokens.muted.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LOADING — "AI слушает трек"
  // ══════════════════════════════════════════════════════════════

  Widget _buildLoading() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      // Pulsing waveform icon
      AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) {
          final scale = 1.0 + _pulseCtrl.value * 0.15;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AurixTokens.accent.withValues(alpha: 0.2),
                  AurixTokens.accent.withValues(alpha: 0.05),
                ]),
                boxShadow: [
                  BoxShadow(
                      color: AurixTokens.accent
                          .withValues(alpha: 0.15 + _pulseCtrl.value * 0.1),
                      blurRadius: 40,
                      spreadRadius: -8)
                ],
              ),
              child: const Icon(Icons.graphic_eq_rounded,
                  size: 40, color: AurixTokens.accent),
            ),
          );
        },
      ),
      const SizedBox(height: 28),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: Text(
          _loadingSteps[_loadingStep],
          key: ValueKey(_loadingStep),
          style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            backgroundColor: AurixTokens.glass(0.08),
            color: AurixTokens.accent,
            minHeight: 4,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Обычно занимает 15–30 сек',
        style: TextStyle(
            color: AurixTokens.muted.withValues(alpha: 0.5), fontSize: 12),
      ),
    ]);
  }

  // ══════════════════════════════════════════════════════════════
  // AUDIO RESULT — full producer analysis
  // ══════════════════════════════════════════════════════════════

  Widget _buildAudioResult() {
    final r = _audioResult!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // ══════════ HIT PREDICTOR BLOCK ══════════
        _HitPredictorCard(result: r),
        const SizedBox(height: 20),

        // ── Retention killer (WOW effect) ──
        if (r.earlyEnergy < 0.7) ...[
          _RetentionKillerCard(earlyEnergy: r.earlyEnergy, text: r.retentionKiller),
          const SizedBox(height: 16),
        ],

        // ── Killer issue ──
        if (r.killerIssue.isNotEmpty) ...[
          _WarningCard(
            icon: Icons.dangerous_rounded,
            title: 'Что убивает вирусность',
            text: r.killerIssue,
          ),
          const SizedBox(height: 16),
        ],

        // ── Main problem ──
        if (r.mainProblem.isNotEmpty) ...[
          _WarningCard(
            icon: Icons.error_outline_rounded,
            title: 'Главный провал',
            text: r.mainProblem,
          ),
          const SizedBox(height: 20),
        ],

        // Score hero
        _ScoreHero(score: r.score),
        const SizedBox(height: 16),

        // Genre badge
        if (r.genreGuess.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AurixTokens.aiAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AurixTokens.aiAccent.withValues(alpha: 0.2)),
            ),
            child: Text(r.genreGuess,
                style: TextStyle(
                    color: AurixTokens.aiAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 20),

        // ── Audio metrics row ──
        _MetricsRow(result: r),
        const SizedBox(height: 20),

        // ── Energy graph ──
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.show_chart_rounded,
                size: 16, color: AurixTokens.accent.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text('Энергия трека',
                style: TextStyle(
                    color: AurixTokens.text.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            if (r.hookTime > 0)
              _LegendDot(
                  color: const Color(0xFF22C55E), label: 'Hook ${r.hookTime.toStringAsFixed(0)}s'),
            const SizedBox(width: 12),
            if (r.dropTime > 0)
              _LegendDot(
                  color: AurixTokens.danger, label: 'Drop ${r.dropTime.toStringAsFixed(0)}s'),
          ]),
          const SizedBox(height: 8),
          EnergyGraph(
            structure: r.structure,
            hookTime: r.hookTime,
            dropTime: r.dropTime,
            duration: r.duration,
          ),
        ]),
        const SizedBox(height: 20),

        // ── Intro warning ──
        if (r.introWeak) ...[
          _WarningCard(
            icon: Icons.warning_amber_rounded,
            title: 'Слабое интро',
            text: r.introAnalysis.isNotEmpty
                ? r.introAnalysis
                : 'Первые 8 секунд — энергия ниже 40%. Слушатель может уйти.',
          ),
          const SizedBox(height: 16),
        ],

        // ── Sub-scores ──
        _ProducerScores(result: r),
        const SizedBox(height: 20),

        // ── Verdict ──
        if (r.verdict.isNotEmpty) ...[
          _VerdictCard(verdict: r.verdict),
          const SizedBox(height: 20),
        ],

        // ── Structure verdict ──
        if (r.structureVerdict.isNotEmpty) ...[
          _AnalysisCard(
              icon: Icons.architecture_rounded,
              title: 'Структура',
              text: r.structureVerdict,
              accent: AurixTokens.aiAccent),
          const SizedBox(height: 16),
        ],

        // ── Hook analysis ──
        if (r.hookAnalysis.isNotEmpty) ...[
          _AnalysisCard(
              icon: Icons.music_note_rounded,
              title: 'Хук (${r.hookTime.toStringAsFixed(0)}s)',
              text: r.hookAnalysis,
              accent: const Color(0xFF22C55E)),
          const SizedBox(height: 16),
        ],

        // ── Drop analysis ──
        if (r.dropAnalysis.isNotEmpty) ...[
          _AnalysisCard(
              icon: Icons.trending_down_rounded,
              title: 'Дроп${r.dropTime > 0 ? ' (${r.dropTime.toStringAsFixed(0)}s)' : ''}',
              text: r.dropAnalysis,
              accent: AurixTokens.warning),
          const SizedBox(height: 16),
        ],

        // ── Lyrics (transcribed by Whisper) ──
        if (r.lyrics != null && r.lyrics!.isNotEmpty) ...[
          _LyricsCard(lyrics: r.lyrics!, analysis: r.lyricsAnalysis),
          const SizedBox(height: 16),
        ],

        // ── Listener dropout ──
        if (r.listenerDropout.isNotEmpty) ...[
          _WarningCard(
            icon: Icons.person_off_rounded,
            title: 'Где слушатель уходит',
            text: r.listenerDropout,
          ),
          const SizedBox(height: 16),
        ],

        // ── Strengths ──
        if (r.strengths.isNotEmpty) ...[
          _ListCard(
              title: 'Сильные стороны',
              items: r.strengths,
              icon: Icons.thumb_up_rounded,
              accent: AurixTokens.positive),
          const SizedBox(height: 16),
        ],

        // ── Problems ──
        if (r.problems.isNotEmpty) ...[
          _ListCard(
              title: 'Проблемы',
              items: r.problems,
              icon: Icons.warning_rounded,
              accent: AurixTokens.danger),
          const SizedBox(height: 16),
        ],

        // ── Fix timestamps ──
        if (r.fixTimestamps.isNotEmpty) ...[
          _FixTimestampsCard(fixes: r.fixTimestamps),
          const SizedBox(height: 16),
        ],

        // ── Improvements (with timestamps) ──
        if (r.improvementsDetailed.isNotEmpty) ...[
          _ImprovementsCard(improvements: r.improvementsDetailed),
          const SizedBox(height: 16),
        ],

        // ── Mix notes ──
        if (r.mixNotes.isNotEmpty) ...[
          _AnalysisCard(
              icon: Icons.tune_rounded,
              title: 'Микс и мастеринг',
              text: r.mixNotes,
              accent: AurixTokens.accent),
          const SizedBox(height: 16),
        ],

        // ── Market fit ──
        if (r.marketFit.isNotEmpty) ...[
          _AnalysisCard(
              icon: Icons.trending_up_rounded,
              title: 'Рынок и тренды',
              text: r.marketFit,
              accent: AurixTokens.positive),
          const SizedBox(height: 16),
        ],

        // ── TikTok segment ──
        if (r.bestTiktokSegment.isNotEmpty) ...[
          _TikTokCard(segment: r.bestTiktokSegment),
          const SizedBox(height: 16),
        ],

        // ── Can be hit + recipe ──
        if (r.canBeHit && r.hitRecipe.isNotEmpty) ...[
          _HitRecipeCard(recipe: r.hitRecipe),
          const SizedBox(height: 16),
        ],

        // ── Final opinion ──
        if (r.finalOpinion.isNotEmpty) ...[
          _FinalOpinionCard(opinion: r.finalOpinion),
          const SizedBox(height: 24),
        ],

        // ── "Сделать хит" CTA ──
        _MakeHitButton(onTap: () => _goToCharacter('producer')),
        const SizedBox(height: 16),

        // ── Action buttons ──
        _ActionButtons(
          onImprove: () => _goToCharacter('producer'),
          onCover: () => _goToCharacter('visual'),
          onVideo: () => _goToCharacter('smm'),
          onRetry: _reset,
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TEXT RESULT — existing simple analysis
  // ══════════════════════════════════════════════════════════════

  Widget _buildTextResult() {
    final r = _textResult!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        _ScoreHero(score: r.score),
        const SizedBox(height: 24),
        if (r.isPotentialHit) ...[_AchievementBadge(), const SizedBox(height: 20)],
        _SubScores(
            hook: r.hookScore,
            vibe: r.vibeScore,
            originality: r.originalityScore),
        const SizedBox(height: 20),
        _VerdictCard(verdict: r.verdict),
        const SizedBox(height: 20),
        if (r.strengths.isNotEmpty) ...[
          _ListCard(
              title: 'Сильные стороны',
              items: r.strengths,
              icon: Icons.thumb_up_rounded,
              accent: AurixTokens.positive),
          const SizedBox(height: 16),
        ],
        if (r.weaknesses.isNotEmpty) ...[
          _ListCard(
              title: 'Слабые места',
              items: r.weaknesses,
              icon: Icons.warning_rounded,
              accent: AurixTokens.warning),
          const SizedBox(height: 16),
        ],
        if (r.recommendations.isNotEmpty) ...[
          _ListCard(
              title: 'Как усилить',
              items: r.recommendations,
              icon: Icons.rocket_launch_rounded,
              accent: AurixTokens.aiAccent),
          const SizedBox(height: 24),
        ],
        _ActionButtons(
          onImprove: () => _goToCharacter(
              r.hookScore < r.vibeScore ? 'writer' : 'producer'),
          onCover: () => _goToCharacter('visual'),
          onVideo: () => _goToCharacter('smm'),
          onRetry: _reset,
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Audio Upload Card
// ══════════════════════════════════════════════════════════════

class _AudioUploadCard extends StatefulWidget {
  final VoidCallback onTap;
  const _AudioUploadCard({required this.onTap});

  @override
  State<_AudioUploadCard> createState() => _AudioUploadCardState();
}

class _AudioUploadCardState extends State<_AudioUploadCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AurixTokens.accent
                    .withValues(alpha: _hovered ? 0.12 : 0.06),
                AurixTokens.aiAccent
                    .withValues(alpha: _hovered ? 0.08 : 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AurixTokens.accent
                    .withValues(alpha: _hovered ? 0.4 : 0.2)),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                        color: AurixTokens.accent.withValues(alpha: 0.1),
                        blurRadius: 24,
                        spreadRadius: -8)
                  ]
                : [],
          ),
          child: Column(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AurixTokens.accent.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.audio_file_rounded,
                  size: 28, color: AurixTokens.accent),
            ),
            const SizedBox(height: 12),
            const Text('Загрузить аудио файл',
                style: TextStyle(
                    color: AurixTokens.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('MP3, WAV, FLAC, M4A — до 100 МБ',
                style: TextStyle(
                    color: AurixTokens.muted.withValues(alpha: 0.5),
                    fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AurixTokens.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('AI проанализирует структуру, хук и слабые места',
                  style: TextStyle(
                      color: AurixTokens.accent.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Legend dot
// ══════════════════════════════════════════════════════════════

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 10)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// Metrics Row — BPM, Key, Energy, Duration
// ══════════════════════════════════════════════════════════════

class _MetricsRow extends StatelessWidget {
  final AudioAnalysisResult result;
  const _MetricsRow({required this.result});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: _MetricTile(
              label: 'BPM',
              value: result.bpm.toStringAsFixed(0),
              icon: Icons.speed_rounded)),
      const SizedBox(width: 8),
      Expanded(
          child: _MetricTile(
              label: 'Тональность',
              value: result.estimatedKey,
              icon: Icons.piano_rounded)),
      const SizedBox(width: 8),
      Expanded(
          child: _MetricTile(
              label: 'Энергия',
              value: '${(result.energy * 100).toStringAsFixed(0)}%',
              icon: Icons.bolt_rounded)),
      const SizedBox(width: 8),
      Expanded(
          child: _MetricTile(
              label: 'Длительность',
              value: result.durationFormatted,
              icon: Icons.timer_rounded)),
    ]);
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MetricTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.stroke(0.08)),
      ),
      child: Column(children: [
        Icon(icon, size: 18, color: AurixTokens.accent.withValues(alpha: 0.6)),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: AurixTokens.muted.withValues(alpha: 0.5),
                fontSize: 10)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Producer Scores — hook, production, viral, playlist
// ══════════════════════════════════════════════════════════════

class _ProducerScores extends StatelessWidget {
  final AudioAnalysisResult result;
  const _ProducerScores({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: Column(children: [
        _ScoreRow(
            label: 'Хук',
            score: result.hookPotential,
            icon: Icons.music_note_rounded),
        const SizedBox(height: 14),
        _ScoreRow(
            label: 'Продакшн',
            score: result.productionQuality,
            icon: Icons.equalizer_rounded),
        const SizedBox(height: 14),
        _ScoreRow(
            label: 'Вирусность',
            score: result.viralPotential,
            icon: Icons.whatshot_rounded),
        const SizedBox(height: 14),
        _ScoreRow(
            label: 'Плейлист',
            score: result.playlistChance,
            icon: Icons.playlist_add_check_rounded),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Warning Card
// ══════════════════════════════════════════════════════════════

class _WarningCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _WarningCard(
      {required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.15)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AurixTokens.danger.withValues(alpha: 0.12)),
          child: Icon(icon, size: 16, color: AurixTokens.danger),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: AurixTokens.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(text,
                    style: TextStyle(
                        color: AurixTokens.text.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.5)),
              ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Analysis Card
// ══════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════
// Lyrics Card — transcribed text + AI analysis
// ══════════════════════════════════════════════════════════════

class _LyricsCard extends StatefulWidget {
  final String lyrics;
  final String analysis;
  const _LyricsCard({required this.lyrics, this.analysis = ''});

  @override
  State<_LyricsCard> createState() => _LyricsCardState();
}

class _LyricsCardState extends State<_LyricsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final lines = widget.lyrics.split('\n');
    final preview = lines.take(8).join('\n');
    final hasMore = lines.length > 8;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.aiAccent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AurixTokens.aiAccent.withValues(alpha: 0.12)),
            child: Icon(Icons.lyrics_rounded, size: 16, color: AurixTokens.aiAccent),
          ),
          const SizedBox(width: 12),
          Text('Текст (распознан AI)',
              style: TextStyle(
                  color: AurixTokens.aiAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        Text(
          _expanded ? widget.lyrics : preview,
          style: TextStyle(
            color: AurixTokens.text.withValues(alpha: 0.85),
            fontSize: 13,
            height: 1.6,
            fontStyle: FontStyle.italic,
          ),
        ),
        if (hasMore) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Свернуть' : 'Показать весь текст (${lines.length} строк)',
              style: TextStyle(
                color: AurixTokens.aiAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (widget.analysis.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AurixTokens.text.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Анализ текста',
                  style: TextStyle(
                      color: AurixTokens.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(widget.analysis,
                  style: TextStyle(
                      color: AurixTokens.text.withValues(alpha: 0.8),
                      fontSize: 12,
                      height: 1.5)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color accent;
  const _AnalysisCard(
      {required this.icon,
      required this.title,
      required this.text,
      required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12)),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(text,
                    style: TextStyle(
                        color: AurixTokens.text.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.5)),
              ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Fix Timestamps Card
// ══════════════════════════════════════════════════════════════

class _FixTimestampsCard extends StatelessWidget {
  final List<FixTimestamp> fixes;
  const _FixTimestampsCard({required this.fixes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AurixTokens.warning.withValues(alpha: 0.06),
          Colors.transparent
        ]),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AurixTokens.warning.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.build_rounded,
              size: 18, color: AurixTokens.warning),
          const SizedBox(width: 8),
          Text('Конкретные правки',
              style: TextStyle(
                  color: AurixTokens.warning,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        ...fixes.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            AurixTokens.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                          '${f.time.toStringAsFixed(0)}s',
                          style: TextStyle(
                              color: AurixTokens.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.issue,
                                style: TextStyle(
                                    color: AurixTokens.text
                                        .withValues(alpha: 0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(f.fix,
                                style: TextStyle(
                                    color: AurixTokens.muted
                                        .withValues(alpha: 0.7),
                                    fontSize: 12,
                                    height: 1.4)),
                          ]),
                    ),
                  ]),
            )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TikTok Card
// ══════════════════════════════════════════════════════════════

class _TikTokCard extends StatelessWidget {
  final String segment;
  const _TikTokCard({required this.segment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFFFF0050).withValues(alpha: 0.06),
          const Color(0xFF00F2EA).withValues(alpha: 0.03),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFF0050).withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF0050).withValues(alpha: 0.12)),
          child: const Icon(Icons.music_video_rounded,
              size: 18, color: Color(0xFFFF0050)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Лучший фрагмент для TikTok',
                    style: TextStyle(
                        color: Color(0xFFFF0050),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(segment,
                    style: TextStyle(
                        color: AurixTokens.text.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Shared widgets (Score Hero, Sub-scores, Verdict, List, Actions)
// ══════════════════════════════════════════════════════════════

class _ScoreHero extends StatefulWidget {
  final double score;
  const _ScoreHero({required this.score});

  @override
  State<_ScoreHero> createState() => _ScoreHeroState();
}

class _ScoreHeroState extends State<_ScoreHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _scoreAnim = Tween<double>(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _scoreColor(double s) {
    if (s >= 7) return AurixTokens.positive;
    if (s >= 4) return AurixTokens.warning;
    return AurixTokens.danger;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scoreAnim,
      builder: (_, __) {
        final s = _scoreAnim.value;
        final color = _scoreColor(s);
        return Container(
          padding:
              const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.12),
                AurixTokens.bg2.withValues(alpha: 0.3)
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 40,
                  spreadRadius: -12)
            ],
          ),
          child: Column(children: [
            Text('ПОТЕНЦИАЛ',
                style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2)),
            const SizedBox(height: 12),
            Text(
              s.toStringAsFixed(1),
              style: TextStyle(
                  color: color,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2),
            ),
            Text('/ 10',
                style: TextStyle(
                    color: color.withValues(alpha: 0.5),
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: s / 10,
                backgroundColor: AurixTokens.glass(0.08),
                color: color,
                minHeight: 6,
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _AchievementBadge extends StatefulWidget {
  @override
  State<_AchievementBadge> createState() => _AchievementBadgeState();
}

class _AchievementBadgeState extends State<_AchievementBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final glow = 0.1 + _ctrl.value * 0.12;
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AurixTokens.accent.withValues(alpha: glow),
              AurixTokens.accent.withValues(alpha: 0.03)
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AurixTokens.accent
                    .withValues(alpha: 0.3 + _ctrl.value * 0.15)),
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('\u{1F451}',
                    style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text('Потенциальный хит!',
                    style: TextStyle(
                        color: AurixTokens.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text('+30 XP',
                    style: TextStyle(
                        color: AurixTokens.positive,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
        );
      },
    );
  }
}

class _SubScores extends StatelessWidget {
  final double hook;
  final double vibe;
  final double originality;
  const _SubScores(
      {required this.hook, required this.vibe, required this.originality});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: Column(children: [
        _ScoreRow(
            label: 'Хук', score: hook, icon: Icons.music_note_rounded),
        const SizedBox(height: 14),
        _ScoreRow(
            label: 'Вайб', score: vibe, icon: Icons.waves_rounded),
        const SizedBox(height: 14),
        _ScoreRow(
            label: 'Оригинальность',
            score: originality,
            icon: Icons.auto_awesome_rounded),
      ]),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double score;
  final IconData icon;
  const _ScoreRow(
      {required this.label, required this.score, required this.icon});

  Color get _color {
    if (score >= 7) return AurixTokens.positive;
    if (score >= 4) return AurixTokens.warning;
    return AurixTokens.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: _color.withValues(alpha: 0.7)),
      const SizedBox(width: 10),
      SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(
                  color: AurixTokens.text.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 10),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              backgroundColor: AurixTokens.glass(0.08),
              color: _color,
              minHeight: 6,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 36,
        child: Text(
          score.toStringAsFixed(1),
          textAlign: TextAlign.right,
          style: TextStyle(
              color: _color, fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    ]);
  }
}

class _VerdictCard extends StatelessWidget {
  final String verdict;
  const _VerdictCard({required this.verdict});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AurixTokens.aiAccent.withValues(alpha: 0.06),
          Colors.transparent
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AurixTokens.aiAccent.withValues(alpha: 0.12)),
      ),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AurixTokens.aiAccent.withValues(alpha: 0.12)),
              child: Icon(Icons.auto_awesome_rounded,
                  size: 16, color: AurixTokens.aiAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Вердикт',
                        style: TextStyle(
                            color: AurixTokens.aiAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(verdict,
                        style: TextStyle(
                            color:
                                AurixTokens.text.withValues(alpha: 0.9),
                            fontSize: 15,
                            height: 1.5)),
                  ]),
            ),
          ]),
    );
  }
}

class _ListCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final Color accent;
  const _ListCard(
      {required this.title,
      required this.items,
      required this.icon,
      required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.5)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(item,
                                style: TextStyle(
                                    color: AurixTokens.text
                                        .withValues(alpha: 0.85),
                                    fontSize: 14,
                                    height: 1.4))),
                      ]),
                )),
          ]),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onImprove;
  final VoidCallback onCover;
  final VoidCallback onVideo;
  final VoidCallback onRetry;
  const _ActionButtons(
      {required this.onImprove,
      required this.onCover,
      required this.onVideo,
      required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Section header
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          'ЧТО ДАЛЬШЕ?',
          style: TextStyle(
            color: AurixTokens.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      Text(
        'Передай результат анализа своей AI-команде',
        style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13, height: 1.3),
      ),
      const SizedBox(height: 16),

      // Next step cards
      _NextStepCard(
        icon: Icons.edit_note_rounded,
        accent: AurixTokens.aiAccent,
        title: 'Улучшить текст',
        subtitle: 'Автор усилит рифмы и подачу',
        onTap: onImprove,
      ),
      const SizedBox(height: 10),
      _NextStepCard(
        icon: Icons.headphones_rounded,
        accent: AurixTokens.accent,
        title: 'Исправить трек',
        subtitle: 'Продюсер поправит структуру и хук',
        onTap: onImprove,
      ),
      const SizedBox(height: 10),
      _NextStepCard(
        icon: Icons.palette_rounded,
        accent: const Color(0xFFE05AA0),
        title: 'Сделать обложку',
        subtitle: 'Визуал создаст арт под настроение трека',
        onTap: onCover,
      ),
      const SizedBox(height: 10),
      _NextStepCard(
        icon: Icons.phone_android_rounded,
        accent: AurixTokens.positive,
        title: 'Сделать контент',
        subtitle: 'SMM придумает Reels и план продвижения',
        onTap: onVideo,
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Анализировать другой трек'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AurixTokens.text,
            side: BorderSide(color: AurixTokens.stroke(0.15)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ]);
  }
}

class _NextStepCard extends StatefulWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NextStepCard({required this.icon, required this.accent, required this.title, required this.subtitle, required this.onTap});

  @override
  State<_NextStepCard> createState() => _NextStepCardState();
}

class _NextStepCardState extends State<_NextStepCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? widget.accent.withValues(alpha: 0.08) : AurixTokens.glass(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hovered ? widget.accent.withValues(alpha: 0.25) : AurixTokens.stroke(0.08)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: widget.accent.withValues(alpha: 0.1),
                border: Border.all(color: widget.accent.withValues(alpha: 0.12)),
              ),
              child: Icon(widget.icon, size: 20, color: widget.accent),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(widget.subtitle, style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 12)),
            ])),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _hovered ? widget.accent : AurixTokens.muted.withValues(alpha: 0.3)),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// HIT PREDICTOR CARD
// ══════════════════════════════════════════════════════════════

class _HitPredictorCard extends StatefulWidget {
  final AudioAnalysisResult result;
  const _HitPredictorCard({required this.result});

  @override
  State<_HitPredictorCard> createState() => _HitPredictorCardState();
}

class _HitPredictorCardState extends State<_HitPredictorCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final color = r.hitColor;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final progress = Curves.easeOutCubic.transform(_anim.value);
        final displayScore = (r.hitScore * progress).round();
        final displayViral = (r.viralProbability * progress).round();

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.15),
                AurixTokens.bg2.withValues(alpha: 0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 40,
                  spreadRadius: -12)
            ],
          ),
          child: Column(children: [
            Row(children: [
              Icon(Icons.local_fire_department_rounded,
                  size: 20, color: color),
              const SizedBox(width: 8),
              Text('HIT PREDICTION',
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2)),
            ]),
            const SizedBox(height: 20),

            // Hit Score
            Text('$displayScore',
                style: TextStyle(
                    color: color,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -3)),
            Text('/ 100',
                style: TextStyle(
                    color: color.withValues(alpha: 0.5),
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: displayScore / 100,
                backgroundColor: AurixTokens.glass(0.08),
                color: color,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),

            // Verdict label
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(r.hitVerdict,
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),

            // Viral probability
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.whatshot_rounded,
                  size: 16,
                  color: AurixTokens.text.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text('Вирусность: ',
                  style: TextStyle(
                      color: AurixTokens.text.withValues(alpha: 0.6),
                      fontSize: 13)),
              Text('$displayViral%',
                  style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ]),

            // Verdict text
            if (r.verdict.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(r.verdict,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AurixTokens.text.withValues(alpha: 0.8),
                      fontSize: 14,
                      height: 1.4)),
            ],
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Retention Killer Card — "Ты теряешь 68% слушателей"
// ══════════════════════════════════════════════════════════════

class _RetentionKillerCard extends StatelessWidget {
  final double earlyEnergy;
  final String text;
  const _RetentionKillerCard(
      {required this.earlyEnergy, required this.text});

  @override
  Widget build(BuildContext context) {
    final lossPercent = earlyEnergy < 0.5
        ? 68
        : earlyEnergy < 0.6
            ? 52
            : 35;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AurixTokens.danger.withValues(alpha: 0.12),
          AurixTokens.danger.withValues(alpha: 0.03),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: AurixTokens.danger.withValues(alpha: 0.08),
              blurRadius: 24,
              spreadRadius: -8)
        ],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.person_off_rounded,
              size: 24, color: AurixTokens.danger),
          const SizedBox(width: 10),
          Text('$lossPercent%',
              style: TextStyle(
                  color: AurixTokens.danger,
                  fontSize: 28,
                  fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        Text('слушателей уходят до 10 секунды',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AurixTokens.danger,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AurixTokens.text.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.4)),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Improvements Card (with timestamps)
// ══════════════════════════════════════════════════════════════

class _ImprovementsCard extends StatelessWidget {
  final List<Improvement> improvements;
  const _ImprovementsCard({required this.improvements});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AurixTokens.aiAccent.withValues(alpha: 0.06),
          Colors.transparent,
        ]),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.rocket_launch_rounded,
              size: 18, color: AurixTokens.aiAccent),
          const SizedBox(width: 8),
          Text('Как усилить',
              style: TextStyle(
                  color: AurixTokens.aiAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        ...improvements.map((imp) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imp.time > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AurixTokens.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${imp.time.toStringAsFixed(0)}s',
                            style: TextStyle(
                                color: AurixTokens.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    if (imp.time > 0) const SizedBox(width: 10),
                    Expanded(
                      child: Text(imp.action,
                          style: TextStyle(
                              color:
                                  AurixTokens.text.withValues(alpha: 0.85),
                              fontSize: 13,
                              height: 1.4)),
                    ),
                  ]),
            )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Hit Recipe Card
// ══════════════════════════════════════════════════════════════

class _HitRecipeCard extends StatelessWidget {
  final String recipe;
  const _HitRecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF22C55E).withValues(alpha: 0.08),
          Colors.transparent,
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E).withValues(alpha: 0.12)),
          child: const Icon(Icons.auto_awesome_rounded,
              size: 18, color: Color(0xFF22C55E)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Как сделать хит',
                    style: TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(recipe,
                    style: TextStyle(
                        color: AurixTokens.text.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.5)),
              ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Final Opinion Card
// ══════════════════════════════════════════════════════════════

class _FinalOpinionCard extends StatelessWidget {
  final String opinion;
  const _FinalOpinionCard({required this.opinion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AurixTokens.accent.withValues(alpha: 0.06),
          AurixTokens.aiAccent.withValues(alpha: 0.03),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.record_voice_over_rounded,
                  size: 18, color: AurixTokens.accent),
              const SizedBox(width: 8),
              Text('Мнение продюсера',
                  style: TextStyle(
                      color: AurixTokens.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            Text(opinion,
                style: TextStyle(
                    color: AurixTokens.text.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.5)),
          ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// "Сделать хит" CTA Button
// ══════════════════════════════════════════════════════════════

class _MakeHitButton extends StatefulWidget {
  final VoidCallback onTap;
  const _MakeHitButton({required this.onTap});

  @override
  State<_MakeHitButton> createState() => _MakeHitButtonState();
}

class _MakeHitButtonState extends State<_MakeHitButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) {
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AurixTokens.accent,
                AurixTokens.aiAccent,
              ]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AurixTokens.accent
                        .withValues(alpha: 0.2 + _glow.value * 0.15),
                    blurRadius: 20 + _glow.value * 10,
                    spreadRadius: -4)
              ],
            ),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_fix_high_rounded,
                      size: 22, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Сделать хит из этого трека',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ]),
          ),
        );
      },
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.accent,
      required this.onTap});

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.accent.withValues(alpha: 0.1)
                : AurixTokens.glass(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _hovered
                    ? widget.accent.withValues(alpha: 0.3)
                    : AurixTokens.stroke(0.1)),
          ),
          child: Column(children: [
            Icon(widget.icon, size: 22, color: widget.accent),
            const SizedBox(height: 6),
            Text(widget.label,
                style: const TextStyle(
                    color: AurixTokens.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
