import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/ai/ai_message.dart';
import 'package:aurix_flutter/ai/ai_service.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

/// Checks viewport width WITHOUT BuildContext — safe from initState.
bool _isDesktopView() {
  try {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return (view.physicalSize.width / view.devicePixelRatio) >= 700;
  } catch (_) {
    return true;
  }
}


// ── Analysis Result Model ────────────────────────────────────

class TrackAnalysis {
  final String verdict;
  final List<String> audience;
  final List<String> content;
  final List<String> strategy;
  final List<String> problems;
  final List<String> nextSteps;

  const TrackAnalysis({
    required this.verdict,
    required this.audience,
    required this.content,
    required this.strategy,
    required this.problems,
    required this.nextSteps,
  });

  factory TrackAnalysis.fromJson(Map<String, dynamic> json) {
    return TrackAnalysis(
      verdict: json['verdict']?.toString() ?? '',
      audience: _toList(json['audience']),
      content: _toList(json['content']),
      strategy: _toList(json['strategy']),
      problems: _toList(json['problems']),
      nextSteps: _toList(json['next_steps']),
    );
  }

  static List<String> _toList(dynamic v) {
    if (v is List) return v.map((e) => '$e').where((s) => s.isNotEmpty).toList();
    return [];
  }
}

// ── Screen ───────────────────────────────────────────────────

class TrackAnalysisScreen extends ConsumerStatefulWidget {
  /// Optional: pre-select a release to discuss.
  final String? releaseId;

  const TrackAnalysisScreen({super.key, this.releaseId});

  @override
  ConsumerState<TrackAnalysisScreen> createState() =>
      _TrackAnalysisScreenState();
}

