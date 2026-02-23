import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/models/support_ticket_model.dart';
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

  static const _statuses = ['all', 'open', 'in_progress', 'resolved', 'closed'];

  Color _statusColor(String status) => switch (status) {
        'open' => Colors.amber,
        'in_progress' => Colors.blue,
        'resolved' => AurixTokens.positive,
        'closed' => AurixTokens.muted,
        _ => AurixTokens.muted,
      };

  @override
  Widget build(BuildContext context) {
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
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final t = filtered[i];
                  return _TicketCard(
                    ticket: t,
                    statusColor: _statusColor(t.status),
                    onTap: () => _openTicket(t),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
            error: (e, _) => Center(child: Text('Ошибка: $e', style: TextStyle(color: AurixTokens.muted))),
          ),
        ),
      ],
    );
  }

  void _openTicket(SupportTicketModel ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AurixTokens.bg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _TicketReplySheet(
        ticket: ticket,
        onDone: () => ref.invalidate(allTicketsProvider),
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
        'open' => 'Открытые',
        'in_progress' => 'В работе',
        'resolved' => 'Решённые',
        'closed' => 'Закрытые',
        _ => s,
      };
}

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
      'low' => AurixTokens.muted,
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
                  child: Text(
                    ticket.subject,
                    style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ticket.statusLabel.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ticket.priorityLabel.toUpperCase(),
                    style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ticket.message,
              style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'ID: ${ticket.userId.substring(0, 8)}...',
                  style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontFamily: 'monospace'),
                ),
                const Spacer(),
                Text(
                  DateFormat('dd.MM.yy HH:mm').format(ticket.createdAt),
                  style: const TextStyle(color: AurixTokens.muted, fontSize: 10),
                ),
              ],
            ),
            if (ticket.adminReply != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AurixTokens.positive.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.reply, size: 14, color: AurixTokens.positive),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ticket.adminReply!,
                        style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TicketReplySheet extends ConsumerStatefulWidget {
  const _TicketReplySheet({required this.ticket, required this.onDone});
  final SupportTicketModel ticket;
  final VoidCallback onDone;

  @override
  ConsumerState<_TicketReplySheet> createState() => _TicketReplySheetState();
}

class _TicketReplySheetState extends ConsumerState<_TicketReplySheet> {
  final _replyCtrl = TextEditingController();
  String _newStatus = 'resolved';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _replyCtrl.text = widget.ticket.adminReply ?? '';
    _newStatus = widget.ticket.isResolved ? widget.ticket.status : 'resolved';
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _reply() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final adminId = ref.read(currentUserProvider)?.id;
      await ref.read(supportTicketRepositoryProvider).replyToTicket(
        ticketId: widget.ticket.id,
        adminId: adminId ?? '',
        reply: _replyCtrl.text.trim(),
        status: _newStatus,
      );
      if (adminId != null) {
        await ref.read(adminLogRepositoryProvider).log(
          adminId: adminId,
          action: 'ticket_replied',
          targetType: 'support_ticket',
          targetId: widget.ticket.id,
          details: {'status': _newStatus},
        );
      }
      widget.onDone();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.subject, style: const TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AurixTokens.bg2, borderRadius: BorderRadius.circular(8)),
              child: Text(t.message, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 13, height: 1.5)),
            ),
            const SizedBox(height: 6),
            Text(
              'Приоритет: ${t.priorityLabel} • ${DateFormat("dd.MM.yyyy HH:mm").format(t.createdAt)}',
              style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
            ),
            const SizedBox(height: 20),
            const Text('ОТВЕТ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 8),
            TextField(
              controller: _replyCtrl,
              maxLines: 4,
              style: const TextStyle(color: AurixTokens.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Напишите ответ...',
                hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                filled: true,
                fillColor: AurixTokens.bg2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Статус: ', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _newStatus,
                  dropdownColor: AurixTokens.bg2,
                  style: const TextStyle(color: AurixTokens.text, fontSize: 13),
                  underline: const SizedBox.shrink(),
                  items: ['open', 'in_progress', 'resolved', 'closed']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _newStatus = v ?? _newStatus),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _reply,
                style: FilledButton.styleFrom(
                  backgroundColor: AurixTokens.orange,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Отправить ответ', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
