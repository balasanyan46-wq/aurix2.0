import 'package:aurix_flutter/data/models/crm_models.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/crm_providers.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

const _crmStages = [
  'new',
  'in_work',
  'need_info',
  'offer_sent',
  'paid',
  'production',
  'done',
  'archived',
];

class AdminCrmTab extends ConsumerStatefulWidget {
  const AdminCrmTab({super.key});

  @override
  ConsumerState<AdminCrmTab> createState() => _AdminCrmTabState();
}

class _AdminCrmTabState extends ConsumerState<AdminCrmTab> {
  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(adminCrmLeadsProvider);
    final dealsAsync = ref.watch(adminCrmDealsProvider);
    final invoicesAsync = ref.watch(adminCrmInvoicesProvider);
    final tasksAsync = ref.watch(adminCrmTasksProvider);
    final profiles =
        ref.watch(allProfilesProvider).valueOrNull ?? const <ProfileModel>[];
    final releases = ref.watch(allReleasesAdminProvider).valueOrNull ??
        const <ReleaseModel>[];

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: PremiumSectionCard(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: PremiumSectionHeader(
                title: 'CRM',
                subtitle: 'Лиды, сделки, задачи и история по артистам.',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AurixTokens.orange,
              labelColor: AurixTokens.orange,
              unselectedLabelColor: AurixTokens.muted,
              tabs: [
                Tab(text: 'Лиды · Канбан'),
                Tab(text: 'Лиды · Таблица'),
                Tab(text: 'Сделки'),
                Tab(text: 'Задачи'),
                Tab(text: 'CRM Profile'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CrmKanbanView(
                  leadsAsync: leadsAsync,
                  profiles: profiles,
                  releases: releases,
                  onOpenLead: (lead) => _openLeadDetails(
                    lead: lead,
                    profiles: profiles,
                    releases: releases,
                    deals: dealsAsync.valueOrNull ?? const [],
                    tasks: tasksAsync.valueOrNull ?? const [],
                    invoices: invoicesAsync.valueOrNull ?? const [],
                  ),
                ),
                _CrmLeadsTableView(
                  leadsAsync: leadsAsync,
                  profiles: profiles,
                  releases: releases,
                  onOpenLead: (lead) => _openLeadDetails(
                    lead: lead,
                    profiles: profiles,
                    releases: releases,
                    deals: dealsAsync.valueOrNull ?? const [],
                    tasks: tasksAsync.valueOrNull ?? const [],
                    invoices: invoicesAsync.valueOrNull ?? const [],
                  ),
                ),
                _CrmDealsView(
                  dealsAsync: dealsAsync,
                  invoicesAsync: invoicesAsync,
                  profiles: profiles,
                  releases: releases,
                ),
                _CrmTasksView(
                  tasksAsync: tasksAsync,
                  profiles: profiles,
                ),
                _CrmProfileView(
                  profiles: profiles,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLeadDetails({
    required CrmLeadModel lead,
    required List<ProfileModel> profiles,
    required List<ReleaseModel> releases,
    required List<CrmDealModel> deals,
    required List<CrmTaskModel> tasks,
    required List<CrmInvoiceModel> invoices,
  }) async {
    final crmRepo = ref.read(crmRepositoryProvider);
    final artist = profiles
        .where((p) => p.userId == lead.userId)
        .cast<ProfileModel?>()
        .firstWhere((x) => x != null, orElse: () => null);
    final userReleases =
        releases.where((r) => r.ownerId == lead.userId).take(5).toList();
    var stage = lead.pipelineStage;
    var priority = lead.priority;
    var assignedTo = lead.assignedTo ?? '';
    DateTime? dueAt = lead.dueAt;
    final titleCtrl = TextEditingController(text: lead.title ?? '');
    final descCtrl = TextEditingController(text: lead.description ?? '');
    final noteCtrl = TextEditingController();
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AurixTokens.bg1,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final notesAsync = ref.watch(crmLeadNotesProvider(lead.id));
            final eventsAsync = ref.watch(crmLeadEventsProvider(lead.id));
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.title ?? 'Лид',
                      style: const TextStyle(
                        color: AurixTokens.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Артист: ${artist?.displayNameOrName ?? lead.userId}',
                      style: const TextStyle(
                          color: AurixTokens.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Источник: ${lead.source}${lead.type == null || lead.type!.isEmpty ? '' : ' · ${lead.type}'}',
                      style: const TextStyle(
                          color: AurixTokens.muted, fontSize: 11),
                    ),
                    if (lead.promoRequestId != null &&
                        lead.promoRequestId!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Связанная promo_request: ${lead.promoRequestId}',
                        style: const TextStyle(
                            color: AurixTokens.muted, fontSize: 11),
                      ),
                    ],
                    if (lead.supportTicketId != null &&
                        lead.supportTicketId!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Связанный support_ticket: ${lead.supportTicketId}',
                        style: const TextStyle(
                            color: AurixTokens.muted, fontSize: 11),
                      ),
                    ],
                    if (lead.productionOrderId != null &&
                        lead.productionOrderId!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Связанный production_order: ${lead.productionOrderId}',
                        style: const TextStyle(
                            color: AurixTokens.muted, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _dropdown(
                      value: stage,
                      values: _crmStages,
                      label: 'Этап воронки',
                      onChanged: (v) => setSheetState(() => stage = v),
                    ),
                    const SizedBox(height: 10),
                    _dropdown(
                      value: priority,
                      values: const ['low', 'normal', 'high'],
                      label: 'Приоритет',
                      onChanged: (v) => setSheetState(() => priority = v),
                    ),
                    const SizedBox(height: 10),
                    _dropdown(
                      value: assignedTo,
                      values: [''] + profiles.map((p) => p.userId).toList(),
                      label: 'Менеджер',
                      labelBuilder: (v) {
                        if (v.isEmpty) return 'Не назначен';
                        final p = profiles
                            .where((x) => x.userId == v)
                            .cast<ProfileModel?>()
                            .firstWhere((x) => x != null, orElse: () => null);
                        return p?.displayNameOrName ?? v;
                      },
                      onChanged: (v) => setSheetState(() => assignedTo = v),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dueAt == null
                                ? 'Дедлайн не задан'
                                : 'Дедлайн: ${DateFormat('dd.MM.yyyy').format(dueAt!)}',
                            style: const TextStyle(
                                color: AurixTokens.muted, fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dueAt ?? DateTime.now(),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 3)),
                            );
                            if (picked != null && context.mounted) {
                              setSheetState(() => dueAt = picked);
                            }
                          },
                          icon: const Icon(Icons.event_rounded),
                          label: const Text('Поставить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: AurixTokens.text),
                      decoration: const InputDecoration(
                        labelText: 'Заголовок',
                        labelStyle: TextStyle(color: AurixTokens.muted),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: AurixTokens.text),
                      decoration: const InputDecoration(
                        labelText: 'Описание',
                        labelStyle: TextStyle(color: AurixTokens.muted),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    setSheetState(() => saving = true);
                                    try {
                                      await crmRepo.updateLead(
                                        leadId: lead.id,
                                        stage: stage,
                                        priority: priority,
                                        assignedTo: assignedTo,
                                        dueAt: dueAt,
                                        title: titleCtrl.text.trim(),
                                        description: descCtrl.text.trim(),
                                      );
                                      ref.invalidate(adminCrmLeadsProvider);
                                      ref.invalidate(
                                          crmLeadEventsProvider(lead.id));
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(this.context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('Лид обновлён')),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(this.context)
                                          .showSnackBar(
                                        SnackBar(content: Text('Ошибка: $e')),
                                      );
                                    } finally {
                                      if (context.mounted) {
                                        setSheetState(() => saving = false);
                                      }
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AurixTokens.orange,
                              foregroundColor: Colors.black,
                            ),
                            icon: const Icon(Icons.save_rounded),
                            label: const Text('Сохранить'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await crmRepo.createDealFromLead(
                                    lead: lead, status: 'draft');
                                ref.invalidate(adminCrmDealsProvider);
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Сделка создана')),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(content: Text('Ошибка: $e')),
                                );
                              }
                            },
                            icon: const Icon(Icons.sell_rounded),
                            label: const Text('Сделка из лида'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _crmArtistProfileCard(
                      artist: artist,
                      releases: userReleases,
                      deals:
                          deals.where((d) => d.userId == lead.userId).toList(),
                      tasks: tasks
                          .where((t) => t.assignedTo == lead.assignedTo)
                          .toList(),
                      invoices:
                          invoices.where((inv) => inv.userId == lead.userId).toList(),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: AurixTokens.text),
                      decoration: const InputDecoration(
                        labelText: 'Новая заметка',
                        labelStyle: TextStyle(color: AurixTokens.muted),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        final uid = ref.read(crmCurrentUserIdProvider);
                        if (uid == null || noteCtrl.text.trim().isEmpty) return;
                        await crmRepo.addNote(
                          userId: lead.userId,
                          authorId: uid,
                          leadId: lead.id,
                          message: noteCtrl.text.trim(),
                        );
                        noteCtrl.clear();
                        ref.invalidate(crmLeadNotesProvider(lead.id));
                        ref.invalidate(crmLeadEventsProvider(lead.id));
                      },
                      child: const Text('Добавить заметку'),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Заметки',
                      style: TextStyle(
                          color: AurixTokens.text, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    notesAsync.when(
                      data: (rows) => rows.isEmpty
                          ? const Text('Нет заметок',
                              style: TextStyle(color: AurixTokens.muted))
                          : Column(
                              children: rows
                                  .map(
                                    (n) => ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        n.message,
                                        style: const TextStyle(
                                            color: AurixTokens.text,
                                            fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        DateFormat('dd.MM HH:mm')
                                            .format(n.createdAt),
                                        style: const TextStyle(
                                            color: AurixTokens.muted,
                                            fontSize: 11),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                      loading: () => const CircularProgressIndicator(
                          color: AurixTokens.orange),
                      error: (e, _) => Text('Ошибка: $e',
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'События',
                      style: TextStyle(
                          color: AurixTokens.text, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    eventsAsync.when(
                      data: (rows) => rows.isEmpty
                          ? const Text('Нет событий',
                              style: TextStyle(color: AurixTokens.muted))
                          : Column(
                              children: rows
                                  .take(10)
                                  .map(
                                    (e) => ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.history_rounded,
                                        size: 16,
                                        color: AurixTokens.muted,
                                      ),
                                      title: Text(
                                        e.eventType,
                                        style: const TextStyle(
                                            color: AurixTokens.text,
                                            fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        DateFormat('dd.MM HH:mm')
                                            .format(e.createdAt),
                                        style: const TextStyle(
                                            color: AurixTokens.muted,
                                            fontSize: 11),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                      loading: () => const CircularProgressIndicator(
                          color: AurixTokens.orange),
                      error: (e, _) => Text('Ошибка: $e',
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> values,
    required String label,
    required void Function(String) onChanged,
    String Function(String)? labelBuilder,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AurixTokens.muted),
      ),
      dropdownColor: AurixTokens.bg1,
      items: values
          .map(
            (v) => DropdownMenuItem<String>(
              value: v,
              child: Text(
                labelBuilder == null ? v : labelBuilder(v),
                style: const TextStyle(color: AurixTokens.text),
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _crmArtistProfileCard({
    required ProfileModel? artist,
    required List<ReleaseModel> releases,
    required List<CrmDealModel> deals,
    required List<CrmTaskModel> tasks,
    required List<CrmInvoiceModel> invoices,
  }) {
    final totalInvoiced = invoices.fold<double>(0, (sum, x) => sum + x.amount);
    final totalPaid = invoices
        .where((x) => x.status == 'paid')
        .fold<double>(0, (sum, x) => sum + x.amount);
    return PremiumSectionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Карточка артиста',
              style: TextStyle(
                  color: AurixTokens.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            artist?.displayNameOrName ?? 'Неизвестный артист',
            style:
                const TextStyle(color: AurixTokens.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniMetric('Релизы', '${releases.length}'),
              _miniMetric('Сделки', '${deals.length}'),
              _miniMetric('Задачи', '${tasks.length}'),
              _miniMetric('Счета', '${invoices.length}'),
              _miniMetric(
                'Оплачено',
                '${totalPaid.toStringAsFixed(0)}/${totalInvoiced.toStringAsFixed(0)}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (releases.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Последние релизы',
                    style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                const SizedBox(height: 4),
                ...releases.take(3).map((r) => Text('• ${r.title}',
                    style: const TextStyle(
                        color: AurixTokens.text, fontSize: 12))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: AurixTokens.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CrmKanbanView extends StatelessWidget {
  const _CrmKanbanView({
    required this.leadsAsync,
    required this.profiles,
    required this.releases,
    required this.onOpenLead,
  });

  final AsyncValue<List<CrmLeadModel>> leadsAsync;
  final List<ProfileModel> profiles;
  final List<ReleaseModel> releases;
  final void Function(CrmLeadModel lead) onOpenLead;

  @override
  Widget build(BuildContext context) {
    return leadsAsync.when(
      data: (leads) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _crmStages.map((stage) {
              final stageLeads =
                  leads.where((l) => l.pipelineStage == stage).toList();
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 10),
                child: PremiumSectionCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _stageLabel(stage),
                              style: const TextStyle(
                                color: AurixTokens.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${stageLeads.length}',
                            style: const TextStyle(
                                color: AurixTokens.muted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (stageLeads.isEmpty)
                        const Text('Пусто',
                            style: TextStyle(
                                color: AurixTokens.muted, fontSize: 12))
                      else
                        ...stageLeads.map((lead) {
                          final profile = profiles
                              .where((p) => p.userId == lead.userId)
                              .cast<ProfileModel?>()
                              .firstWhere((x) => x != null, orElse: () => null);
                          final release = releases
                              .where((r) => r.id == lead.releaseId)
                              .cast<ReleaseModel?>()
                              .firstWhere((x) => x != null, orElse: () => null);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => onOpenLead(lead),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AurixTokens.bg2,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AurixTokens.stroke(0.14)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lead.title ??
                                          _typeLabel(lead.type ?? lead.source),
                                      style: const TextStyle(
                                        color: AurixTokens.text,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      profile?.displayNameOrName ?? lead.userId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AurixTokens.textSecondary,
                                          fontSize: 12),
                                    ),
                                    if (release != null)
                                      Text(
                                        release.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: AurixTokens.muted,
                                            fontSize: 11),
                                      ),
                                    if (lead.dueAt != null)
                                      Text(
                                        'до ${DateFormat('dd.MM').format(lead.dueAt!)}',
                                        style: const TextStyle(
                                            color: Colors.amber, fontSize: 11),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Приоритет: ${lead.priority}',
                                      style: const TextStyle(
                                          color: AurixTokens.muted,
                                          fontSize: 11),
                                    ),
                                    if (lead.assignedTo != null &&
                                        lead.assignedTo!.isNotEmpty)
                                      Text(
                                        'Менеджер назначен',
                                        style: const TextStyle(
                                            color: AurixTokens.muted,
                                            fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AurixTokens.orange)),
      error: (e, _) => Center(
          child: Text('Ошибка: $e',
              style: const TextStyle(color: Colors.redAccent))),
    );
  }
}

class _CrmLeadsTableView extends ConsumerWidget {
  const _CrmLeadsTableView({
    required this.leadsAsync,
    required this.profiles,
    required this.releases,
    required this.onOpenLead,
  });

  final AsyncValue<List<CrmLeadModel>> leadsAsync;
  final List<ProfileModel> profiles;
  final List<ReleaseModel> releases;
  final void Function(CrmLeadModel lead) onOpenLead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(crmLeadStageFilterProvider);
    final assignee = ref.watch(crmLeadAssigneeFilterProvider);
    final source = ref.watch(crmLeadSourceFilterProvider);
    final priority = ref.watch(crmLeadPriorityFilterProvider);
    final search = ref.watch(crmLeadSearchProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          PremiumSectionCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FilterField(
                        value: stage,
                        label: 'Этап',
                        values: ['all', ..._crmStages],
                        onChanged: (v) => ref
                            .read(crmLeadStageFilterProvider.notifier)
                            .state = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FilterField(
                        value: source,
                        label: 'Источник',
                        values: const [
                          'all',
                          'promo',
                          'pitch',
                          'influencer',
                          'ads',
                          'support',
                          'other'
                        ],
                        onChanged: (v) => ref
                            .read(crmLeadSourceFilterProvider.notifier)
                            .state = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FilterField(
                        value: priority,
                        label: 'Приоритет',
                        values: const ['all', 'low', 'normal', 'high'],
                        onChanged: (v) => ref
                            .read(crmLeadPriorityFilterProvider.notifier)
                            .state = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FilterField(
                        value: assignee,
                        label: 'Менеджер',
                        values: ['all', ...profiles.map((p) => p.userId)],
                        labelBuilder: (v) {
                          if (v == 'all') return 'all';
                          final p = profiles
                              .where((x) => x.userId == v)
                              .cast<ProfileModel?>()
                              .firstWhere((x) => x != null, orElse: () => null);
                          return p?.displayNameOrName ?? v;
                        },
                        onChanged: (v) => ref
                            .read(crmLeadAssigneeFilterProvider.notifier)
                            .state = v,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: search),
                  onChanged: (v) =>
                      ref.read(crmLeadSearchProvider.notifier).state = v,
                  style: const TextStyle(color: AurixTokens.text),
                  decoration: const InputDecoration(
                    hintText: 'Поиск по заголовку/описанию/типу',
                    hintStyle: TextStyle(color: AurixTokens.muted),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: AurixTokens.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          leadsAsync.when(
            data: (rows) {
              if (rows.isEmpty) {
                return const PremiumEmptyState(
                  title: 'Лиды не найдены',
                  description: 'Измени фильтры или дождись новых заявок.',
                  icon: Icons.inbox_rounded,
                );
              }
              return PremiumSectionCard(
                child: Column(
                  children: rows.map((lead) {
                    final profile = profiles
                        .where((p) => p.userId == lead.userId)
                        .cast<ProfileModel?>()
                        .firstWhere((x) => x != null, orElse: () => null);
                    final release = releases
                        .where((r) => r.id == lead.releaseId)
                        .cast<ReleaseModel?>()
                        .firstWhere((x) => x != null, orElse: () => null);
                    return ListTile(
                      dense: true,
                      onTap: () => onOpenLead(lead),
                      title: Text(
                        lead.title ?? _typeLabel(lead.type ?? lead.source),
                        style: const TextStyle(
                            color: AurixTokens.text,
                            fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${profile?.displayNameOrName ?? lead.userId}${release == null ? '' : ' · ${release.title}'}',
                        style: const TextStyle(
                            color: AurixTokens.muted, fontSize: 12),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_stageLabel(lead.pipelineStage),
                              style: const TextStyle(
                                  color: AurixTokens.orange, fontSize: 11)),
                          if (lead.dueAt != null)
                            Text(DateFormat('dd.MM').format(lead.dueAt!),
                                style: const TextStyle(
                                    color: Colors.amber, fontSize: 11)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AurixTokens.orange),
            ),
            error: (e, _) => Text('Ошибка: $e',
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _CrmDealsView extends ConsumerWidget {
  const _CrmDealsView({
    required this.dealsAsync,
    required this.invoicesAsync,
    required this.profiles,
    required this.releases,
  });

  final AsyncValue<List<CrmDealModel>> dealsAsync;
  final AsyncValue<List<CrmInvoiceModel>> invoicesAsync;
  final List<ProfileModel> profiles;
  final List<ReleaseModel> releases;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return dealsAsync.when(
      data: (rows) {
        final invoices = invoicesAsync.valueOrNull ?? const <CrmInvoiceModel>[];
        if (rows.isEmpty) {
          return const Center(
            child: PremiumEmptyState(
              title: 'Сделок пока нет',
              description: 'Создай сделку из лида в карточке лида.',
              icon: Icons.sell_rounded,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final d = rows[i];
            final artist = profiles
                .where((p) => p.userId == d.userId)
                .cast<ProfileModel?>()
                .firstWhere((x) => x != null, orElse: () => null);
            final release = releases
                .where((r) => r.id == d.releaseId)
                .cast<ReleaseModel?>()
                .firstWhere((x) => x != null, orElse: () => null);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PremiumSectionCard(
                child: ListTile(
                  onTap: () => _openDealFinance(
                    context: context,
                    ref: ref,
                    deal: d,
                    invoices: invoices.where((x) => x.dealId == d.id).toList(),
                  ),
                  title: Text(d.packageTitle ?? 'Сделка',
                      style: const TextStyle(
                          color: AurixTokens.text,
                          fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${artist?.displayNameOrName ?? d.userId}${release == null ? '' : ' · ${release.title}'}',
                    style:
                        const TextStyle(color: AurixTokens.muted, fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_dealStatusLabel(d.status),
                          style: const TextStyle(
                              color: AurixTokens.orange, fontSize: 11)),
                      if (d.amount != null)
                        Text('${d.amount!.toStringAsFixed(0)} ${d.currency}',
                            style: const TextStyle(
                                color: AurixTokens.textSecondary,
                                fontSize: 11)),
                      Builder(
                        builder: (_) {
                          final dealInvoices =
                              invoices.where((x) => x.dealId == d.id).toList();
                          if (dealInvoices.isEmpty) {
                            return const Text(
                              'Счёт: —',
                              style: TextStyle(
                                  color: AurixTokens.muted, fontSize: 10),
                            );
                          }
                          final paid = dealInvoices
                              .where((x) => x.status == 'paid')
                              .fold<double>(0, (s, x) => s + x.amount);
                          final total = dealInvoices
                              .fold<double>(0, (s, x) => s + x.amount);
                          return Text(
                            'Оплата: ${paid.toStringAsFixed(0)}/${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: AurixTokens.textSecondary, fontSize: 10),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AurixTokens.orange)),
      error: (e, _) => Center(
          child: Text('Ошибка: $e',
              style: const TextStyle(color: Colors.redAccent))),
    );
  }
}

Future<void> _openDealFinance({
  required BuildContext context,
  required WidgetRef ref,
  required CrmDealModel deal,
  required List<CrmInvoiceModel> invoices,
}) async {
  final amountCtrl = TextEditingController(
    text: deal.amount?.toStringAsFixed(0) ?? '',
  );
  final extRefCtrl = TextEditingController();
  DateTime? dueAt;
  var status = 'sent';
  var saving = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AurixTokens.bg1,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Финансы сделки',
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    deal.packageTitle ?? deal.id,
                    style:
                        const TextStyle(color: AurixTokens.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AurixTokens.text),
                    decoration: const InputDecoration(
                      labelText: 'Сумма (RUB)',
                      labelStyle: TextStyle(color: AurixTokens.muted),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Статус счёта',
                      labelStyle: TextStyle(color: AurixTokens.muted),
                    ),
                    dropdownColor: AurixTokens.bg1,
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('draft')),
                      DropdownMenuItem(value: 'sent', child: Text('sent')),
                      DropdownMenuItem(value: 'paid', child: Text('paid')),
                      DropdownMenuItem(value: 'overdue', child: Text('overdue')),
                      DropdownMenuItem(
                          value: 'canceled', child: Text('canceled')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => status = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: extRefCtrl,
                    style: const TextStyle(color: AurixTokens.text),
                    decoration: const InputDecoration(
                      labelText: 'External ref (опционально)',
                      labelStyle: TextStyle(color: AurixTokens.muted),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        dueAt == null
                            ? 'Срок оплаты не задан'
                            : 'Срок: ${DateFormat('dd.MM.yyyy').format(dueAt!)}',
                        style: const TextStyle(
                            color: AurixTokens.muted, fontSize: 12),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 3)),
                          );
                          if (picked != null && context.mounted) {
                            setSheetState(() => dueAt = picked);
                          }
                        },
                        child: const Text('Поставить срок'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final amount =
                                double.tryParse(amountCtrl.text.trim()) ?? 0;
                            if (amount <= 0) return;
                            setSheetState(() => saving = true);
                            try {
                              await ref.read(crmRepositoryProvider).upsertInvoice(
                                    dealId: deal.id,
                                    userId: deal.userId,
                                    amount: amount,
                                    status: status,
                                    dueAt: dueAt,
                                    paidAt: status == 'paid' ? DateTime.now() : null,
                                    externalRef: extRefCtrl.text.trim().isEmpty
                                        ? null
                                        : extRefCtrl.text.trim(),
                                  );
                              ref.invalidate(adminCrmInvoicesProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Счёт сохранён')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Ошибка: $e')),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setSheetState(() => saving = false);
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AurixTokens.orange,
                      foregroundColor: Colors.black,
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text('Создать / обновить счёт'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'История счетов',
                    style: TextStyle(
                      color: AurixTokens.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (invoices.isEmpty)
                    const Text(
                      'Счета пока не создавались',
                      style: TextStyle(color: AurixTokens.muted, fontSize: 12),
                    )
                  else
                    ...invoices.map((inv) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${inv.amount.toStringAsFixed(0)} ${inv.currency} · ${inv.status}',
                            style: const TextStyle(
                              color: AurixTokens.text,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('dd.MM.yyyy HH:mm').format(inv.createdAt),
                            style: const TextStyle(
                                color: AurixTokens.muted, fontSize: 11),
                          ),
                        )),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _CrmTasksView extends ConsumerStatefulWidget {
  const _CrmTasksView({
    required this.tasksAsync,
    required this.profiles,
  });

  final AsyncValue<List<CrmTaskModel>> tasksAsync;
  final List<ProfileModel> profiles;

  @override
  ConsumerState<_CrmTasksView> createState() => _CrmTasksViewState();
}

class _CrmTasksViewState extends ConsumerState<_CrmTasksView> {
  String _scope = 'overdue';

  @override
  Widget build(BuildContext context) {
    return widget.tasksAsync.when(
      data: (rows) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final weekEnd = today.add(const Duration(days: 7));
        final filtered = rows.where((t) {
          if (t.dueAt == null) return _scope == 'week';
          final due = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
          switch (_scope) {
            case 'today':
              return due == today;
            case 'week':
              return !due.isBefore(today) && !due.isAfter(weekEnd);
            default:
              return due.isBefore(today);
          }
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                    label: const Text('Просрочено'),
                    selected: _scope == 'overdue',
                    onSelected: (_) => setState(() => _scope = 'overdue')),
                ChoiceChip(
                    label: const Text('На сегодня'),
                    selected: _scope == 'today',
                    onSelected: (_) => setState(() => _scope = 'today')),
                ChoiceChip(
                    label: const Text('На неделю'),
                    selected: _scope == 'week',
                    onSelected: (_) => setState(() => _scope = 'week')),
              ],
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              const PremiumEmptyState(
                title: 'Задачи не найдены',
                description: 'По выбранному фильтру нет задач.',
                icon: Icons.task_alt_rounded,
              )
            else
              ...filtered.map((t) {
                final assignee = widget.profiles
                    .where((p) => p.userId == t.assignedTo)
                    .cast<ProfileModel?>()
                    .firstWhere((x) => x != null, orElse: () => null);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PremiumSectionCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  style: const TextStyle(
                                      color: AurixTokens.text,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(
                                'Менеджер: ${assignee?.displayNameOrName ?? (t.assignedTo ?? '—')}',
                                style: const TextStyle(
                                    color: AurixTokens.muted, fontSize: 12),
                              ),
                              if (t.dueAt != null)
                                Text(
                                  'Дедлайн: ${DateFormat('dd.MM.yyyy').format(t.dueAt!)}',
                                  style: const TextStyle(
                                      color: Colors.amber, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        Checkbox(
                          value: t.status == 'done',
                          onChanged: (v) async {
                            await ref.read(crmRepositoryProvider).setTaskStatus(
                                  taskId: t.id,
                                  status: v == true ? 'done' : 'open',
                                );
                            ref.invalidate(adminCrmTasksProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AurixTokens.orange)),
      error: (e, _) => Center(
          child: Text('Ошибка: $e',
              style: const TextStyle(color: Colors.redAccent))),
    );
  }
}

class _CrmProfileView extends ConsumerStatefulWidget {
  const _CrmProfileView({
    required this.profiles,
  });

  final List<ProfileModel> profiles;

  @override
  ConsumerState<_CrmProfileView> createState() => _CrmProfileViewState();
}

class _CrmProfileViewState extends ConsumerState<_CrmProfileView> {
  String _selectedUserId = '';

  @override
  Widget build(BuildContext context) {
    final options = widget.profiles.map((p) => p.userId).toList();
    if (_selectedUserId.isEmpty && options.isNotEmpty) {
      _selectedUserId = options.first;
    }
    final snapshotAsync = _selectedUserId.isEmpty
        ? const AsyncValue<CrmArtistProfileSnapshot?>.data(null)
        : ref.watch(crmArtistSnapshotProvider(_selectedUserId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PremiumSectionCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Карточка артиста (CRM Profile)',
                style: TextStyle(
                  color: AurixTokens.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (options.isEmpty)
                const Text(
                  'Нет пользователей',
                  style: TextStyle(color: AurixTokens.muted),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedUserId,
                  decoration: const InputDecoration(
                    labelText: 'Артист',
                    labelStyle: TextStyle(color: AurixTokens.muted),
                  ),
                  dropdownColor: AurixTokens.bg1,
                  items: options
                      .map((id) => DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              widget.profiles
                                      .firstWhere((p) => p.userId == id)
                                      .displayNameOrName +
                                  ' · $id',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AurixTokens.text,
                                fontSize: 12,
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedUserId = v);
                    }
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        snapshotAsync.when(
          data: (snap) {
            if (snap == null) {
              return const SizedBox.shrink();
            }
            return Column(
              children: [
                PremiumSectionCard(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _metric('Лиды', '${snap.leads.length}'),
                      _metric('Сделки', '${snap.deals.length}'),
                      _metric('Задачи', '${snap.tasks.length}'),
                      _metric('Счета', '${snap.invoices.length}'),
                      _metric('Оплачено', '${snap.totalPaid.toStringAsFixed(0)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PremiumSectionCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Последние события',
                        style: TextStyle(
                          color: AurixTokens.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (snap.events.isEmpty)
                        const Text(
                          'Нет событий',
                          style: TextStyle(color: AurixTokens.muted),
                        )
                      else
                        ...snap.events.take(10).map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${DateFormat('dd.MM HH:mm').format(e.createdAt)} · ${e.eventType}',
                                  style: const TextStyle(
                                    color: AurixTokens.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AurixTokens.orange),
          ),
          error: (e, _) => Text(
            'Ошибка CRM Profile: $e',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
          Text(
            value,
            style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
    this.labelBuilder,
  });

  final String value;
  final List<String> values;
  final String label;
  final void Function(String) onChanged;
  final String Function(String)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AurixTokens.muted),
      ),
      dropdownColor: AurixTokens.bg1,
      items: values
          .map(
            (v) => DropdownMenuItem(
              value: v,
              child: Text(
                labelBuilder == null ? v : labelBuilder!(v),
                style: const TextStyle(color: AurixTokens.text, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

String _stageLabel(String stage) => switch (stage) {
      'new' => 'Новые',
      'in_work' => 'В работе',
      'need_info' => 'Нужны данные',
      'offer_sent' => 'Оффер отправлен',
      'paid' => 'Оплачено',
      'production' => 'Продакшн',
      'done' => 'Завершено',
      'archived' => 'Архив',
      _ => stage,
    };

String _dealStatusLabel(String status) => switch (status) {
      'draft' => 'Черновик',
      'active' => 'Активна',
      'completed' => 'Завершена',
      'canceled' => 'Отменена',
      _ => status,
    };

String _typeLabel(String type) => switch (type) {
      'dsp_pitch' => 'DSP Pitch',
      'aurix_pitch' => 'Aurix Pitch',
      'influencer' => 'Influencer',
      'ads' => 'Ads',
      _ => type,
    };
