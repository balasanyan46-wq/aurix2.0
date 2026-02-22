import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurix_flutter/ai/ai_message.dart';
import 'package:aurix_flutter/ai/ai_service.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

const _historyKey = 'aurix_ai_history';
const _historyLimit = 14;

typedef OnNavigateCb = void Function(AppScreen screen, [String? releaseId]);

/// AI chat overlay — floating "Aurix AI" button, calls Cloudflare Worker.
class AiAssistantOverlay extends ConsumerStatefulWidget {
  final OnNavigateCb? onNavigate;
  final String page;
  final Map<String, dynamic>? context;

  const AiAssistantOverlay({
    super.key,
    this.onNavigate,
    this.page = 'cabinet',
    this.context,
  });

  @override
  ConsumerState<AiAssistantOverlay> createState() => _AiAssistantOverlayState();
}

class _AiAssistantOverlayState extends ConsumerState<AiAssistantOverlay> {
  bool _chatOpen = false;
  final List<AiMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = false;
  bool _greetingAdded = false;
  String _lastSentForRetry = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_greetingAdded) {
      _greetingAdded = true;
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      final List<AiMessage> loaded = [];
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          loaded.addAll(
            list
                .map((e) => AiMessage.fromJson(e as Map<String, dynamic>))
                .where((m) => m.role == 'user' || m.role == 'assistant')
                .take(_historyLimit),
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _messages.clear();
        if (loaded.isNotEmpty) {
          _messages.addAll(loaded);
        } else {
          _messages.add(AiMessage(
            role: 'assistant',
            content: L10n.t(context, 'assistantGreeting'),
          ));
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_messages.isEmpty) {
          _messages.add(AiMessage(
            role: 'assistant',
            content: L10n.t(context, 'assistantGreeting'),
          ));
        }
      });
    }
  }

  Future<void> _saveHistory() async {
    try {
      final toSave = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .take(_historyLimit)
          .map((m) => m.toJson())
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(toSave));
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _loading) return;

    _lastSentForRetry = msg;
    setState(() {
      _controller.clear();
      _messages.insert(0, AiMessage(role: 'user', content: msg));
      _loading = true;
    });
    _scrollToTop();

    try {
      final history = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .skip(1)
          .take(12)
          .toList()
          .reversed
          .toList();

      final reply = await AiService.send(
        message: msg,
        history: history,
        page: widget.page,
        context: widget.context,
      );

      if (!mounted) return;
      setState(() {
        _messages.insert(0, AiMessage(role: 'assistant', content: reply));
        _loading = false;
      });
      _saveHistory();
      _scrollToTop();
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.insert(
          0,
          AiMessage(role: 'assistant', content: 'Ошибка: ${e.message}'),
        );
        _loading = false;
      });
      _scrollToTop();
    } catch (e, st) {
      if (!mounted) return;
      debugPrint('[AiAssistant] unhandled: $e\n$st');
      String err = 'Ошибка соединения. Попробуйте позже.';
      if (e.toString().contains('TimeoutException')) {
        err = 'Таймаут, попробуйте ещё раз';
      } else if (e.toString().toLowerCase().contains('failed to fetch') ||
          e.toString().toLowerCase().contains('cors')) {
        err = 'Сеть/браузер блокирует запрос (CORS/Failed to fetch)';
      }
      setState(() {
        _messages.insert(
          0,
          AiMessage(role: 'assistant', content: 'Ошибка: $err'),
        );
        _loading = false;
      });
      _scrollToTop();
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_chatOpen)
            _ChatOverlay(
              messages: _messages,
              controller: _controller,
              scrollController: _scrollController,
              loading: _loading,
              lastSentForRetry: _lastSentForRetry,
              onClose: () => setState(() => _chatOpen = false),
              onSend: _sendMessage,
              onRetry: _lastSentForRetry.isNotEmpty ? () => _sendMessage(_lastSentForRetry) : null,
              onNavigate: widget.onNavigate,
            ),
          Positioned(
            right: 24,
            bottom: 24,
            child: GestureDetector(
              onTap: () => setState(() => _chatOpen = !_chatOpen),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AurixTokens.orange, AurixTokens.orange2],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AurixTokens.orangeGlow,
                      blurRadius: _chatOpen ? 24 : 16,
                      spreadRadius: _chatOpen ? 2 : 0,
                    ),
                  ],
                  border: Border.all(color: AurixTokens.stroke(0.2)),
                ),
                child: Icon(
                  _chatOpen ? Icons.close : Icons.smart_toy_rounded,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatOverlay extends StatelessWidget {
  final List<AiMessage> messages;
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool loading;
  final String lastSentForRetry;
  final VoidCallback onClose;
  final Future<void> Function(String) onSend;
  final VoidCallback? onRetry;
  final OnNavigateCb? onNavigate;

  const _ChatOverlay({
    required this.messages,
    required this.controller,
    required this.scrollController,
    required this.loading,
    required this.lastSentForRetry,
    required this.onClose,
    required this.onSend,
    this.onRetry,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.of(context).size.height;
    final chatHeight = (availableHeight * 0.6).clamp(320.0, 480.0);
    return Positioned(
      right: 24,
      bottom: 92,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 380,
          height: chatHeight,
          decoration: BoxDecoration(
            color: AurixTokens.bg1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AurixTokens.stroke(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AurixTokens.orange.withValues(alpha: 0.1),
                blurRadius: 32,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AurixTokens.glass(0.06),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy_rounded, color: AurixTokens.orange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aurix AI',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AurixTokens.muted, size: 20),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (loading)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TypingIndicator(),
                        ),
                      for (var i = messages.length - 1; i >= 0; i--)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ChatBubble(
                            text: messages[i].content,
                            isUser: messages[i].role == 'user',
                            showNavChips: i == 0 &&
                                messages[i].role == 'assistant' &&
                                !messages[i].content.startsWith('Ошибка:'),
                            showRetry: i == 0 &&
                                messages[i].content.startsWith('Ошибка:') &&
                                onRetry != null &&
                                lastSentForRetry.isNotEmpty,
                            onRetry: onRetry,
                            onNavigate: onNavigate,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AurixTokens.glass(0.04),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        enabled: !loading,
                        decoration: InputDecoration(
                          hintText: L10n.t(context, 'assistantPlaceholder'),
                          hintStyle: TextStyle(color: AurixTokens.muted),
                          filled: true,
                          fillColor: AurixTokens.glass(0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (s) => onSend(s),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: loading ? null : () => onSend(controller.text),
                      icon: Icon(
                        Icons.send_rounded,
                        color: loading ? AurixTokens.muted : AurixTokens.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AurixTokens.glass(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AurixTokens.stroke(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AurixTokens.orange,
              ),
            ),
            const SizedBox(width: 12),
            Text('Печатает...', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool showNavChips;
  final bool showRetry;
  final VoidCallback? onRetry;
  final OnNavigateCb? onNavigate;

  const _ChatBubble({
    required this.text,
    required this.isUser,
    required this.showNavChips,
    this.showRetry = false,
    this.onRetry,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser
                  ? AurixTokens.orange.withValues(alpha: 0.2)
                  : AurixTokens.glass(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUser
                    ? AurixTokens.orange.withValues(alpha: 0.4)
                    : AurixTokens.stroke(0.1),
              ),
            ),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              text,
              style: TextStyle(color: AurixTokens.text, fontSize: 14, height: 1.4),
            ),
          ),
        ),
        if (showRetry && onRetry != null) ...[
          const SizedBox(height: 10),
          _NavChip(label: 'Повторить', onTap: onRetry!),
        ],
        if (showNavChips && onNavigate != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: [
              _NavChip(
                label: L10n.t(context, 'createRelease'),
                onTap: () => onNavigate!(AppScreen.uploadRelease),
              ),
              _NavChip(
                label: L10n.t(context, 'importCsv'),
                onTap: () => onNavigate!(AppScreen.analytics),
              ),
              _NavChip(
                label: L10n.t(context, 'services'),
                onTap: () => onNavigate!(AppScreen.services),
              ),
              _NavChip(
                label: L10n.t(context, 'subscription'),
                onTap: () => onNavigate!(AppScreen.subscription),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NavChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AurixTokens.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: TextStyle(color: AurixTokens.orange, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
