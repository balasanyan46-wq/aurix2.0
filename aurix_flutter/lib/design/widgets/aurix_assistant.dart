import 'package:flutter/material.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

typedef OnNavigateCb = void Function(AppScreen screen, [String? releaseId]);

/// Плавающая кнопка AURIX Assistant — mock chat с навигационными chips.
class AurixAssistant extends StatefulWidget {
  final OnNavigateCb? onNavigate;

  const AurixAssistant({super.key, this.onNavigate});

  @override
  State<AurixAssistant> createState() => _AurixAssistantState();
}

class _AurixAssistantState extends State<AurixAssistant> {
  bool _chatOpen = false;
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _greetingAdded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_greetingAdded) {
      _greetingAdded = true;
      _messages.add(_ChatMessage(
        text: L10n.t(context, 'assistantGreeting'),
        isUser: false,
        chips: null,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.insert(0, _ChatMessage(text: text.trim(), isUser: true, chips: null));
      _controller.clear();
      final reply = _buildAssistantReply(text);
      _messages.insert(0, reply);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  _ChatMessage _buildAssistantReply(String _) {
    final chips = [
      _ChipAction(L10n.t(context, 'createRelease'), () {
        widget.onNavigate?.call(AppScreen.uploadRelease);
        if (mounted) setState(() => _chatOpen = false);
      }),
      _ChipAction(L10n.t(context, 'importCsv'), () {
        widget.onNavigate?.call(AppScreen.analytics);
        if (mounted) setState(() => _chatOpen = false);
      }),
      _ChipAction(L10n.t(context, 'services'), () {
        widget.onNavigate?.call(AppScreen.services);
        if (mounted) setState(() => _chatOpen = false);
      }),
      _ChipAction(L10n.t(context, 'subscription'), () {
        widget.onNavigate?.call(AppScreen.subscription);
        if (mounted) setState(() => _chatOpen = false);
      }),
    ];
    const replies = [
      'Перейдите в раздел «Релизы» и нажмите «Создать релиз». Или используйте быстрые действия ниже.',
      'Go to Releases and tap Create Release. Or use the quick actions below.',
    ];
    final replyText = Localizations.localeOf(context).languageCode == 'ru' ? replies[0] : replies[1];
    return _ChatMessage(text: replyText, isUser: false, chips: chips);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_chatOpen)
            _AssistantChatOverlay(
              messages: _messages,
              controller: _controller,
              scrollController: _scrollController,
              onClose: () => setState(() => _chatOpen = false),
              onSend: _sendMessage,
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
                  _chatOpen ? Icons.close : Icons.support_agent_rounded,
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

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<_ChipAction>? chips;

  _ChatMessage({required this.text, required this.isUser, this.chips});
}

class _ChipAction {
  final String label;
  final VoidCallback onTap;

  _ChipAction(this.label, this.onTap);
}

class _AssistantChatOverlay extends StatelessWidget {
  final List<_ChatMessage> messages;
  final TextEditingController controller;
  final ScrollController scrollController;
  final VoidCallback onClose;
  final void Function(String) onSend;

  const _AssistantChatOverlay({
    required this.messages,
    required this.controller,
    required this.scrollController,
    required this.onClose,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 24,
      bottom: 92,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 380,
          height: 480,
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
                    Icon(Icons.support_agent_rounded, color: AurixTokens.orange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(L10n.t(context, 'assistantTitle'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
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
                      for (var i = messages.length - 1; i >= 0; i--) ...[
                        _ChatBubble(
                          text: messages[i].text,
                          isUser: messages[i].isUser,
                          chips: messages[i].chips,
                        ),
                        const SizedBox(height: 12),
                      ],
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
                        onSubmitted: onSend,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => onSend(controller.text),
                      icon: Icon(Icons.send_rounded, color: AurixTokens.orange),
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

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final List<_ChipAction>? chips;

  const _ChatBubble({required this.text, required this.isUser, this.chips});

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
              color: isUser ? AurixTokens.orange.withValues(alpha: 0.2) : AurixTokens.glass(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isUser ? AurixTokens.orange.withValues(alpha: 0.4) : AurixTokens.stroke(0.1)),
            ),
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(text, style: TextStyle(color: AurixTokens.text, fontSize: 14, height: 1.4)),
          ),
        ),
        if (chips != null && chips!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: chips!.map((c) => _ChipButton(label: c.label, onTap: c.onTap)).toList(),
          ),
        ],
      ],
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ChipButton({required this.label, required this.onTap});

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
          child: Text(label, style: TextStyle(color: AurixTokens.orange, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
