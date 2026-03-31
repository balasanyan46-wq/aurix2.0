import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/ai/ai_message.dart';
import 'package:aurix_flutter/ai/ai_service.dart';
import 'package:aurix_flutter/ai/ai_persistence_guard.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_backdrop.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/design/components/liquid_glass.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/core/api/api_error.dart';
import 'package:aurix_flutter/core/services/event_tracker.dart';

import 'widgets/ai_list.dart';
import 'widgets/ai_action_chips.dart';
import 'widgets/ai_typing_indicator.dart';
import 'generate_cover_screen.dart';

// ── Mode definition ─────────────────────────────────────────────

enum AiMode {
  chat(id: 'chat', label: 'Chat', icon: Icons.chat_rounded),
  image(id: 'image', label: 'Image', icon: Icons.image_rounded),
  video(id: 'video', label: 'Video', icon: Icons.movie_rounded),
  audio(id: 'audio', label: 'Audio', icon: Icons.audiotrack_rounded),
  dnk(id: 'dnk', label: 'DNK', icon: Icons.fingerprint_rounded),
  reels(id: 'reels', label: 'Reels', icon: Icons.videocam_rounded),
  lyrics(id: 'lyrics', label: 'Lyrics', icon: Icons.edit_note_rounded),
  ideas(id: 'ideas', label: 'Ideas', icon: Icons.lightbulb_rounded);

  final String id;
  final String label;
  final IconData icon;
  const AiMode({required this.id, required this.label, required this.icon});

  bool get isGenerative => this == image || this == video || this == audio;

  String get placeholder => switch (this) {
        AiMode.chat => 'Опиши идею, трек или задачу...',
        AiMode.image => 'Опиши обложку или визуал...',
        AiMode.video => 'Опиши видео для генерации...',
        AiMode.audio => 'Опиши голос или аудио...',
        AiMode.dnk => 'Опиши себя как артиста...',
        AiMode.reels => 'Опиши тему для Reels...',
        AiMode.lyrics => 'Опиши идею для текста...',
        AiMode.ideas => 'Опиши направление для идей...',
      };
}

// ── Welcome prompts ─────────────────────────────────────────────

class _WelcomePrompt {
  final String title, subtitle, prompt;
  final IconData icon;
  final AiMode? mode;
  const _WelcomePrompt(this.title, this.subtitle, this.icon, this.prompt,
      [this.mode]);
}

const _welcomePrompts = [
  _WelcomePrompt(
    'Хук для трека',
    'Создай цепляющий хук',
    Icons.music_note_rounded,
    'Напиши хук для трека про ночной город — чтобы зацепил с первых секунд',
    AiMode.lyrics,
  ),
  _WelcomePrompt(
    'Reels стратегия',
    '10 вирусных идей',
    Icons.videocam_rounded,
    '10 идей для Reels под мой новый трек — нужен вирусный контент',
    AiMode.reels,
  ),
  _WelcomePrompt(
    'Разбор аудитории',
    'Кто будет слушать',
    Icons.fingerprint_rounded,
    'Проанализируй аудиторию для начинающего рэп-артиста из СНГ',
    AiMode.dnk,
  ),
  _WelcomePrompt(
    'Идеи для трека',
    '10 концепций',
    Icons.lightbulb_rounded,
    'Придумай 10 идей для трека в жанре поп-рэп, тема — амбиции и рост',
    AiMode.ideas,
  ),
];

// ── Chat Entry ──────────────────────────────────────────────────

class _ChatEntry {
  final String role;
  final String content;
  final AiMode mode;
  final AiFollowUp? followUp;
  final String? generativeType;
  final DateTime ts;

  _ChatEntry({
    required this.role,
    required this.content,
    required this.mode,
    this.followUp,
    this.generativeType,
  }) : ts = DateTime.now();
}

// ══════════════════════════════════════════════════════════════════
// Main Screen
// ══════════════════════════════════════════════════════════════════

