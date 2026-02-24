import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/data/models/support_ticket_model.dart';
import 'package:aurix_flutter/data/models/support_message_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  List<SupportTicketModel> _tickets = [];
  bool _loading = true;
  SupportTicketModel? _activeTicket;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      final tickets = await ref.read(supportTicketRepositoryProvider).getMyTickets(userId);
      if (mounted) setState(() { _tickets = tickets; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTicket() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    final subjectCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Новое обращение', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjectCtrl,
              style: const TextStyle(color: AurixTokens.text, fontSize: 14),
              decoration: _inputDecoration('Тема обращения'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              style: const TextStyle(color: AurixTokens.text, fontSize: 14),
              decoration: _inputDecoration('Опишите проблему...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.orange, foregroundColor: Colors.black),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (subjectCtrl.text.trim().isEmpty || msgCtrl.text.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните тему и сообщение')));
      return;
    }

    try {
      final ticket = await ref.read(supportTicketRepositoryProvider).createTicket(
        userId: userId,
        subject: subjectCtrl.text.trim(),
        message: msgCtrl.text.trim(),
      );
      // Also create the first message
      await ref.read(supportTicketRepositoryProvider).sendMessage(
        ticketId: ticket.id,
        senderId: userId,
        senderRole: 'user',
        body: msgCtrl.text.trim(),
      );
      await _loadTickets();
      if (mounted) setState(() => _activeTicket = ticket);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
    filled: true,
    fillColor: AurixTokens.bg2,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  @override
  Widget build(BuildContext context) {
    if (_activeTicket != null) {
      return _ChatView(
        ticket: _activeTicket!,
        onBack: () {
          setState(() => _activeTicket = null);
          _loadTickets();
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  L10n.t(context, 'support'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: _createTicket,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Написать'),
                style: FilledButton.styleFrom(
                  backgroundColor: AurixTokens.orange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('Ваши обращения в поддержку', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AurixTokens.orange))
              : _tickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AurixTokens.muted.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          const Text('У вас пока нет обращений', style: TextStyle(color: AurixTokens.muted, fontSize: 15)),
                          const SizedBox(height: 8),
                          const Text('Нажмите «Написать», чтобы задать вопрос', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: _tickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _TicketRow(
                        ticket: _tickets[i],
                        onTap: () => setState(() => _activeTicket = _tickets[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.onTap});
  final SupportTicketModel ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (ticket.status) {
      'open' => Colors.amber,
      'in_progress' => Colors.blue,
      'resolved' => AurixTokens.positive,
      'closed' => AurixTokens.muted,
      _ => AurixTokens.muted,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AurixGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AurixTokens.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chat_rounded, color: AurixTokens.orange, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ticket.subject, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(ticket.message, style: const TextStyle(color: AurixTokens.muted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(ticket.statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 4),
                Text(DateFormat('dd.MM.yy').format(ticket.updatedAt), style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AurixTokens.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ChatView extends ConsumerStatefulWidget {
  const _ChatView({required this.ticket, required this.onBack});
  final SupportTicketModel ticket;
  final VoidCallback onBack;

  @override
  ConsumerState<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<_ChatView> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<SupportMessageModel> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final msgs = await ref.read(supportTicketRepositoryProvider).getMessages(widget.ticket.id);
      if (mounted) {
        setState(() { _messages = msgs; _loading = false; });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final body = _msgCtrl.text.trim();
    if (body.isEmpty) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await ref.read(supportTicketRepositoryProvider).sendMessage(
        ticketId: widget.ticket.id,
        senderId: userId,
        senderRole: 'user',
        body: body,
      );
      await _loadMessages();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
          decoration: BoxDecoration(
            color: AurixTokens.bg1,
            border: Border(bottom: BorderSide(color: AurixTokens.border)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
              ),
              const SizedBox(width: 4),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AurixTokens.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.support_agent_rounded, color: AurixTokens.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.ticket.subject, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Поддержка AURIX', style: TextStyle(color: AurixTokens.muted, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (widget.ticket.isResolved ? AurixTokens.positive : Colors.amber).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.ticket.statusLabel,
                  style: TextStyle(
                    color: widget.ticket.isResolved ? AurixTokens.positive : Colors.amber,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AurixTokens.orange))
              : _messages.isEmpty
                  ? const Center(child: Text('Ожидайте ответа от поддержки', style: TextStyle(color: AurixTokens.muted)))
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        final isMe = msg.isUser;
                        return _MessageBubble(message: msg, isMe: isMe);
                      },
                    ),
        ),
        // Input
        Container(
          padding: EdgeInsets.only(
            left: 16, right: 8, top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: AurixTokens.bg1,
            border: Border(top: BorderSide(color: AurixTokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Написать сообщение...',
                    hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                    filled: true,
                    fillColor: AurixTokens.bg2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange)),
                    )
                  : IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded, color: AurixTokens.orange),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});
  final SupportMessageModel message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AurixTokens.orange.withValues(alpha: 0.15),
              child: const Icon(Icons.support_agent_rounded, size: 16, color: AurixTokens.orange),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AurixTokens.orange.withValues(alpha: 0.15)
                    : AurixTokens.bg2,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(
                  color: isMe
                      ? AurixTokens.orange.withValues(alpha: 0.25)
                      : AurixTokens.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.body,
                    style: const TextStyle(color: AurixTokens.text, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: TextStyle(color: AurixTokens.muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
