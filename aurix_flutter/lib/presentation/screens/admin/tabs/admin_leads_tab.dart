import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/presentation/screens/admin/widgets/confirm_dangerous_dialog.dart';
import 'package:aurix_flutter/presentation/screens/admin/widgets/lead_explainer_dialog.dart';

/// Leads tab — sales pipeline (отдельно от CRM-вкладки, которая для deals/promo).
///
/// Источник данных: GET /admin/leads.
/// Действия:
///   - "Связался" → POST /admin/leads/:id/contacted (требует короткий reason)
///   - смена статуса → PATCH /admin/leads/:id (converted/lost требуют confirm+reason)
///   - назначение менеджера → PATCH /admin/leads/:id { assigned_to }
class AdminLeadsTab extends ConsumerStatefulWidget {
  const AdminLeadsTab({super.key});

  @override
  ConsumerState<AdminLeadsTab> createState() => _AdminLeadsTabState();
}

class _AdminLeadsTabState extends ConsumerState<AdminLeadsTab> {
  String? _bucketFilter;
  String? _statusFilter;
  bool _onlyMine = false;

  @override
  Widget build(BuildContext context) {
    final currentIdAsync = ref.watch(adminCurrentIdProvider);
    final myId = currentIdAsync.valueOrNull;
    final filter = LeadsFilter(
      bucket: _bucketFilter,
      status: _statusFilter,
      // "Мои лиды" — отправляем assigned_to=<myId>. Если myId не получили,
      // _onlyMine не активен, чтобы не отправить запрос с null.
      assignedTo: _onlyMine && myId != null ? myId : null,
    );
    final leadsAsync = ref.watch(adminLeadsListProvider(filter));

    return Column(
      children: [
        _FilterBar(
          bucket: _bucketFilter,
          status: _statusFilter,
          onlyMine: _onlyMine,
          canFilterMine: myId != null,
          onBucket: (v) => setState(() => _bucketFilter = v),
          onStatus: (v) => setState(() => _statusFilter = v),
          onMineToggle: () => setState(() => _onlyMine = !_onlyMine),
        ),
        Expanded(
          child: leadsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
            error: (e, _) => Center(
              child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Text('Нет lead\'ов под выбранные фильтры',
                      style: TextStyle(color: AurixTokens.muted)),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminLeadsListProvider(filter)),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) => _LeadCard(
                    lead: items[i],
                    onAction: () => ref.invalidate(adminLeadsListProvider(filter)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.bucket,
    required this.status,
    required this.onlyMine,
    required this.canFilterMine,
    required this.onBucket,
    required this.onStatus,
    required this.onMineToggle,
  });
  final String? bucket;
  final String? status;
  final bool onlyMine;
  final bool canFilterMine;
  final ValueChanged<String?> onBucket;
  final ValueChanged<String?> onStatus;
  final VoidCallback onMineToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.7),
        border: Border(bottom: BorderSide(color: AurixTokens.stroke(0.2))),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _ChipFilter(
            label: 'Все',
            selected: bucket == null && status == null && !onlyMine,
            onTap: () { onBucket(null); onStatus(null); if (onlyMine) onMineToggle(); },
            color: AurixTokens.muted,
          ),
          if (canFilterMine)
            _ChipFilter(
              label: '👤 Мои',
              selected: onlyMine,
              onTap: onMineToggle,
              color: AurixTokens.accent,
            ),
          _ChipFilter(label: 'Hot', selected: bucket == 'hot', onTap: () => onBucket('hot'), color: AurixTokens.danger),
          _ChipFilter(label: 'Warm', selected: bucket == 'warm', onTap: () => onBucket('warm'), color: AurixTokens.orange),
          _ChipFilter(label: 'Cold', selected: bucket == 'cold', onTap: () => onBucket('cold'), color: AurixTokens.muted),
          const SizedBox(width: 16),
          _ChipFilter(label: 'New', selected: status == 'new', onTap: () => onStatus('new'), color: AurixTokens.accent),
          _ChipFilter(label: 'Contacted', selected: status == 'contacted', onTap: () => onStatus('contacted'), color: AurixTokens.aiAccent),
          _ChipFilter(label: 'In progress', selected: status == 'in_progress', onTap: () => onStatus('in_progress'), color: AurixTokens.orange),
          _ChipFilter(label: 'Converted', selected: status == 'converted', onTap: () => onStatus('converted'), color: AurixTokens.positive),
          _ChipFilter(label: 'Lost', selected: status == 'lost', onTap: () => onStatus('lost'), color: AurixTokens.muted),
        ],
      ),
    );
  }
}

