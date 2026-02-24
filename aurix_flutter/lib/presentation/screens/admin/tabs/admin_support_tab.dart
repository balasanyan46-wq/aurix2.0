import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/models/support_ticket_model.dart';
import 'package:aurix_flutter/data/models/support_message_model.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

class AdminSupportTab extends ConsumerStatefulWidget {
  const AdminSupportTab({super.key});

  @override
  ConsumerState<AdminSupportTab> createState() => _AdminSupportTabState();
}

class _AdminSupportTabState extends ConsumerState<AdminSupportTab> {
  String _statusFilter = 'all';
  SupportTicketModel? _openedTicket;

  static const _statuses = ['all', 'open', 'in_progress', 'resolved', 'closed'];

  Color _statusColor(String status) => switch (status) {
        'open' => Colors.amber,
        'in_progress' => Colors.blue,
        'resolved' => AurixTokens.positive,
        'closed' => AurixTokens.muted,
        _ => AurixTokens.muted,
      };

  String _statusLabel(String s) => switch (s) {
        'open' => 'Открытые',
        'in_progress' => 'В работе',
        'resolved' => 'Решённые',
        'closed' => 'Закрытые',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    if (_openedTicket != null) {
      return _AdminChatView(
        ticket: _openedTicket!,
        onBack: () {
          setState(() => _openedTicket = null);
          ref.invalidate(allTicketsProvider);
        },
      );
    }

    final ticketsAsync = ref.watch(allTicketsProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: AurixTokens.bg1,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statuses.map((s) {
                final selected = _statusFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s == 'all' ? 'Все' : _statusLabel(s)),
                    selected: selected,
                    onSelected: (_) => setState(() => _statusFilter = s),
                    selectedColor: AurixTokens.orange.withValues(alpha: 0.2),
                    backgroundColor: AurixTokens.bg2,
                    labelStyle: TextStyle(
                      color: selected ? AurixTokens.orange : AurixTokens.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: selected ? AurixTokens.orange.withValues(alpha: 0.4) : AurixTokens.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: ticketsAsync.when(
            data: (tickets) {
              final filtered = _statusFilter == 'all'
                  ? tickets
                  : tickets.where((t) => t.status == _statusFilter).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.support_agent_rounded, size: 48, color: AurixTokens.muted.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text('Нет тикетов', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                      if (kDebugMode) ...[
                        const SizedBox(height: 16),
                        _CreateTestTicketButton(onCreated: () => ref.invalidate(allTicketsProvider)),
                      ],
                    ],
                  ),
                );
              }

              return Stack(
                children: [
                  ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = filtered[i];
                      return _TicketCard(
                        ticket: t,
                        statusColor: _statusColor(t.status),
                        onTap: () => setState(() => _openedTicket = t),
                      );
                    },
                  ),
                  if (kDebugMode)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: _CreateTestTicketButton(onCreated: () => ref.invalidate(allTicketsProvider)),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent.withValues(alpha: 0.6)),
                    const SizedBox(height: 12),
                    Text(e.toString().replaceAll('Exception: ', ''), style: const TextStyle(color: AurixTokens.muted, fontSize: 13), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(allTicketsProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Повторить'),
                      style: TextButton.styleFrom(foregroundColor: AurixTokens.orange),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Ticket card ───

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.statusColor, required this.onTap});
  final SupportTicketModel ticket;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (ticket.priority) {
      'high' => Colors.redAccent,
      'medium' => Colors.amber,
      _ => AurixTokens.muted,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AurixTokens.bg1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AurixTokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(ticket.subject, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text(ticket.statusLabel.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: priorityColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text(ticket.priorityLabel.toUpperCase(), style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(ticket.message, style: const TextStyle(color: AurixTokens.muted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('ID: ${ticket.userId.substring(0, 8)}...', style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontFamily: 'monospace')),
                const Spacer(),
                Text(DateFormat('dd.MM.yy HH:mm').format(ticket.updatedAt), style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Admin chat view ───

class _AdminChatView extends ConsumerStatefulWidget {
  const _AdminChatView({required this.ticket, required this.onBack});
  final SupportTicketModel ticket;
  final VoidCallback onBack;

  @override
  ConsumerState<_AdminChatView> createState() => _AdminChatViewState();
}

class _AdminChatViewState extends ConsumerState<_AdminChatView> {
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
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final body = _msgCtrl.text.trim();
    if (body.isEmpty) return;
    final adminId = ref.read(currentUserProvider)?.id;
    if (adminId == null) return;

    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await ref.read(supportTicketRepositoryProvider).sendMessage(
        ticketId: widget.ticket.id,
        senderId: adminId,
        senderRole: 'admin',
        body: body,
      );
      // Mark as in_progress if it was open
      if (widget.ticket.status == 'open') {
        await ref.read(supportTicketRepositoryProvider).updateStatus(widget.ticket.id, 'in_progress');
      }
      await _loadMessages();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _changeStatus(String status) async {
    try {
      await ref.read(supportTicketRepositoryProvider).updateStatus(widget.ticket.id, status);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Статус: $status')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            color: AurixTokens.bg1,
            border: Border(bottom: BorderSide(color: AurixTokens.border)),
          ),
          child: Row(
            children: [
              IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text)),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.ticket.subject, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('User: ${widget.ticket.userId.substring(0, 8)}...', style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontFamily: 'monospace')),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: _changeStatus,
                color: AurixTokens.bg2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                icon: const Icon(Icons.more_vert_rounded, color: AurixTokens.muted, size: 20),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'open', child: Text('Открыт', style: TextStyle(fontSize: 13))),
                  const PopupMenuItem(value: 'in_progress', child: Text('В работе', style: TextStyle(fontSize: 13))),
                  const PopupMenuItem(value: 'resolved', child: Text('Решён', style: TextStyle(fontSize: 13))),
                  const PopupMenuItem(value: 'closed', child: Text('Закрыт', style: TextStyle(fontSize: 13))),
                ],
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AurixTokens.orange))
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 40, color: AurixTokens.muted.withValues(alpha: 0.3)),
                          const SizedBox(height: 8),
                          Text('Пользователь ещё не написал в чат', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Первое сообщение: «${widget.ticket.message}»', style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        final isAdmin = msg.isAdmin;
                        return _AdminMessageBubble(message: msg, isMe: isAdmin);
                      },
                    ),
        ),
        // Input
        Container(
          padding: EdgeInsets.only(left: 16, right: 8, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 8),
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
                    hintText: 'Ответить...',
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
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange)))
                  : IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded, color: AurixTokens.orange)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminMessageBubble extends StatelessWidget {
  const _AdminMessageBubble({required this.message, required this.isMe});
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
              backgroundColor: AurixTokens.bg2,
              child: const Icon(Icons.person, size: 16, color: AurixTokens.muted),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AurixTokens.orange.withValues(alpha: 0.15) : AurixTokens.bg2,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(color: isMe ? AurixTokens.orange.withValues(alpha: 0.25) : AurixTokens.border),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('Пользователь', style: TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  if (isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('Поддержка', style: TextStyle(color: AurixTokens.orange, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  Text(message.body, style: const TextStyle(color: AurixTokens.text, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 4),
                  Text(DateFormat('HH:mm').format(message.createdAt), style: TextStyle(color: AurixTokens.muted, fontSize: 10)),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: AurixTokens.orange.withValues(alpha: 0.15),
              child: const Icon(Icons.support_agent_rounded, size: 16, color: AurixTokens.orange),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Debug test ticket button ───

class _CreateTestTicketButton extends ConsumerStatefulWidget {
  const _CreateTestTicketButton({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateTestTicketButton> createState() => _CreateTestTicketButtonState();
}

class _CreateTestTicketButtonState extends ConsumerState<_CreateTestTicketButton> {
  bool _creating = false;

  Future<void> _create() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    setState(() => _creating = true);
    try {
      await ref.read(supportTicketRepositoryProvider).createTicket(
        userId: userId,
        subject: 'Тест #${DateTime.now().millisecondsSinceEpoch % 10000}',
        message: 'Тестовый тикет из debug-режима.',
        priority: 'medium',
      );
      widget.onCreated();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Тестовый тикет создан')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
    if (mounted) setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _creating ? null : _create,
      icon: _creating
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
          : const Icon(Icons.bug_report_rounded, size: 16),
      label: const Text('Тестовый тикет'),
      style: FilledButton.styleFrom(
        backgroundColor: AurixTokens.orange,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