class _TrackAnalysisScreenState extends ConsumerState<TrackAnalysisScreen>
    with TickerProviderStateMixin {
  final TextEditingController _input = TextEditingController();
  final TextEditingController _followUpInput = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _loading = false;
  String? _error;

  // History of analyses + follow-up text responses
  final List<_HistoryEntry> _history = [];

  String _lastQuery = '';

  // Context settings
  bool _dnkEnabled = true;
  String? _selectedReleaseId;
  bool _autoAnalyzed = false;

  late AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _selectedReleaseId = widget.releaseId;
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-analyze when navigated from release screen with a releaseId
    if (!_autoAnalyzed && widget.releaseId != null && _history.isEmpty && !_loading) {
      _autoAnalyzed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _input.text.isEmpty) {
          _input.text = 'Разбери этот трек: сильные стороны, аудитория, стратегия продвижения';
          _analyze();
        }
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _followUpInput.dispose();
    _scroll.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  AiContextMode get _contextMode {
    if (!_dnkEnabled) return AiContextMode.noDnk;
    return AiContextMode.full;
  }

  Future<void> _analyze() async {
    final query = _input.text.trim();
    if (query.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    _staggerCtrl.reset();

    try {
      final locale =
          ref.read(appStateProvider).locale == AppLocale.ru ? 'ru' : 'en';

      final reply = await AiService.send(
        message: query,
        history: const [],
        mode: 'analyze',
        page: 'studio',
        locale: locale,
        contextMode: _contextMode,
        trackId: _selectedReleaseId,
      );

      if (!mounted) return;

      final parsed = _parseAnalysis(reply);
      if (parsed != null) {
        setState(() {
          _history.add(_HistoryEntry.analysis(query, parsed));
          _lastQuery = query;
          _loading = false;
        });
        _staggerCtrl.forward();
        _scrollToResults();
      } else {
        setState(() {
          _error = 'AI вернул некорректный формат. Попробуйте ещё раз.';
          _loading = false;
        });
      }
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Ошибка соединения. Попробуйте позже.'; _loading = false; });
    }
  }

  Future<void> _sendFollowUp(String message, {String mode = 'chat'}) async {
    if (message.trim().isEmpty || _loading) return;

    setState(() { _loading = true; _error = null; });

    try {
      final locale =
          ref.read(appStateProvider).locale == AppLocale.ru ? 'ru' : 'en';

      // Build history from previous interactions
      final history = <AiMessage>[];
      for (final entry in _history) {
        if (entry.query != null) {
          history.add(AiMessage(role: 'user', content: entry.query!));
        }
        if (entry.textReply != null) {
          history.add(AiMessage(role: 'assistant', content: entry.textReply!));
        }
      }

      final reply = await AiService.send(
        message: message,
        history: history,
        mode: mode,
        page: 'studio',
        locale: locale,
        contextMode: _contextMode,
        trackId: _selectedReleaseId,
      );

      if (!mounted) return;
      setState(() {
        _history.add(_HistoryEntry.text(message, reply));
        _loading = false;
      });
      _followUpInput.clear();
      _scrollToBottom();
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Ошибка соединения. Попробуйте позже.'; _loading = false; });
    }
  }

  TrackAnalysis? _parseAnalysis(String raw) {
    try {
      final data = jsonDecode(raw.trim());
      if (data is Map<String, dynamic>) return TrackAnalysis.fromJson(data);
    } catch (_) {}
    return null;
  }

  void _scrollToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(200,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _followUp(String action, {String mode = 'chat'}) {
    final message = '$action. Контекст: $_lastQuery';
    _sendFollowUp(message, mode: mode);
  }

  void _reset() {
    setState(() {
      _history.clear();
      _error = null;
      _input.clear();
      _followUpInput.clear();
      _lastQuery = '';
    });
    _staggerCtrl.reset();
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
    }
  }

  void _copyBlock(String title, List<String> items) {
    final text = '$title:\n${items.map((e) => '• $e').join('\n')}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L10n.t(context, 'copied')),
        backgroundColor: AurixTokens.bg2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasResults = _history.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AurixTokens.bg0, Color(0xFF0A0A12)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildContextBar()),
              SliverToBoxAdapter(child: _buildInputSection()),
              if (!hasResults && !_loading && _error == null)
                SliverToBoxAdapter(child: _buildEmptyState()),
              if (_loading && _history.isEmpty)
                SliverToBoxAdapter(child: _buildLoading()),
              if (_error != null) SliverToBoxAdapter(child: _buildError()),
              ..._buildAllResults(),
              if (_loading && _history.isNotEmpty)
                SliverToBoxAdapter(child: _buildLoading()),
              if (hasResults && !_loading)
                SliverToBoxAdapter(child: _buildFollowUpInput()),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          // DNK banner
          _DnkBanner(),

          const SizedBox(height: 16),

          // Example prompt cards
          Text('Попробуй спросить:', style: TextStyle(
            color: AurixTokens.muted, fontSize: 13, fontWeight: FontWeight.w500,
          )),
          const SizedBox(height: 12),
          _ExampleCard(
            icon: Icons.music_note_rounded,
            text: 'Разбери мой последний трек — что сильно, а что слабо?',
            onTap: () {
              _input.text = 'Разбери мой последний трек — что сильно, а что слабо?';
              _analyze();
            },
          ),
          const SizedBox(height: 8),
          _ExampleCard(
            icon: Icons.people_rounded,
            text: 'Какая аудитория подходит для моей музыки?',
            onTap: () {
              _input.text = 'Какая аудитория подходит для моей музыки?';
              _analyze();
            },
          ),
          const SizedBox(height: 8),
          _ExampleCard(
            icon: Icons.trending_up_rounded,
            text: 'Дай стратегию продвижения для нового релиза',
            onTap: () {
              _input.text = 'Дай стратегию продвижения для нового релиза';
              _analyze();
            },
          ),
        ],
      ),
    );
  }

  // ── Follow-Up Input ────────────────────────────────────────

  Widget _buildFollowUpInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AurixTokens.bg2.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AurixTokens.stroke(0.1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _followUpInput,
                style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Задай уточняющий вопрос...',
                  hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.4)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onSubmitted: (v) => _sendFollowUp(v),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _sendFollowUp(_followUpInput.text),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AurixTokens.accent, AurixTokens.accentWarm]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── All Results (history) ──────────────────────────────────

  List<Widget> _buildAllResults() {
    final widgets = <Widget>[];
    for (int h = 0; h < _history.length; h++) {
      final entry = _history[h];
      if (entry.analysis != null) {
        // Structured analysis result
        if (h > 0) {
          // Add separator label for subsequent analyses
          widgets.add(SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                entry.query ?? 'Анализ',
                style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
          ));
        }
        widgets.addAll(_buildAnalysisBlocks(entry.analysis!, isLatest: h == _history.length - 1));
      } else if (entry.textReply != null) {
        // Free-text follow-up response
        widgets.add(SliverToBoxAdapter(
          child: _FollowUpReplyBlock(query: entry.query ?? '', reply: entry.textReply!),
        ));
      }
    }
    return widgets;
  }

  List<Widget> _buildAnalysisBlocks(TrackAnalysis r, {bool isLatest = false}) {
    final blocks = <_BlockDef>[
      if (r.verdict.isNotEmpty)
        _BlockDef(null, null, null, isVerdict: true, verdict: r.verdict),
      _BlockDef('Кому это зайдёт', Icons.people_rounded, AurixTokens.accent, items: r.audience),
      _BlockDef('Что снимать', Icons.videocam_rounded, AurixTokens.positive, items: r.content),
      _BlockDef('Что делать', Icons.rocket_launch_rounded, AurixTokens.aiAccent, items: r.strategy),
      _BlockDef('Что слабо', Icons.warning_amber_rounded, AurixTokens.warning, items: r.problems),
    ];

    final widgets = <Widget>[];
    for (int i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final child = b.isVerdict
          ? _VerdictBlock(text: b.verdict!)
          : _SectionBlock(
              title: b.title!, icon: b.icon!, color: b.color!,
              items: b.items!, onCopy: () => _copyBlock(b.title!, b.items!),
            );

      widgets.add(SliverToBoxAdapter(
        child: isLatest
            ? _StaggeredBlock(
                animation: _staggerCtrl, index: i, total: blocks.length,
                child: child,
              )
            : child,
      ));
    }

    // Next steps + actions
    widgets.add(SliverToBoxAdapter(
      child: isLatest
          ? _StaggeredBlock(
              animation: _staggerCtrl, index: blocks.length, total: blocks.length + 1,
              child: _NextStepsBlock(steps: r.nextSteps, onAction: _followUp),
            )
          : _NextStepsBlock(steps: r.nextSteps, onAction: _followUp),
    ));

    return widgets;
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                AurixTokens.accent.withValues(alpha: 0.2),
                AurixTokens.accent.withValues(alpha: 0.06),
              ]),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                size: 18, color: AurixTokens.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Разбор трека',
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'AI знает твой профиль, треки и DNK',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_history.isNotEmpty)
            GestureDetector(
              onTap: _reset,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AurixTokens.glass(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AurixTokens.stroke(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, size: 14, color: AurixTokens.muted),
                    const SizedBox(width: 4),
                    Text('Заново', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Context Bar (DNK toggle + Release selector) ────────────

  Widget _buildContextBar() {
    final releasesAsync = ref.watch(releasesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AurixTokens.bg2.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AurixTokens.stroke(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DNK Toggle
            Row(
              children: [
                Icon(Icons.fingerprint_rounded, size: 16,
                    color: _dnkEnabled ? AurixTokens.accent : AurixTokens.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Учитывать DNK профиль',
                    style: TextStyle(
                      color: AurixTokens.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Switch.adaptive(
                    value: _dnkEnabled,
                    activeColor: AurixTokens.accent,
                    onChanged: _loading ? null : (v) => setState(() => _dnkEnabled = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Release selector
            Row(
              children: [
                Icon(Icons.album_rounded, size: 16, color: AurixTokens.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: releasesAsync.when(
                    data: (releases) {
                      if (releases.isEmpty) {
                        return Text(
                          'Нет загруженных треков',
                          style: TextStyle(color: AurixTokens.muted, fontSize: 13),
                        );
                      }
                      return _ReleaseDropdown(
                        releases: releases,
                        selectedId: _selectedReleaseId,
                        enabled: !_loading,
                        onChanged: (id) => setState(() => _selectedReleaseId = id),
                      );
                    },
                    loading: () => Text('Загрузка...', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                    error: (_, __) => Text('—', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Input Section ──────────────────────────────────────────

  Widget _buildInputSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        children: [
          TextField(
            controller: _input,
            enabled: !_loading,
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(color: AurixTokens.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: _selectedReleaseId != null
                  ? 'Что хочешь узнать про этот трек?'
                  : 'Опиши трек или идею...',
              hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.4)),
              hintMaxLines: 2,
              filled: true,
              fillColor: AurixTokens.glass(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AurixTokens.stroke(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AurixTokens.accent.withValues(alpha: 0.3)),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            onSubmitted: (_) => _analyze(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: _AnalyzeButton(loading: _loading, onTap: _analyze),
          ),
        ],
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: _LoadingSkeleton(),
    );
  }

  // ── Error ──────────────────────────────────────────────────

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AurixTokens.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 18, color: AurixTokens.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_error!, style: TextStyle(color: AurixTokens.danger, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

}

// ══════════════════════════════════════════════════════════════
// History Entry
// ══════════════════════════════════════════════════════════════

class _HistoryEntry {
  final String? query;
  final TrackAnalysis? analysis;
  final String? textReply;

  _HistoryEntry._({this.query, this.analysis, this.textReply});

  factory _HistoryEntry.analysis(String query, TrackAnalysis analysis) =>
      _HistoryEntry._(query: query, analysis: analysis);

  factory _HistoryEntry.text(String query, String reply) =>
      _HistoryEntry._(query: query, textReply: reply);
}

// ══════════════════════════════════════════════════════════════
// DNK Banner
// ══════════════════════════════════════════════════════════════

final _hasDnkResultProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  try {
    final res = await ApiClient.get('/dnk-results/latest', query: {
      'user_id': user.id,
      'status': 'finished',
    });
    final data = res.data;
    if (data is List) return data.isNotEmpty;
    if (data is Map) return data['id'] != null;
    return false;
  } catch (_) {
    return false;
  }
});

class _DnkBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDnk = ref.watch(_hasDnkResultProvider).valueOrNull ?? false;
    if (hasDnk) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => context.push('/dnk'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AurixTokens.accent.withValues(alpha: 0.08),
              AurixTokens.aiAccent.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AurixTokens.accent.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.fingerprint_rounded, size: 18, color: AurixTokens.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Пройди DNK тест', style: TextStyle(
                    color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600,
                  )),
                  Text('AI даст более точные рекомендации с DNK профилем', style: TextStyle(
                    color: AurixTokens.muted, fontSize: 12,
                  )),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AurixTokens.muted),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Example Prompt Card
// ══════════════════════════════════════════════════════════════

class _ExampleCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _ExampleCard({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AurixTokens.glass(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AurixTokens.stroke(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AurixTokens.accent.withValues(alpha: 0.7)),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(
              color: AurixTokens.textSecondary, fontSize: 13, height: 1.4,
            ))),
            Icon(Icons.arrow_forward_rounded, size: 16, color: AurixTokens.muted.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Follow-Up Reply Block
// ══════════════════════════════════════════════════════════════

class _FollowUpReplyBlock extends StatelessWidget {
  final String query;
  final String reply;
  const _FollowUpReplyBlock({required this.query, required this.reply});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User's question
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AurixTokens.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(query, style: TextStyle(
                color: AurixTokens.text, fontSize: 13, height: 1.4,
              )),
            ),
          ),
          const SizedBox(height: 10),
          // AI reply
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AurixTokens.bg2.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AurixTokens.stroke(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 14, color: AurixTokens.accent),
                    const SizedBox(width: 8),
                    Text('AI', style: TextStyle(
                      color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w600,
                    )),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(reply, style: TextStyle(
                  color: AurixTokens.textSecondary, fontSize: 14, height: 1.55,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Release Dropdown
// ══════════════════════════════════════════════════════════════

class _ReleaseDropdown extends StatelessWidget {
  final List<ReleaseModel> releases;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _ReleaseDropdown({
    required this.releases,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: selectedId,
        isExpanded: true,
        isDense: true,
        dropdownColor: AurixTokens.bg2,
        style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13),
        icon: Icon(Icons.expand_more_rounded, size: 18, color: AurixTokens.muted),
        hint: Text('Выбери трек (необязательно)',
            style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text('Без привязки к треку',
                style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
          ),
          ...releases.map((r) => DropdownMenuItem<String?>(
                value: r.id,
                child: Text(
                  '${r.title}${r.genre != null ? ' (${r.genre})' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13),
                ),
              )),
        ],
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Block helpers
// ══════════════════════════════════════════════════════════════

class _BlockDef {
  final String? title;
  final IconData? icon;
  final Color? color;
  final List<String>? items;
  final bool isVerdict;
  final String? verdict;
  _BlockDef(this.title, this.icon, this.color,
      {this.items, this.isVerdict = false, this.verdict});
}

// ══════════════════════════════════════════════════════════════
// Verdict Block
// ══════════════════════════════════════════════════════════════

class _VerdictBlock extends StatelessWidget {
  final String text;
  const _VerdictBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [
              AurixTokens.accent.withValues(alpha: 0.1),
              AurixTokens.bg2.withValues(alpha: 0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AurixTokens.accent.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 16, color: AurixTokens.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(
                color: AurixTokens.text, fontSize: 16,
                fontWeight: FontWeight.w600, height: 1.45,
              )),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Section Block
// ══════════════════════════════════════════════════════════════

class _SectionBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final VoidCallback onCopy;

  const _SectionBlock({
    required this.title, required this.icon, required this.color,
    required this.items, required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AurixTokens.bg2.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AurixTokens.stroke(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: TextStyle(
                  color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700,
                ))),
                GestureDetector(
                  onTap: onCopy,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AurixTokens.glass(0.06),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AurixTokens.stroke(0.08)),
                    ),
                    child: Icon(Icons.copy_rounded, size: 13, color: AurixTokens.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...items.asMap().entries.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: e.key < items.length - 1 ? 10 : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(top: 7, right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.5),
                        ),
                      ),
                      Expanded(child: Text(e.value, style: TextStyle(
                        color: AurixTokens.textSecondary, fontSize: 14, height: 1.5,
                      ))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Next Steps Block
// ══════════════════════════════════════════════════════════════

class _NextStepsBlock extends StatelessWidget {
  final List<String> steps;
  final void Function(String, {String mode}) onAction;
  const _NextStepsBlock({required this.steps, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (steps.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AurixTokens.bg2.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AurixTokens.stroke(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AurixTokens.accent.withValues(alpha: 0.12),
                      ),
                      child: Icon(Icons.flag_rounded, size: 15, color: AurixTokens.accent),
                    ),
                    const SizedBox(width: 10),
                    Text('Следующие шаги', style: TextStyle(
                      color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700,
                    )),
                  ]),
                  const SizedBox(height: 14),
                  ...steps.asMap().entries.map((e) => Padding(
                        padding: EdgeInsets.only(bottom: e.key < steps.length - 1 ? 10 : 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22, height: 22,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AurixTokens.accent.withValues(alpha: 0.1),
                              ),
                              child: Center(child: Text('${e.key + 1}', style: TextStyle(
                                color: AurixTokens.accent, fontSize: 11, fontWeight: FontWeight.w700,
                              ))),
                            ),
                            Expanded(child: Text(e.value, style: TextStyle(
                              color: AurixTokens.textSecondary, fontSize: 14, height: 1.5,
                            ))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _ActionButton(
              label: 'Усилить', icon: Icons.bolt_rounded, color: AurixTokens.accent,
              onTap: () => onAction('Усиль разбор — дай более агрессивные и нестандартные решения', mode: 'chat'),
            )),
            const SizedBox(width: 10),
            Expanded(child: _ActionButton(
              label: 'Контент-план', icon: Icons.videocam_rounded, color: AurixTokens.positive,
              onTap: () => onAction('Составь детальный контент-план на 2 недели для продвижения', mode: 'reels'),
            )),
            const SizedBox(width: 10),
            Expanded(child: _ActionButton(
              label: 'Стратегия', icon: Icons.trending_up_rounded, color: AurixTokens.aiAccent,
              onTap: () => onAction('Дай пошаговую стратегию запуска трека от 0 до 10к прослушиваний', mode: 'chat'),
            )),
          ]),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Staggered Animation
// ══════════════════════════════════════════════════════════════

class _StaggeredBlock extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final int total;
  final Widget child;
  const _StaggeredBlock({required this.animation, required this.index, required this.total, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = index / (total + 1);
    final end = (index + 1.5) / (total + 1);
    final interval = Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final t = interval.transform(animation.value);
        return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 20 * (1 - t)), child: child));
      },
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Buttons
// ══════════════════════════════════════════════════════════════

class _AnalyzeButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _AnalyzeButton({required this.loading, required this.onTap});
  @override
  State<_AnalyzeButton> createState() => _AnalyzeButtonState();
}

class _AnalyzeButtonState extends State<_AnalyzeButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); if (!widget.loading) widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.loading
                  ? [AurixTokens.bg2.withValues(alpha: 0.5), AurixTokens.bg2.withValues(alpha: 0.3)]
                  : [AurixTokens.accent, AurixTokens.accentWarm],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.loading ? null : [
              BoxShadow(color: AurixTokens.accentGlow.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: -8, offset: const Offset(0, 6)),
            ],
          ),
          child: Center(
            child: widget.loading
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.muted)),
                    const SizedBox(width: 10),
                    Text('Анализирую...', style: TextStyle(color: AurixTokens.muted, fontSize: 15, fontWeight: FontWeight.w600)),
                  ])
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('Разобрать', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});
  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.color.withValues(alpha: 0.2)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(widget.icon, size: 18, color: widget.color),
            const SizedBox(height: 2),
            Text(widget.label, style: TextStyle(color: widget.color, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Loading Skeleton
// ══════════════════════════════════════════════════════════════

class _LoadingSkeleton extends StatefulWidget {
  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
 if (_isDesktopView()) _ctrl.repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final alpha = 0.15 + _ctrl.value * 0.15;
        final color = AurixTokens.bg2.withValues(alpha: alpha);
        return Column(children: [
          Container(width: double.infinity, height: 60, decoration: BoxDecoration(
            color: AurixTokens.accent.withValues(alpha: alpha * 0.3), borderRadius: BorderRadius.circular(16),
          )),
          const SizedBox(height: 14),
          _blockSkel(color), const SizedBox(height: 12),
          _blockSkel(color), const SizedBox(height: 12),
          _blockSkel(color),
        ]);
      },
    );
  }

  Widget _blockSkel(Color color) => Container(
    width: double.infinity, height: 120,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: AurixTokens.stroke(0.06))),
  );
}
