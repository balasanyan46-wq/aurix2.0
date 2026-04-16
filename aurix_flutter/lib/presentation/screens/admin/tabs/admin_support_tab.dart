import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/models/support_ticket_model.dart';
import 'package:aurix_flutter/data/models/support_message_model.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/crm_providers.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/presentation/screens/admin/admin_user_detail_screen.dart';

String _userNameById(dynamic profiles, String id) {
  if (profiles is! List) return 'User #$id';
  for (final p in profiles) {
    if (p.userId == id) {
      return p.displayNameOrName ?? p.email ?? 'User #$id';
    }
  }
  return 'User #$id';
}

class AdminSupportTab extends ConsumerStatefulWidget {
  const AdminSupportTab({super.key});

  @override
  ConsumerState<AdminSupportTab> createState() => _AdminSupportTabState();
}

class _AdminSupportTabState extends ConsumerState<AdminSupportTab> {
  String _statusFilter = 'all';
  String _search = '';
  SupportTicketModel? _openedTicket;

  static const _statuses = ['all', 'open', 'in_progress', 'resolved', 'closed'];

  Color _statusColor(String status) => switch (status) {
        'open' => AurixTokens.warning,
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
    final profiles = ref.watch(allProfilesProvider).valueOrNull ?? [];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: AurixTokens.bg1,
          child: Column(
            children: [
              TextField(
                style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Поиск по теме, сообщению, user id',
                  hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AurixTokens.muted),
                  filled: true,
                  fillColor: AurixTokens.bg2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
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
            ],
          ),
        ),
        Expanded(
          child: ticketsAsync.when(
            data: (tickets) {
              var filtered = _statusFilter == 'all'
                  ? tickets
                  : tickets.where((t) => t.status == _statusFilter).toList();

              if (_search.isNotEmpty) {
                filtered = filtered.where((t) {
                  final subject = t.subject.toLowerCase();
                  final message = t.message.toLowerCase();
                  final uid = t.userId.toLowerCase();
                  return subject.contains(_search) || message.contains(_search) || uid.contains(_search);
                }).toList();
              }

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
                        userName: _userNameById(profiles, t.userId),
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
                    Icon(Icons.error_outline_rounded, size: 40, color: AurixTokens.danger.withValues(alpha: 0.6)),
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
  const _TicketCard({required this.ticket, required this.statusColor, required this.onTap, required this.userName});
  final SupportTicketModel ticket;
  final Color statusColor;
  final VoidCallback onTap;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (ticket.priority) {
      'high' => AurixTokens.danger,
      'medium' => AurixTokens.warning,
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
                Icon(Icons.person_rounded, size: 12, color: AurixTokens.muted),
                const SizedBox(width: 4),
                Text(userName, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 11)),
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
  bool _notifyingEmail = false;

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
      await ref.read(adminLogRepositoryProvider).log(
        adminId: adminId,
        action: 'ticket_replied',
        targetType: 'support_ticket',
        targetId: widget.ticket.id,
        details: {'message_len': body.length},
      );
      if (widget.ticket.status == 'open') {
        await ref.read(supportTicketRepositoryProvider).updateStatus(widget.ticket.id, 'in_progress');
      }
      ref.invalidate(adminCrmLeadsProvider);
      await _loadMessages();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _changeStatus(String status) async {
    final reason = await _askReasonForStatus(status);
    if (reason == null) return;
    try {
      await ref.read(supportTicketRepositoryProvider).updateStatus(widget.ticket.id, status);
      final adminId = ref.read(currentUserProvider)?.id;
      if (adminId != null) {
        await ref.read(adminLogRepositoryProvider).log(
          adminId: adminId,
          action: 'ticket_status_changed',
          targetType: 'support_ticket',
          targetId: widget.ticket.id,
          details: {'status': status, 'reason': reason},
        );
      }
      ref.invalidate(adminCrmLeadsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Статус: $status')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _notifyByEmail() async {
    final lastAdminMsg = _messages.lastWhere(
      (m) => m.isAdmin,
      orElse: () => _messages.last,
    );

    setState(() => _notifyingEmail = true);
    try {
      await ApiClient.post('/support-tickets/${widget.ticket.id}/notify-email', data: {
        'message_text': lastAdminMsg.body,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email-уведомление отправлено'), backgroundColor: AurixTokens.positive),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки email: $e'), backgroundColor: AurixTokens.danger),
        );
      }
    }
    if (mounted) setState(() => _notifyingEmail = false);
  }

  Future<String?> _askReasonForStatus(String nextStatus) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: Text('Изменить статус на "$nextStatus"', style: const TextStyle(color: AurixTokens.text)),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          style: const TextStyle(color: AurixTokens.text),
          decoration: const InputDecoration(
            hintText: 'Причина',
            hintStyle: TextStyle(color: AurixTokens.muted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Применить')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    if (ok != true || text.isEmpty) return null;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(allProfilesProvider).valueOrNull ?? [];
    // Find profile for this ticket's user
    final userProfile = profiles.cast<dynamic>().where((p) => p.userId == widget.ticket.userId).firstOrNull;
    final userName = userProfile?.displayNameOrName ?? 'User #${widget.ticket.userId}';
    final userEmail = userProfile?.email as String?;
    final userPlan = userProfile?.planId as String?;

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
                    Text(userName, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 11)),
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
        // User info card
        _UserInfoCard(
          userId: widget.ticket.userId,
          userName: userName,
          email: userEmail,
          plan: userPlan,
          ticketCreatedAt: widget.ticket.createdAt,
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
                        return _AdminMessageBubble(
                          message: msg,
                          isMe: msg.isAdmin,
                          senderLabel: msg.isAdmin ? 'Вы (поддержка)' : userName,
                        );
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
              const SizedBox(width: 4),
              _sending
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange)))
                  : IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded, color: AurixTokens.orange)),
              _notifyingEmail
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue)))
                  : IconButton(
                      onPressed: _messages.any((m) => m.isAdmin) ? _notifyByEmail : null,
                      icon: const Icon(Icons.email_outlined, size: 20),
                      color: Colors.blue,
                      tooltip: 'Оповестить на почту',
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── User info card (shown at top of admin chat) ───

class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({
    required this.userId,
    required this.userName,
    this.email,
    this.plan,
    required this.ticketCreatedAt,
  });
  final String userId;
  final String userName;
  final String? email;
  final String? plan;
  final DateTime ticketCreatedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AurixTokens.bg2.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: AurixTokens.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AurixTokens.accent.withValues(alpha: 0.15),
            child: const Icon(Icons.person_rounded, size: 20, color: AurixTokens.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 13)),
                Row(
                  children: [
                    if (email != null) ...[
                      Flexible(
                        child: Text(email!, style: const TextStyle(color: AurixTokens.muted, fontSize: 11), overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (plan != null && plan!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AurixTokens.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(plan!.toUpperCase(), style: TextStyle(color: AurixTokens.accent, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(width: 8),
                    Text('ID: $userId', style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AdminUserDetailScreen(
                    userId: int.tryParse(userId) ?? 0,
                    userName: userName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 14),
            label: const Text('Профиль'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AurixTokens.accent,
              side: BorderSide(color: AurixTokens.accent.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message bubble for admin chat ───

class _AdminMessageBubble extends StatelessWidget {
  const _AdminMessageBubble({required this.message, required this.isMe, required this.senderLabel});
  final SupportMessageModel message;
  final bool isMe;
  final String senderLabel;

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
              backgroundColor: AurixTokens.coolUndertone.withValues(alpha: 0.15),
              child: const Icon(Icons.person, size: 16, color: AurixTokens.coolUndertone),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AurixTokens.orange.withValues(alpha: 0.12) : AurixTokens.bg2,
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      senderLabel,
                      style: TextStyle(
                        color: isMe ? AurixTokens.orange : AurixTokens.coolUndertone,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
