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
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/core/api/api_error.dart';

import 'widgets/ai_list.dart';
import 'widgets/ai_magic_background.dart';
import 'widgets/ai_glow_card.dart';
import 'widgets/ai_action_chips.dart';
import 'widgets/ai_typing_indicator.dart';
import 'generate_cover_screen.dart';

// ── Modes ────────────────────────────────────────────────────

class _AiMode {
  final String id, label;
  final IconData icon;
  const _AiMode(this.id, this.label, this.icon);
}

const _modes = [
  _AiMode('chat', 'Chat', Icons.chat_rounded),
  _AiMode('dnk', 'DNK', Icons.fingerprint_rounded),
  _AiMode('reels', 'Reels', Icons.videocam_rounded),
  _AiMode('lyrics', 'Lyrics', Icons.edit_note_rounded),
  _AiMode('ideas', 'Ideas', Icons.lightbulb_rounded),
];

// ── Welcome prompts ──────────────────────────────────────────

class _WelcomePrompt {
  final String title;
  final String subtitle;
  final IconData icon;
  final String prompt;
  final String? mode;
  const _WelcomePrompt(this.title, this.subtitle, this.icon, this.prompt, [this.mode]);
}

const _welcomePrompts = [
  _WelcomePrompt(
    'Хук для трека',
    'Создай цепляющий хук',
    Icons.music_note_rounded,
    'Напиши хук для трека про ночной город — чтобы зацепил с первых секунд',
    'lyrics',
  ),
  _WelcomePrompt(
    'Reels стратегия',
    '10 вирусных идей',
    Icons.videocam_rounded,
    '10 идей для Reels под мой новый трек — нужен вирусный контент',
    'reels',
  ),
  _WelcomePrompt(
    'Разбор аудитории',
    'Кто будет слушать',
    Icons.fingerprint_rounded,
    'Проанализируй аудиторию для начинающего рэп-артиста из СНГ',
    'dnk',
  ),
  _WelcomePrompt(
    'Идеи для трека',
    '10 концепций',
    Icons.lightbulb_rounded,
    'Придумай 10 идей для трека в жанре поп-рэп, тема — амбиции и рост',
    'ideas',
  ),
];

// ── Chat Entry ───────────────────────────────────────────────

class _ChatEntry {
  final String role;
  final String content;
  final String mode;
  final AiFollowUp? followUp;
  final DateTime ts;

  _ChatEntry({
    required this.role,
    required this.content,
    required this.mode,
    this.followUp,
  }) : ts = DateTime.now();
}

// ══════════════════════════════════════════════════════════════
// Main Screen
// ══════════════════════════════════════════════════════════════

class StudioAiScreen extends ConsumerStatefulWidget {
  const StudioAiScreen({super.key});

  @override
  ConsumerState<StudioAiScreen> createState() => _StudioAiScreenState();
}

