import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/ai/ai_message.dart';
import 'package:aurix_flutter/ai/ai_service.dart';
import 'package:aurix_flutter/ai/ai_persistence_guard.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';

/// Aurix Studio AI — чистый чат. mode="studio", page="studio", context={}.
class StudioAiScreen extends ConsumerStatefulWidget {
  const StudioAiScreen({super.key});

  @override
  ConsumerState<StudioAiScreen> createState() => _StudioAiScreenState();
}

class _StudioAiScreenState extends ConsumerState<StudioAiScreen> {
  final List<AiMessage> _history = [];
  final ScrollController _chatScrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  bool _loading = false;
  bool _loaded = false;
  String? _persistWarning;

  static const _makeHarderMessage = 'сделай жестче и короче';

  static const _commands = [
    (label: 'cmdHook', msg: '/hook'),
    (label: 'cmdLyrics', msg: '/lyrics'),
    (label: 'cmdSnippet', msg: '/snippet'),
    (label: 'cmdReels', msg: '/snippet 3 сценария по секундам 0-2/2-5/5-8/8-11'),
    (label: 'cmdWarmup', msg: '/warmup'),
    (label: 'cmdContentKit', msg: '/contentkit'),
  ];

  @override
  void dispose() {
    _chatScrollController.dispose();
    _inputController.dispose();
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
      final rows = await repo.getMessages(limit: 60);
      if (!mounted) return;
      setState(() {
        _history
          ..clear()
          ..addAll(rows.map((m) => AiMessage(role: m.role, content: m.content)));
      });
    } on AiSchemaMissingException {
      if (!mounted) return;
      setState(() {
        _persistWarning = 'Нужно применить миграцию для сохранения чата.';
      });
    } catch (e) {
      debugPrint('[StudioAi] load history error: ${formatSupabaseError(e)}');
    }
  }

  Future<void> _sendMessage(String message) async {
    final msg = message.trim();
    if (msg.isEmpty || _loading) return;

    _inputController.clear();
    setState(() {
      _history.insert(0, AiMessage(role: 'user', content: msg));
      _loading = true;
    });
    _scrollToBottom();

    final historyForApi = List<AiMessage>.from(_history.skip(1).take(12).toList().reversed);

    try {
      try {
        await ref.read(aiStudioHistoryRepositoryProvider).append(role: 'user', content: msg);
      } catch (_) {}

      final locale = ref.read(appStateProvider).locale == AppLocale.ru ? 'ru' : 'en';
      final reply = await AiService.send(
        message: msg,
        history: historyForApi,
        mode: 'studio',
        page: 'studio',
        context: <String, dynamic>{},
        locale: locale,
      );

      if (!mounted) return;
      setState(() {
        _history.insert(0, AiMessage(role: 'assistant', content: reply));
        while (_history.length > 24) { _history.removeLast(); }
        _loading = false;
      });
      try {
        await ref.read(aiStudioHistoryRepositoryProvider).append(role: 'assistant', content: reply);
      } catch (_) {}
      _scrollToBottom();
    } on AiServiceException catch (e) {
      if (!mounted) return;
      final err = 'Ошибка: ${e.message}';
      setState(() {
        _history.insert(0, AiMessage(role: 'assistant', content: err));
        while (_history.length > 24) { _history.removeLast(); }
        _loading = false;
      });
      try {
        await ref.read(aiStudioHistoryRepositoryProvider).append(role: 'assistant', content: err);
      } catch (_) {}
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      const err = 'Ошибка соединения. Попробуйте позже.';
      setState(() {
        _history.insert(0, AiMessage(role: 'assistant', content: err));
        while (_history.length > 24) { _history.removeLast(); }
        _loading = false;
      });
      try {
        await ref.read(aiStudioHistoryRepositoryProvider).append(role: 'assistant', content: err);
      } catch (_) {}
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _clearChat() {
    setState(() => _history.clear());
    unawaited(() async {
      try {
        await ref.read(aiStudioHistoryRepositoryProvider).clear();
      } catch (_) {}
    }());
  }

  void _copyText(String text) {
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t(context, 'copied'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          if (_persistWarning != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
                ),
                child: Text(
                  _persistWarning!,
                  style: TextStyle(color: Colors.amber.shade200, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          if (_history.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 4),
                child: IconButton(
                  onPressed: _loading ? null : _clearChat,
                  icon: Icon(Icons.clear_all, color: AurixTokens.orange, size: 20),
                  tooltip: L10n.t(context, 'clearChat'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          Expanded(
            child: _history.isEmpty && !_loading
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(horizontalPadding(context)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 48, color: AurixTokens.orange.withValues(alpha: 0.6)),
                          const SizedBox(height: 16),
                          Text(
                            L10n.t(context, 'studioChatEmpty'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AurixTokens.muted, fontSize: 15),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: _commands.map((c) => _CommandChip(
                              label: L10n.t(context, c.label),
                              loading: _loading,
                              onTap: () => _sendMessage(c.msg),
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _chatScrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _history.length + (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_loading && index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange),
                              ),
                              const SizedBox(width: 10),
                              Text(L10n.t(context, 'aurixThinking'), style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                            ],
                          ),
                        );
                      }
                      final msg = _history[_loading ? index - 1 : index];
                      return _ChatBubble(
                        message: msg,
                        onCopy: _copyText,
                        onMakeHarder: msg.role == 'assistant' ? () => _sendMessage(_makeHarderMessage) : null,
                      );
                    },
                  ),
          ),
          if (_history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _commands.map((c) => _CommandChip(
                  label: L10n.t(context, c.label),
                  loading: _loading,
                  onTap: () => _sendMessage(c.msg),
                )).toList(),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AurixTokens.bg1,
              border: Border(top: BorderSide(color: AurixTokens.stroke())),
            ),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_loading,
                      maxLines: 3,
                      minLines: 1,
                      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: L10n.t(context, 'studioChatPlaceholder'),
                        hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.6)),
                        filled: true,
                        fillColor: AurixTokens.glass(0.08),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (s) => _sendMessage(s),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _loading ? null : () => _sendMessage(_inputController.text),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AurixTokens.orange.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.5)),
                        ),
                        child: Icon(Icons.send_rounded, color: AurixTokens.orange, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
  }
}

class _CommandChip extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _CommandChip({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AurixTokens.glass(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AurixTokens.stroke(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AurixTokens.orange),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final AiMessage message;
  final void Function(String) onCopy;
  final VoidCallback? onMakeHarder;

  const _ChatBubble({
    required this.message,
    required this.onCopy,
    this.onMakeHarder,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? AurixTokens.orange.withValues(alpha: 0.2) : AurixTokens.glass(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUser ? AurixTokens.orange.withValues(alpha: 0.4) : AurixTokens.stroke(0.1),
                  ),
                ),
                child: SelectableText(
                  message.content,
                  style: TextStyle(color: AurixTokens.text, fontSize: 14, height: 1.45),
                ),
              ),
              if (!isUser) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => onCopy(message.content),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy, size: 14, color: AurixTokens.orange),
                          const SizedBox(width: 4),
                          Text(L10n.t(context, 'copy'), style: TextStyle(color: AurixTokens.orange, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (onMakeHarder != null) ...[
                      const SizedBox(width: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onMakeHarder,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt, size: 14, color: AurixTokens.orange),
                            const SizedBox(width: 4),
                            Text(L10n.t(context, 'makeHarder'), style: TextStyle(color: AurixTokens.orange, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