class StudioAiScreen extends ConsumerStatefulWidget {
  const StudioAiScreen({super.key});

  @override
  ConsumerState<StudioAiScreen> createState() => _StudioAiScreenState();
}

class _StudioAiScreenState extends ConsumerState<StudioAiScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<_ChatEntry> _entries = [];

  AiMode _selectedMode = AiMode.chat;
  bool _loading = false;
  bool _loaded = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(_loadHistory());
  }

  // ── Data ──────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final repo = ref.read(aiStudioHistoryRepositoryProvider);
    try {
      final rows = await repo.getMessages(limit: 60);
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(rows.map((m) => _ChatEntry(
                role: m.role,
                content: m.content,
                mode: AiMode.chat,
              )));
      });
    } on AiSchemaMissingException {
      // ignore
    } catch (e) {
      debugPrint('[StudioAi] load: ${formatApiError(e)}');
    }
  }

  // ── Send / Generate ───────────────────────────────────────────

  Future<void> _send(String message, {AiMode? overrideMode}) async {
    final msg = message.trim();
    if (msg.isEmpty || _loading) return;

    _input.clear();
    final mode = overrideMode ?? _selectedMode;
    if (overrideMode != null) setState(() => _selectedMode = overrideMode);

    setState(() {
      _entries.insert(0, _ChatEntry(role: 'user', content: msg, mode: mode));
      _loading = true;
    });
    _scrollToBottom();

    try {
      try {
        await ref
            .read(aiStudioHistoryRepositoryProvider)
            .append(role: 'user', content: msg);
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 300));

      String reply;
      String? genType;

      if (mode.isGenerative) {
        final result = await AiService.generate(type: mode.id, prompt: msg);
        reply = result.content;
        genType = mode.id;
      } else {
        final historyForApi = _entries
            .skip(1)
            .where((e) => !e.mode.isGenerative)
            .take(10)
            .map((e) => AiMessage(
                  role: e.role,
                  content: AiFollowUp.stripFollowUp(e.content),
                ))
            .toList()
            .reversed
            .toList();

        final locale =
            ref.read(appStateProvider).locale == AppLocale.ru ? 'ru' : 'en';

        reply = await AiService.send(
          message: msg,
          history: historyForApi,
          mode: mode.id,
          page: 'studio',
          locale: locale,
        );
      }

      if (!mounted) return;

      EventTracker.track('ai_studio_sent', meta: {'mode': mode.id});
      final followUp = genType == null ? AiFollowUp.parse(reply) : null;

      setState(() {
        _entries.insert(
          0,
          _ChatEntry(
            role: 'assistant',
            content: reply,
            mode: mode,
            followUp: followUp,
            generativeType: genType,
          ),
        );
        while (_entries.length > 50) _entries.removeLast();
        _loading = false;
      });

      try {
        await ref
            .read(aiStudioHistoryRepositoryProvider)
            .append(role: 'assistant', content: reply);
      } catch (_) {}
    } on AiServiceException catch (e) {
      _insertError(e.message);
    } catch (_) {
      _insertError('Ошибка соединения. Попробуйте позже.');
    }
    _scrollToBottom();
  }

  void _insertError(String text) {
    if (!mounted) return;
    setState(() {
      _entries.insert(
          0, _ChatEntry(role: 'assistant', content: text, mode: AiMode.chat));
      while (_entries.length > 50) _entries.removeLast();
      _loading = false;
    });
    try {
      ref
          .read(aiStudioHistoryRepositoryProvider)
          .append(role: 'assistant', content: text);
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic);
      }
    });
  }

  void _clearChat() {
    setState(() => _entries.clear());
    unawaited(() async {
      try {
        await ref.read(aiStudioHistoryRepositoryProvider).clear();
      } catch (_) {}
    }());
  }

  void _copy(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: AiFollowUp.stripFollowUp(text)));
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

  void _onActionChip(String prompt, String? mode) {
    final aiMode = mode != null
        ? AiMode.values.where((m) => m.id == mode).firstOrNull
        : null;
    _send(prompt, overrideMode: aiMode);
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AurixBackdrop(
      child: Column(
        children: [
          Expanded(
            child: _entries.isEmpty && !_loading
                ? _buildWelcome()
                : _buildChatList(),
          ),
          _buildModeBar(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Welcome Screen ────────────────────────────────────────────

  Widget _buildWelcome() {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              FadeInSlide(
                delayMs: 0,
                child: const _AiAvatar(),
              ),
              const SizedBox(height: 20),

              // Status badge
              FadeInSlide(
                delayMs: 80,
                child: LiquidGlass(
                  level: GlassLevel.light,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  radius: 8,
                  hoverScale: false,
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
                              color:
                                  AurixTokens.positive.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'AI STUDIO ONLINE',
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
              const SizedBox(height: 16),

              // Title
              FadeInSlide(
                delayMs: 160,
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [AurixTokens.text, AurixTokens.accent],
                  ).createShader(bounds),
                  child: Text(
                    'Aurix Studio',
                    style: TextStyle(
                      fontFamily: AurixTokens.fontHeading,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeInSlide(
                delayMs: 200,
                child: Text(
                  'Твой продюсер. Опиши идею — я сделаю остальное.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AurixTokens.fontBody,
                    color: AurixTokens.muted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Tool cards
              if (isDesktop) ...[
                FadeInSlide(
                  delayMs: 280,
                  child: Row(children: [
                    Expanded(
                      child: _WelcomeCard(
                        prompt: const _WelcomePrompt('Обложка',
                            'Сгенерировать обложку', Icons.palette_rounded, ''),
                        accentColor: AurixTokens.aiAccent,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const GenerateCoverScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _WelcomeCard(
                        prompt: _welcomePrompts[0],
                        accentColor: AurixTokens.accent,
                        onTap: () => _send(_welcomePrompts[0].prompt,
                            overrideMode: _welcomePrompts[0].mode),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                FadeInSlide(
                  delayMs: 360,
                  child: Row(children: [
                    Expanded(
                      child: _WelcomeCard(
                        prompt: _welcomePrompts[1],
                        accentColor: AurixTokens.warning,
                        onTap: () => _send(_welcomePrompts[1].prompt,
                            overrideMode: _welcomePrompts[1].mode),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _WelcomeCard(
                        prompt: _welcomePrompts[2],
                        accentColor: AurixTokens.positive,
                        onTap: () => _send(_welcomePrompts[2].prompt,
                            overrideMode: _welcomePrompts[2].mode),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                FadeInSlide(
                  delayMs: 440,
                  child: _WelcomeCard(
                    prompt: _welcomePrompts[3],
                    accentColor: AurixTokens.accent,
                    onTap: () => _send(_welcomePrompts[3].prompt,
                        overrideMode: _welcomePrompts[3].mode),
                  ),
                ),
              ] else ...[
                FadeInSlide(
                  delayMs: 280,
                  child: _WelcomeCard(
                    prompt: const _WelcomePrompt('Обложка',
                        'Сгенерировать обложку', Icons.palette_rounded, ''),
                    accentColor: AurixTokens.aiAccent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const GenerateCoverScreen()),
                    ),
                  ),
                ),
                ...List.generate(_welcomePrompts.length, (i) {
                  final p = _welcomePrompts[i];
                  final colors = [
                    AurixTokens.accent,
                    AurixTokens.warning,
                    AurixTokens.positive,
                    AurixTokens.accent,
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FadeInSlide(
                      delayMs: 360 + i * 80,
                      child: _WelcomeCard(
                        prompt: p,
                        accentColor: colors[i],
                        onTap: () => _send(p.prompt, overrideMode: p.mode),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Chat List ─────────────────────────────────────────────────

  Widget _buildChatList() {
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          itemCount: _entries.length + (_loading ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (_loading && i == 0) return _buildLoadingBubble();
            final entry = _entries[_loading ? i - 1 : i];
            return FadeInSlide(
              key: ValueKey('${entry.hashCode}_$i'),
              startDy: 8,
              child: _ChatBubble(
                entry: entry,
                onCopy: _copy,
                onAction: _loading ? null : _onActionChip,
                onRegenerate: entry.role == 'assistant' && !_loading
                    ? () => _send('Переделай — сделай мощнее и конкретнее')
                    : null,
              ),
            );
          },
        ),
        if (_entries.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: _GlassIconBtn(
              icon: Icons.delete_outline_rounded,
              onTap: _loading ? null : _clearChat,
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: AurixGlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                AiTypingIndicator(),
                SizedBox(height: 16),
                AiResponseSkeleton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mode Bar ──────────────────────────────────────────────────

  Widget _buildModeBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AurixTokens.bg0.withValues(alpha: 0.7),
        border: Border(top: BorderSide(color: AurixTokens.stroke(0.08))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: AiMode.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final m = AiMode.values[i];
          final sel = m == _selectedMode;
          return GestureDetector(
            onTap:
                _loading ? null : () => setState(() => _selectedMode = m),
            child: AnimatedContainer(
              duration: AurixTokens.dMedium,
              curve: AurixTokens.cEase,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: sel
                    ? AurixTokens.accent.withValues(alpha: 0.14)
                    : AurixTokens.glass(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel
                      ? AurixTokens.accent.withValues(alpha: 0.35)
                      : AurixTokens.stroke(0.08),
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color:
                              AurixTokens.accentGlow.withValues(alpha: 0.1),
                          blurRadius: 14,
                          spreadRadius: -6,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(m.icon,
                      size: 15,
                      color: sel ? AurixTokens.accent : AurixTokens.muted),
                  const SizedBox(width: 6),
                  Text(
                    m.label,
                    style: TextStyle(
                      fontFamily: AurixTokens.fontBody,
                      color:
                          sel ? AurixTokens.text : AurixTokens.textSecondary,
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Input Bar ─────────────────────────────────────────────────

  Widget _buildInputBar() {
    return LiquidGlass(
      level: GlassLevel.light,
      radius: 0,
      hoverScale: false,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _focusNode,
                enabled: !_loading,
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _selectedMode.placeholder,
                  hintStyle: TextStyle(
                      color: AurixTokens.muted.withValues(alpha: 0.45)),
                  filled: true,
                  fillColor: AurixTokens.glass(0.05),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AurixTokens.radiusField),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AurixTokens.radiusField),
                    borderSide: BorderSide(color: AurixTokens.stroke(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AurixTokens.radiusField),
                    borderSide: BorderSide(
                        color: AurixTokens.accent.withValues(alpha: 0.35)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (v) => _send(v),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              height: 48,
              child: AurixButton(
                text: '',
                icon: Icons.send_rounded,
                onPressed: _loading ? null : () => _send(_input.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Chat Bubble
// ══════════════════════════════════════════════════════════════════

class _ChatBubble extends StatelessWidget {
  final _ChatEntry entry;
  final void Function(String) onCopy;
  final void Function(String prompt, String? mode)? onAction;
  final VoidCallback? onRegenerate;

  const _ChatBubble({
    required this.entry,
    required this.onCopy,
    this.onAction,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == 'user';
    final w = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isUser ? 320 : w * 0.92),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              isUser ? _buildUserBubble() : _buildAiBubble(),

              if (!isUser) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SmallAction(
                      icon: Icons.copy_rounded,
                      label: 'Скопировать',
                      onTap: () => onCopy(entry.content),
                    ),
                    if (onRegenerate != null) ...[
                      const SizedBox(width: 6),
                      _SmallAction(
                        icon: Icons.refresh_rounded,
                        label: 'Ещё раз',
                        onTap: onRegenerate!,
                      ),
                    ],
                  ],
                ),
                if (onAction != null && entry.generativeType == null) ...[
                  const SizedBox(height: 8),
                  AiActionChips(
                    followUp: entry.followUp,
                    onAction: onAction!,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserBubble() {
    return LiquidGlass(
      level: GlassLevel.medium,
      hoverScale: false,
      showOrangeBorderOnHover: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 18,
      child: Text(
        entry.content,
        style: const TextStyle(
          color: AurixTokens.text,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildAiBubble() {
    return AurixGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI badge + type label
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AurixTokens.accent.withValues(alpha: 0.2),
                      AurixTokens.aiAccent.withValues(alpha: 0.15),
                    ],
                  ),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    size: 12, color: AurixTokens.accent),
              ),
              const SizedBox(width: 8),
              Text(
                'Aurix AI',
                style: TextStyle(
                  color: AurixTokens.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              if (entry.generativeType != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AurixTokens.aiAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.generativeType!.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AurixTokens.fontMono,
                      color: AurixTokens.aiAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _buildAiContent(),
        ],
      ),
    );
  }

  Widget _buildAiContent() {
    final parsed = parseAiResponse(
      entry.content,
      entry.mode.id,
      generativeType: entry.generativeType,
    );
    return AiResultRenderer(result: parsed, onCopy: onCopy);
  }
}

// ══════════════════════════════════════════════════════════════════
// Welcome Card — uses LiquidGlass
// ══════════════════════════════════════════════════════════════════

class _WelcomeCard extends StatelessWidget {
  final _WelcomePrompt prompt;
  final VoidCallback onTap;
  final Color? accentColor;

  const _WelcomeCard(
      {required this.prompt, required this.onTap, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AurixTokens.accent;
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlass(
        level: GlassLevel.light,
        padding: const EdgeInsets.all(16),
        radius: AurixTokens.radiusSm,
        hoverScale: true,
        showOrangeBorderOnHover: color == AurixTokens.accent,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: color.withValues(alpha: 0.1),
                border:
                    Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: Icon(prompt.icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prompt.title,
                    style: TextStyle(
                      fontFamily: AurixTokens.fontBody,
                      color: AurixTokens.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    prompt.subtitle,
                    style: TextStyle(
                      fontFamily: AurixTokens.fontBody,
                      color: AurixTokens.micro,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: AurixTokens.micro,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// AI Avatar
// ══════════════════════════════════════════════════════════════════

class _AiAvatar extends StatefulWidget {
  const _AiAvatar();

  @override
  State<_AiAvatar> createState() => _AiAvatarState();
}

class _AiAvatarState extends State<_AiAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
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
        final t = _ctrl.value;
        final pulse = 0.5 + sin(t * 2 * pi) * 0.5;
        return Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AurixTokens.accent.withValues(alpha: 0.15 + pulse * 0.08),
                AurixTokens.aiAccent.withValues(alpha: 0.06 + pulse * 0.04),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: AurixTokens.accentGlow
                    .withValues(alpha: 0.12 + pulse * 0.08),
                blurRadius: 40,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AurixTokens.accent.withValues(alpha: 0.2),
                    AurixTokens.aiAccent.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(
                  color: AurixTokens.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  size: 28, color: AurixTokens.accent),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Small UI Components
// ══════════════════════════════════════════════════════════════════

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SmallAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlass(
        level: GlassLevel.light,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        radius: 8,
        hoverScale: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AurixTokens.muted),
            const SizedBox(width: 5),
            Text(label,
                style:
                    const TextStyle(color: AurixTokens.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _GlassIconBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LiquidGlass(
        level: GlassLevel.medium,
        padding: const EdgeInsets.all(8),
        radius: 10,
        hoverScale: false,
        child: Icon(icon, size: 16, color: AurixTokens.muted),
      ),
    );
  }
}