class _StudioAiScreenState extends ConsumerState<StudioAiScreen>
    with TickerProviderStateMixin {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<_ChatEntry> _entries = [];

  String _selectedMode = 'chat';
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
  }

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

  // ── Data ─────────────────────────────────────────────────

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
                mode: 'chat',
              )));
      });
    } on AiSchemaMissingException {
      // ignore
    } catch (e) {
      debugPrint('[StudioAi] load: ${formatApiError(e)}');
    }
  }

  Future<void> _send(String message, {String? overrideMode}) async {
    final msg = message.trim();
    if (msg.isEmpty || _loading) return;

    _input.clear();
    final mode = overrideMode ?? _selectedMode;
    if (overrideMode != null) {
      setState(() => _selectedMode = overrideMode);
    }

    setState(() {
      _entries.insert(0, _ChatEntry(role: 'user', content: msg, mode: mode));
      _loading = true;
    });
    _scrollToBottom();

    final historyForApi = _entries
        .skip(1)
        .take(10)
        .map((e) => AiMessage(
              role: e.role,
              content: AiFollowUp.stripFollowUp(e.content),
            ))
        .toList()
        .reversed
        .toList();

    try {
      try {
        await ref
            .read(aiStudioHistoryRepositoryProvider)
            .append(role: 'user', content: msg);
      } catch (_) {}

      final locale =
          ref.read(appStateProvider).locale == AppLocale.ru ? 'ru' : 'en';

      // Slight delay for "alive" feel
      await Future.delayed(const Duration(milliseconds: 400));

      final reply = await AiService.send(
        message: msg,
        history: historyForApi,
        mode: mode,
        page: 'studio',
        locale: locale,
      );

      if (!mounted) return;

      // Parse follow-up
      final followUp = AiFollowUp.parse(reply);

      setState(() {
        _entries.insert(
          0,
          _ChatEntry(
            role: 'assistant',
            content: reply,
            mode: mode,
            followUp: followUp,
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
          0, _ChatEntry(role: 'assistant', content: text, mode: 'chat'));
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
    _send(prompt, overrideMode: mode);
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AiMagicBackground(
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

  // ── Welcome Screen ─────────────────────────────────────────

  Widget _buildWelcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI Avatar with glow
            _AiAvatar(),
            const SizedBox(height: 24),

            // Title
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [AurixTokens.text, AurixTokens.accent],
              ).createShader(bounds),
              child: const Text(
                'Aurix Studio AI',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Твой продюсер. Опиши идею — я сделаю остальное.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AurixTokens.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            // Cover generation card
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WelcomeCard(
                prompt: const _WelcomePrompt(
                  'Обложка',
                  'Сгенерировать обложку',
                  Icons.palette_rounded,
                  '',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GenerateCoverScreen()),
                ),
              ),
            ),

            // Welcome cards
            ...List.generate(_welcomePrompts.length, (i) {
              final p = _welcomePrompts[i];
              return Padding(
                padding: EdgeInsets.only(bottom: i < _welcomePrompts.length - 1 ? 10 : 0),
                child: _WelcomeCard(
                  prompt: p,
                  onTap: () => _send(p.prompt, overrideMode: p.mode),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Chat List ──────────────────────────────────────────────

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
            return _AnimatedEntry(
              key: ValueKey('${entry.hashCode}_$i'),
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

        // Clear button
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
          child: AiGlowCard(
            glowColor: AurixTokens.accent,
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

  // ── Mode Bar ───────────────────────────────────────────────

  Widget _buildModeBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AurixTokens.bg0.withValues(alpha: 0.6),
        border: Border(top: BorderSide(color: AurixTokens.stroke(0.08))),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final m = _modes[i];
          final sel = m.id == _selectedMode;
          return GestureDetector(
            onTap: _loading
                ? null
                : () => setState(() => _selectedMode = m.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: sel
                    ? LinearGradient(colors: [
                        AurixTokens.accent.withValues(alpha: 0.22),
                        AurixTokens.accentWarm.withValues(alpha: 0.1),
                      ])
                    : null,
                color: sel ? null : AurixTokens.glass(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sel
                      ? AurixTokens.accent.withValues(alpha: 0.4)
                      : AurixTokens.stroke(0.08),
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: AurixTokens.accentGlow.withValues(alpha: 0.12),
                          blurRadius: 16,
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
                      color:
                          sel ? AurixTokens.text : AurixTokens.textSecondary,
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
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

  // ── Input Bar ──────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AurixTokens.bg0.withValues(alpha: 0.85),
            AurixTokens.bg0.withValues(alpha: 0.95),
          ],
        ),
        border: Border(top: BorderSide(color: AurixTokens.stroke(0.1))),
      ),
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
                  hintText: 'Опиши идею, трек или задачу...',
                  hintStyle: TextStyle(
                      color: AurixTokens.muted.withValues(alpha: 0.45)),
                  filled: true,
                  fillColor: AurixTokens.glass(0.05),
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
            _SendButton(loading: _loading, onTap: () => _send(_input.text)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Chat Bubble — renders user message or AI result + actions
// ══════════════════════════════════════════════════════════════

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
              // Bubble
              isUser ? _buildUserBubble() : _buildAiBubble(context),

              // AI bottom actions
              if (!isUser) ...[
                const SizedBox(height: 8),
                // Copy + regenerate
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

                // Action chips
                if (onAction != null) ...[
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AurixTokens.accent.withValues(alpha: 0.18),
            AurixTokens.accentWarm.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(6),
        ),
        border: Border.all(
          color: AurixTokens.accent.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AurixTokens.accentGlow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        entry.content,
        style: TextStyle(
          color: AurixTokens.text,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildAiBubble(BuildContext context) {
    return AiGlowCard(
      glowColor: AurixTokens.aiAccent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI badge
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
            ],
          ),
          const SizedBox(height: 12),

          // Content
          _buildAiContent(),
        ],
      ),
    );
  }

  Widget _buildAiContent() {
    final parsed = parseAiResponse(entry.content, entry.mode);
    return AiResultRenderer(result: parsed, onCopy: onCopy);
  }
}

// ══════════════════════════════════════════════════════════════
// Welcome Card
// ══════════════════════════════════════════════════════════════

class _WelcomeCard extends StatefulWidget {
  final _WelcomePrompt prompt;
  final VoidCallback onTap;

  const _WelcomeCard({required this.prompt, required this.onTap});

  @override
  State<_WelcomeCard> createState() => _WelcomeCardState();
}

class _WelcomeCardState extends State<_WelcomeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AurixTokens.glass(0.06),
                AurixTokens.bg2.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AurixTokens.stroke(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AurixTokens.accent.withValues(alpha: 0.15),
                      AurixTokens.accent.withValues(alpha: 0.04),
                    ],
                  ),
                ),
                child: Icon(widget.prompt.icon,
                    size: 18, color: AurixTokens.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.prompt.title,
                      style: TextStyle(
                        color: AurixTokens.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.prompt.subtitle,
                      style: TextStyle(
                        color: AurixTokens.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AurixTokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI Avatar (welcome screen)
// ══════════════════════════════════════════════════════════════

class _AiAvatar extends StatefulWidget {
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
                color: AurixTokens.accentGlow.withValues(alpha: 0.12 + pulse * 0.08),
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

// ══════════════════════════════════════════════════════════════
// Animated Entry — fade + slide
// ══════════════════════════════════════════════════════════════

class _AnimatedEntry extends StatefulWidget {
  final Widget child;
  const _AnimatedEntry({super.key, required this.child});

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Small UI Components
// ══════════════════════════════════════════════════════════════

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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AurixTokens.glass(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AurixTokens.stroke(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AurixTokens.muted),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SendButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: loading
                ? [
                    AurixTokens.bg2.withValues(alpha: 0.3),
                    AurixTokens.bg2.withValues(alpha: 0.2),
                  ]
                : [
                    AurixTokens.accent.withValues(alpha: 0.3),
                    AurixTokens.accentWarm.withValues(alpha: 0.18),
                  ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: loading
                ? AurixTokens.stroke(0.12)
                : AurixTokens.accent.withValues(alpha: 0.4),
          ),
          boxShadow: loading
              ? null
              : [
                  BoxShadow(
                    color: AurixTokens.accentGlow.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: -8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Icon(
          Icons.send_rounded,
          color: loading ? AurixTokens.muted : AurixTokens.accent,
          size: 20,
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
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AurixTokens.bg2.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AurixTokens.stroke(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: AurixTokens.muted),
      ),
    );
  }
}