class _ChipFilter extends StatelessWidget {
  const _ChipFilter({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.6) : AurixTokens.stroke(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AurixTokens.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LeadCard extends ConsumerStatefulWidget {
  const _LeadCard({required this.lead, required this.onAction});
  final LeadRow lead;
  final VoidCallback onAction;

  @override
  ConsumerState<_LeadCard> createState() => _LeadCardState();
}

class _LeadCardState extends ConsumerState<_LeadCard> {
  bool _busy = false;

  Color get _bucketColor => switch (widget.lead.leadBucket) {
        'hot' => AurixTokens.danger,
        'warm' => AurixTokens.orange,
        _ => AurixTokens.muted,
      };

  Color get _statusColor => switch (widget.lead.status) {
        'new' => AurixTokens.accent,
        'contacted' => AurixTokens.aiAccent,
        'in_progress' => AurixTokens.orange,
        'converted' => AurixTokens.positive,
        _ => AurixTokens.muted,
      };

  Future<void> _markContacted() async {
    final res = await showDangerousActionDialog(
      context,
      title: 'Связались с lead\'ом?',
      description: 'Опишите контакт: чем интересовался, что пообещали, когда следующий шаг.',
      confirmLabel: 'Записать контакт',
      destructiveColor: AurixTokens.aiAccent,
    );
    if (res == null) return;
    setState(() => _busy = true);
    try {
      await ApiClient.post(
        '/admin/leads/${widget.lead.id}/contacted',
        data: {'reason': res['reason']},
      );
      widget.onAction();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: AurixTokens.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(String newStatus) async {
    // converted/lost — финальные состояния, требуют confirm+reason.
    final isFinal = newStatus == 'converted' || newStatus == 'lost';
    Map<String, dynamic>? confirm;
    if (isFinal) {
      confirm = await showDangerousActionDialog(
        context,
        title: 'Изменить статус на $newStatus?',
        description: 'Финальное состояние. Откатить можно только созданием нового lead\'а.',
        confirmLabel: 'Изменить',
        destructiveColor: newStatus == 'converted' ? AurixTokens.positive : AurixTokens.muted,
      );
      if (confirm == null) return;
    }
    setState(() => _busy = true);
    try {
      await ApiClient.dio.patch('/admin/leads/${widget.lead.id}', data: {
        'status': newStatus,
        if (confirm != null) ...confirm,
      });
      widget.onAction();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: AurixTokens.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Открывает диалог выбора менеджера из списка staff.
  Future<void> _assignManager() async {
    final staffAsync = ref.read(adminStaffListProvider.future);
    final staff = await staffAsync;
    if (staff.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Список менеджеров пуст'),
          backgroundColor: AurixTokens.muted,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    final myId = ref.read(adminCurrentIdProvider).valueOrNull;
    if (!mounted) return;
    final selected = await showDialog<int?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Назначить менеджера', style: TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700)),
        children: [
          if (myId != null)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, myId),
              child: Row(children: const [
                Icon(Icons.person_pin_rounded, size: 18, color: AurixTokens.accent),
                SizedBox(width: 8),
                Text('Назначить себя', style: TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w700)),
              ]),
            ),
          Divider(color: AurixTokens.stroke(0.2), height: 1),
          ...staff.map((s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, s.id),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AurixTokens.bg0,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(s.role, style: const TextStyle(color: AurixTokens.muted, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.displayName, style: const TextStyle(color: AurixTokens.text, fontSize: 13))),
                ]),
              )),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, -1), // -1 = снять назначение
            child: const Text('— Снять назначение —', style: TextStyle(color: AurixTokens.muted)),
          ),
        ],
      ),
    );
    if (selected == null) return;

    setState(() => _busy = true);
    try {
      await ApiClient.dio.patch('/admin/leads/${widget.lead.id}', data: {
        'assigned_to': selected == -1 ? null : selected,
        'status': widget.lead.status == 'new' ? 'in_progress' : widget.lead.status,
      });
      widget.onAction();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: AurixTokens.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Объяснить" — открывает Lead Explainer dialog.
  Future<void> _explain() async {
    await showDialog(
      context: context,
      builder: (ctx) => LeadExplainerDialog(leadId: widget.lead.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AurixTokens.bg1.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _bucketColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Tag(label: widget.lead.leadBucket.toUpperCase(), color: _bucketColor),
                const SizedBox(width: 6),
                _Tag(label: widget.lead.status, color: _statusColor),
                const SizedBox(width: 8),
                Text('SCORE ${widget.lead.leadScore}',
                    style: TextStyle(
                      color: _bucketColor, fontSize: 11, fontWeight: FontWeight.w800,
                    )),
                const Spacer(),
                if (widget.lead.assignedTo != null)
                  Consumer(builder: (_, ref, __) {
                    final staffAsync = ref.watch(adminStaffListProvider);
                    final staff = staffAsync.valueOrNull ?? const [];
                    StaffMember? mgr;
                    for (final s in staff) {
                      if (s.id == widget.lead.assignedTo) { mgr = s; break; }
                    }
                    return Text(
                      mgr?.displayName ?? 'admin#${widget.lead.assignedTo}',
                      style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                    );
                  }),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => context.push('/admin/users/${widget.lead.userId}'),
              child: Text(
                widget.lead.email ?? 'user#${widget.lead.userId}',
                style: const TextStyle(
                  color: AurixTokens.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            if (widget.lead.nextAction != null && widget.lead.nextAction!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '→ ${widget.lead.nextAction}',
                style: const TextStyle(
                  color: AurixTokens.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (widget.lead.lastContactAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Последний контакт: ${widget.lead.lastContactAt!.split('T').first}',
                style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniBtn(
                  label: 'Связался',
                  icon: Icons.call_made_rounded,
                  color: AurixTokens.aiAccent,
                  onTap: _busy ? null : _markContacted,
                ),
                _MiniBtn(
                  label: widget.lead.assignedTo != null ? 'Переназначить' : 'Назначить',
                  icon: Icons.assignment_ind_rounded,
                  color: AurixTokens.accent,
                  onTap: _busy ? null : _assignManager,
                ),
                _MiniBtn(
                  label: 'Объяснить',
                  icon: Icons.psychology_rounded,
                  color: AurixTokens.aiAccent,
                  onTap: _busy ? null : _explain,
                ),
                if (widget.lead.status != 'converted')
                  _MiniBtn(
                    label: 'Converted',
                    icon: Icons.check_circle_rounded,
                    color: AurixTokens.positive,
                    onTap: _busy ? null : () => _changeStatus('converted'),
                  ),
                if (widget.lead.status != 'lost')
                  _MiniBtn(
                    label: 'Lost',
                    icon: Icons.cancel_rounded,
                    color: AurixTokens.muted,
                    onTap: _busy ? null : () => _changeStatus('lost'),
                  ),
                _MiniBtn(
                  label: 'Открыть',
                  icon: Icons.person_rounded,
                  color: AurixTokens.muted,
                  onTap: _busy ? null : () => context.push('/admin/users/${widget.lead.userId}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 12),
        label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.85),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}
