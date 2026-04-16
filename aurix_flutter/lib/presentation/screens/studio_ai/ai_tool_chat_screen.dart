import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/ai/ai_message.dart';
import 'package:aurix_flutter/ai/ai_service.dart';
import 'package:aurix_flutter/ai/ai_persistence_guard.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/core/api/api_error.dart';
import 'package:aurix_flutter/core/services/event_tracker.dart';
import 'ai_tool_config.dart';
import 'studio_ai_screen.dart' show AiMode;
import 'widgets/ai_list.dart';
import 'widgets/ai_action_chips.dart';
import 'widgets/ai_typing_indicator.dart';

class AiToolChatScreen extends ConsumerStatefulWidget {
  const AiToolChatScreen({super.key, required this.tool, this.initialPrompt});
  final AiToolConfig tool;
  final String? initialPrompt;

  @override
  ConsumerState<AiToolChatScreen> createState() => _AiToolChatScreenState();
}

class _AiToolChatScreenState extends ConsumerState<AiToolChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<_Entry> _entries = [];
  bool _loading = false;
  bool _loaded = false;
  bool _initialSent = false;

  AiMode get _mode => widget.tool.mode;
  String get _modeId => _mode.id;

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

  Future<void> _loadHistory() async {
    final repo = ref.read(aiStudioHistoryRepositoryProvider);
    try {
      final rows = await repo.getMessages(limit: 60, generativeType: _modeId);
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(rows.map((m) => _Entry(
                role: m.role,
                content: m.content,
              )));
      });
    } on AiSchemaMissingException {
      // table not created yet
    } catch (e) {
      debugPrint('[AiToolChat] load: ${formatApiError(e)}');
    }

    if (!_initialSent && widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _initialSent = true;
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _send(widget.initialPrompt!);
    }
  }

  Future<void> _send(String message) async {
    final msg = message.trim();
    if (msg.isEmpty || _loading) return;
    _input.clear();

    setState(() {
      _entries.insert(0, _Entry(role: 'user', content: msg));
      _loading = true;
    });
    _scrollToBottom();

    try {
      // Persist user message with generativeType
      try {
        await ref.read(aiStudioHistoryRepositoryProvider).append(
              role: 'user',
              content: msg,
              meta: {'generativeType': _modeId},
            );
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 200));

      String reply;
      if (_mode.isGenerative) {
        final result = await AiService.generate(type: _modeId, prompt: msg);
        reply = result.content;
      } else {
        final history = _entries
            .skip(1)
            .take(10)
            .map((e) => AiMessage(role: e.role, content: AiFollowUp.stripFollowUp(e.content)))
            .toList()
            .reversed
            .toList();

        final locale = ref.read(appStateProvider).locale == AppLocale.ru ? 'ru' : 'en';
        reply = await AiService.send(
          message: msg,
          history: history,
          mode: _modeId,
          page: 'studio',
          locale: locale,
        );
      }

      if (!mounted) return;

      EventTracker.track('ai_studio_sent', meta: {'mode': _modeId});

      setState(() {
        _entries.insert(0, _Entry(role: 'assistant', content: reply));
        while (_entries.length > 60) _entries.removeLast();
        _loading = false;
      });

      try {
        await ref.read(aiStudioHistoryRepositoryProvider).append(
              role: 'assistant',
              content: reply,
              meta: {'generativeType': _modeId},
            );
      } catch (_) {}
    } on AiServiceException catch (e) {
      _insertError(e.message);
    } catch (_) {
      _insertError('AI временно недоступен');
    }
    _scrollToBottom();
  }

  void _insertError(String text) {
    if (!mounted) return;
    setState(() {
      _entries.insert(0, _Entry(role: 'assistant', content: text));
      _loading = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    });
  }

  void _clearChat() {
    setState(() => _entries.clear());
    unawaited(() async {
      try {
        await ref.read(aiStudioHistoryRepositoryProvider).clear(generativeType: _modeId);
      } catch (_) {}
    }());
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: AiFollowUp.stripFollowUp(text)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Скопировано'),
      backgroundColor: AurixTokens.bg2,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1.withValues(alpha: 0.8),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(tool.icon, size: 18, color: tool.color),
            const SizedBox(width: 8),
            Text(tool.title, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AurixTokens.muted, size: 20),
              tooltip: 'Очистить чат',
              onPressed: _clearChat,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _entries.isEmpty && !_loading
                ? _buildEmpty(tool)
                : _buildMessages(),
          ),
          _buildInputBar(tool),
        ],
      ),
    );
  }

  Widget _buildEmpty(AiToolConfig tool) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: tool.color.withValues(alpha: 0.2)),
              ),
              child: Icon(tool.icon, size: 28, color: tool.color),
            ),
            const SizedBox(height: 16),
            Text(
              tool.title,
              style: TextStyle(
                fontFamily: AurixTokens.fontHeading,
                color: AurixTokens.text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tool.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (tool.examplePrompts.isNotEmpty) ...[
              Text(
                'Попробуй:',
                style: TextStyle(color: AurixTokens.micro, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: tool.examplePrompts.map((p) => _ExampleChip(
                      text: p,
                      color: tool.color,
                      onTap: () => _send(p),
                    )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _entries.length + (_loading ? 1 : 0),
      itemBuilder: (context, i) {
        if (_loading && i == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AiTypingIndicator(),
            ),
          );
        }
        final entry = _entries[_loading ? i - 1 : i];
        final isUser = entry.role == 'user';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MessageBubble(
            content: entry.content,
            isUser: isUser,
            toolColor: widget.tool.color,
            onCopy: () => _copy(entry.content),
            onRetry: isUser ? null : () {
              // Find last user message and resend
              final lastUser = _entries.firstWhere((e) => e.role == 'user', orElse: () => _Entry(role: 'user', content: ''));
              if (lastUser.content.isNotEmpty) _send(lastUser.content);
            },
          ),
        );
      },
    );
  }

  Widget _buildInputBar(AiToolConfig tool) {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 8, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 8),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        border: Border(top: BorderSide(color: AurixTokens.stroke(0.12))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focusNode,
              style: const TextStyle(color: AurixTokens.text, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(_input.text),
              decoration: InputDecoration(
                hintText: tool.mode.placeholder.isNotEmpty ? tool.mode.placeholder : 'Напишите сообщение...',
                hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                filled: true,
                fillColor: AurixTokens.bg2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.accent)),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AurixTokens.accent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _send(_input.text),
                    icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    padding: EdgeInsets.zero,
                  ),
                ),
        ],
      ),
    );
  }
}

class _Entry {
  final String role;
  final String content;
  const _Entry({required this.role, required this.content});
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.text, required this.color, required this.onTap});
  final String text;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Text(
          text,
          style: TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.content, required this.isUser, required this.toolColor, this.onCopy, this.onRetry});
  final String content;
  final bool isUser;
  final Color toolColor;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? toolColor.withValues(alpha: 0.12) : AurixTokens.bg1,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: Border.all(
              color: isUser ? toolColor.withValues(alpha: 0.2) : AurixTokens.stroke(0.12),
            ),
          ),
          child: SelectableText(
            content,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        if (!isUser)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onCopy != null)
                  _SmallBtn(icon: Icons.copy_rounded, label: 'Скопировать', onTap: onCopy!),
                if (onRetry != null) ...[
                  const SizedBox(width: 8),
                  _SmallBtn(icon: Icons.refresh_rounded, label: 'Ещё раз', onTap: onRetry!),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AurixTokens.micro),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(color: AurixTokens.micro, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
