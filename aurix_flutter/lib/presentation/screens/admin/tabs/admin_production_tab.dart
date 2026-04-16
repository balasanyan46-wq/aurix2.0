import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/crm_providers.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/production/data/production_models.dart';

class AdminProductionTab extends ConsumerStatefulWidget {
  const AdminProductionTab({super.key});

  @override
  ConsumerState<AdminProductionTab> createState() => _AdminProductionTabState();
}

class _AdminProductionTabState extends ConsumerState<AdminProductionTab> with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(length: 3, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AurixTokens.bg1,
          child: TabBar(
            controller: _tc,
            isScrollable: true,
            labelColor: AurixTokens.accent,
            unselectedLabelColor: AurixTokens.muted,
            tabs: const [
              Tab(text: 'Каталог услуг'),
              Tab(text: 'Заказы'),
              Tab(text: 'Исполнители'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tc,
            children: const [
              _CatalogTab(),
              _OrdersTab(),
              _AssigneesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogTab extends ConsumerWidget {
  const _CatalogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.watch(_catalogProvider);
    return future.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AurixTokens.negative))),
      data: (items) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _showServiceDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Добавить услугу'),
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((s) => ListTile(
                title: Text(s.title, style: const TextStyle(color: AurixTokens.text)),
                subtitle: Text('${s.category} • SLA: ${s.slaDays ?? '-'} дн', style: const TextStyle(color: AurixTokens.muted)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: AurixTokens.accent),
                  onPressed: () => _showServiceDialog(context, ref, s),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _showServiceDialog(BuildContext context, WidgetRef ref, [ProductionServiceCatalog? s]) async {
    final title = TextEditingController(text: s?.title ?? '');
    final desc = TextEditingController(text: s?.description ?? '');
    final sla = TextEditingController(text: s?.slaDays?.toString() ?? '');
    var category = s?.category ?? 'other';
    var active = s?.isActive ?? true;
    String? error;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AurixTokens.bg1,
          title: Text(s == null ? 'Новая услуга' : 'Редактирование', style: const TextStyle(color: AurixTokens.text)),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 8),
                TextField(controller: desc, decoration: const InputDecoration(labelText: 'Описание')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: category,
                  items: const [
                    DropdownMenuItem(value: 'music', child: Text('Музыка')),
                    DropdownMenuItem(value: 'visual', child: Text('Визуал')),
                    DropdownMenuItem(value: 'promo', child: Text('Промо')),
                    DropdownMenuItem(value: 'other', child: Text('Прочее')),
                  ],
                  onChanged: (v) => setDialogState(() => category = v ?? 'other'),
                  decoration: const InputDecoration(labelText: 'Категория'),
                ),
                const SizedBox(height: 8),
                TextField(controller: sla, decoration: const InputDecoration(labelText: 'SLA (дней)')),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: AurixTokens.negative)),
                  ),
                SwitchListTile(
                  value: active,
                  onChanged: (v) => setDialogState(() => active = v),
                  title: const Text('Активна'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) {
                  setDialogState(() => error = 'Укажи название услуги');
                  return;
                }
                try {
                  final service = ref.read(productionServiceProvider);
                  await service.upsertService(ProductionServiceCatalog(
                    id: s?.id ?? '',
                    title: title.text.trim(),
                    description: desc.text.trim(),
                    category: category,
                    defaultPrice: s?.defaultPrice,
                    slaDays: int.tryParse(sla.text.trim()),
                    requiredInputs: s?.requiredInputs ?? const {},
                    deliverables: s?.deliverables ?? const {},
                    isActive: active,
                  ));
                  ref.invalidate(_catalogProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  setDialogState(() => error = _shortError(e));
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends ConsumerStatefulWidget {
  const _OrdersTab();

  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final ordersAsync = ref.watch(_ordersProvider);
    final profilesAsync = ref.watch(allProfilesProvider);
    final assigneesAsync = ref.watch(_assigneesProvider);
    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AurixTokens.negative))),
      data: (data) => profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка профилей: $e', style: const TextStyle(color: AurixTokens.negative, fontSize: 12))),
        data: (profiles) {
          final profileName = {for (final p in profiles) p.id: (p.name?.isNotEmpty == true ? p.name! : p.email)};
          final orders = data.$1;
          final items = data.$2;
          final q = _searchCtrl.text.trim().toLowerCase();
          return assigneesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Ошибка исполнителей: $e', style: const TextStyle(color: AurixTokens.negative, fontSize: 12))),
            data: (assignees) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryCards(orders, items),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _showCreateOrderDialog(context, ref, profiles),
                    icon: const Icon(Icons.add),
                    label: const Text('Создать заказ'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Поиск: артист, услуга, статус, название заказа',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip('Все', 'all'),
                    _statusChip('Не начато', 'not_started'),
                    _statusChip('Ожидает артиста', 'waiting_artist'),
                    _statusChip('В работе', 'in_progress'),
                    _statusChip('На проверке', 'review'),
                    _statusChip('Готово', 'done'),
                    _statusChip('Отменено', 'canceled'),
                  ],
                ),
                const SizedBox(height: 10),
                ...orders.map((o) {
                  final orderItems = items.where((i) => i.orderId == o.id).toList();
                  final byStatus = (_statusFilter == 'all')
                      ? orderItems
                      : orderItems.where((i) => i.status == _statusFilter).toList();
                  final visibleItems = q.isEmpty
                      ? byStatus
                      : byStatus.where((i) {
                          final artist = (profileName[o.userId] ?? o.userId).toLowerCase();
                          final serviceTitle = (i.service?.title ?? '').toLowerCase();
                          final statusTitle = productionStatusLabel(i.status).toLowerCase();
                          final orderTitle = o.title.toLowerCase();
                          return artist.contains(q) ||
                              serviceTitle.contains(q) ||
                              statusTitle.contains(q) ||
                              orderTitle.contains(q);
                        }).toList();
                  if (visibleItems.isEmpty && (q.isNotEmpty || _statusFilter != 'all')) {
                    return const SizedBox.shrink();
                  }
                  return ExpansionTile(
                    title: Text(o.title.isNotEmpty ? o.title : 'Процесс', style: const TextStyle(color: AurixTokens.text)),
                    subtitle: Text(
                      'Артист: ${profileName[o.userId] ?? o.userId} • услуг: ${orderItems.length}',
                      style: const TextStyle(color: AurixTokens.muted),
                    ),
                    children: visibleItems
                        .map((i) => _AdminItemTile(item: i, assignees: assignees, onChanged: () => ref.invalidate(_ordersProvider)))
                        .toList(),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateOrderDialog(BuildContext context, WidgetRef ref, List<dynamic> profiles) async {
    final title = TextEditingController();
    String? selectedUser;
    final selectedServices = <String>{};
    final catalog = await ref.read(productionServiceProvider).getCatalog();
    if (!context.mounted) return;
    bool submitting = false;
    String? error;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AurixTokens.bg1,
          title: const Text('Создать заказ', style: TextStyle(color: AurixTokens.text)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedUser,
                    decoration: const InputDecoration(labelText: 'Артист'),
                    items: profiles
                        .map((p) => DropdownMenuItem<String>(
                              value: p.id.toString(),
                              child: Text((p.name?.isNotEmpty == true) ? p.name! : p.email),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedUser = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Название процесса')),
                  const SizedBox(height: 10),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(error!, style: const TextStyle(color: AurixTokens.negative)),
                    ),
                  ...catalog.map((s) => CheckboxListTile(
                        value: selectedServices.contains(s.id),
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              selectedServices.add(s.id);
                            } else {
                              selectedServices.remove(s.id);
                            }
                          });
                        },
                        title: Text(s.title),
                      )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(context), child: const Text('Отмена')),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (selectedUser == null) {
                        setDialogState(() => error = 'Выберите артиста');
                        return;
                      }
                      if (selectedServices.isEmpty) {
                        setDialogState(() => error = 'Выберите хотя бы одну услугу');
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        final orderTitle = title.text.trim().isEmpty ? 'Новый продакшн-процесс' : title.text.trim();
                        await ref.read(productionServiceProvider).createOrder(
                              userId: selectedUser!,
                              title: orderTitle,
                              serviceIds: selectedServices.toList(),
                            );
                        ref.invalidate(_ordersProvider);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() => error = _shortError(e));
                      } finally {
                        setDialogState(() => submitting = false);
                      }
                    },
              child: submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String title, String value) => ChoiceChip(
        label: Text(title),
        selected: _statusFilter == value,
        onSelected: (_) => setState(() => _statusFilter = value),
      );

  Widget _summaryCards(List<ProductionOrder> orders, List<ProductionOrderItem> items) {
    final now = DateTime.now();
    final waiting = items.where((e) => e.status == 'waiting_artist').length;
    final inProgress = items.where((e) => e.status == 'in_progress' || e.status == 'review').length;
    final done = items.where((e) => e.status == 'done').length;
    final overdue = items.where((e) {
      if (e.deadlineAt == null) return false;
      if (e.status == 'done' || e.status == 'canceled') return false;
      return e.deadlineAt!.isBefore(now);
    }).length;
    final riskSoon = items.where((e) {
      if (e.deadlineAt == null) return false;
      if (e.status == 'done' || e.status == 'canceled') return false;
      final diff = e.deadlineAt!.difference(now).inHours;
      return diff >= 0 && diff <= 48;
    }).length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(label: 'Заказы', value: '${orders.length}'),
        _StatChip(label: 'В работе', value: '$inProgress'),
        _StatChip(label: 'Ждут артиста', value: '$waiting'),
        _StatChip(label: 'SLA риск', value: '$riskSoon'),
        _StatChip(label: 'SLA overdue', value: '$overdue'),
        _StatChip(label: 'Готово', value: '$done'),
      ],
    );
  }
}

class _AdminItemTile extends ConsumerStatefulWidget {
  final ProductionOrderItem item;
  final List<ProductionAssignee> assignees;
  final VoidCallback onChanged;

  const _AdminItemTile({
    required this.item,
    required this.assignees,
    required this.onChanged,
  });

  @override
  ConsumerState<_AdminItemTile> createState() => _AdminItemTileState();
}

class _AdminItemTileState extends ConsumerState<_AdminItemTile> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return ListTile(
      title: Text(item.service?.title ?? 'Услуга', style: const TextStyle(color: AurixTokens.text)),
      subtitle: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<String>(
            value: const ['not_started', 'waiting_artist', 'in_progress', 'review', 'done', 'canceled'].contains(item.status)
                ? item.status
                : 'not_started',
            items: const [
              DropdownMenuItem(value: 'not_started', child: Text('Не начато')),
              DropdownMenuItem(value: 'waiting_artist', child: Text('Ожидает артиста')),
              DropdownMenuItem(value: 'in_progress', child: Text('В работе')),
              DropdownMenuItem(value: 'review', child: Text('На проверке')),
              DropdownMenuItem(value: 'done', child: Text('Готово')),
              DropdownMenuItem(value: 'canceled', child: Text('Отменено')),
            ],
            onChanged: _saving
                ? null
                : (v) async {
                    if (v == null) return;
                    await _safeCall(() async {
                      await ref.read(productionServiceProvider).updateItem(itemId: item.id, status: v);
                    });
                  },
          ),
          DropdownButton<String?>(
            value: widget.assignees.any((a) => a.id == item.assigneeId) ? item.assigneeId : null,
            hint: const Text('Исполнитель'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Не назначен')),
              ...widget.assignees.map((a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.fullName))),
            ],
            onChanged: _saving
                ? null
                : (v) async {
                    await _safeCall(() async {
                      await ref.read(productionServiceProvider).updateItem(itemId: item.id, assigneeId: v ?? '');
                    });
                  },
          ),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    final now = DateTime.now();
                    final initial = item.deadlineAt ?? now.add(const Duration(days: 7));
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: now.subtract(const Duration(days: 365)),
                      lastDate: now.add(const Duration(days: 365 * 3)),
                      initialDate: initial,
                    );
                    if (picked == null) return;
                    await _safeCall(() async {
                      await ref.read(productionServiceProvider).updateItem(itemId: item.id, deadlineAt: picked);
                    });
                  },
            icon: const Icon(Icons.event_rounded, size: 16),
            label: Text(item.deadlineAt == null
                ? 'Дедлайн'
                : 'До ${item.deadlineAt!.day.toString().padLeft(2, '0')}.${item.deadlineAt!.month.toString().padLeft(2, '0')}'),
          ),
        ],
      ),
      trailing: _saving
          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
    );
  }

  Future<void> _safeCall(Future<void> Function() fn) async {
    setState(() => _saving = true);
    try {
      await fn();
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_shortError(e)), backgroundColor: AurixTokens.negative),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AssigneesTab extends ConsumerWidget {
  const _AssigneesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_assigneesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AurixTokens.negative))),
      data: (assignees) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _showAssigneeDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Добавить исполнителя'),
            ),
          ),
          ...assignees.map((a) => ListTile(
                title: Text(a.fullName, style: const TextStyle(color: AurixTokens.text)),
                subtitle: Text(a.specialization, style: const TextStyle(color: AurixTokens.muted)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: AurixTokens.accent),
                  onPressed: () => _showAssigneeDialog(context, ref, a),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _showAssigneeDialog(BuildContext context, WidgetRef ref, [ProductionAssignee? a]) async {
    final name = TextEditingController(text: a?.fullName ?? '');
    final role = TextEditingController(text: a?.specialization ?? '');
    final contact = TextEditingController(text: a?.contacts ?? '');
    var active = a?.isActive ?? true;
    String? error;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AurixTokens.bg1,
          title: Text(a == null ? 'Новый исполнитель' : 'Редактирование', style: const TextStyle(color: AurixTokens.text)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Имя')),
                const SizedBox(height: 8),
                TextField(controller: role, decoration: const InputDecoration(labelText: 'Специализация')),
                const SizedBox(height: 8),
                TextField(controller: contact, decoration: const InputDecoration(labelText: 'Контакты')),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: AurixTokens.negative)),
                  ),
                SwitchListTile(
                  value: active,
                  onChanged: (v) => setDialogState(() => active = v),
                  title: const Text('Активен'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  setDialogState(() => error = 'Укажи имя исполнителя');
                  return;
                }
                try {
                  await ref.read(productionServiceProvider).upsertAssignee(ProductionAssignee(
                        id: a?.id ?? '',
                        userId: a?.userId,
                        fullName: name.text.trim(),
                        specialization: role.text.trim(),
                        contacts: contact.text.trim(),
                        isActive: active,
                      ));
                  ref.invalidate(_assigneesProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  setDialogState(() => error = _shortError(e));
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        border: Border.all(color: AurixTokens.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AurixTokens.muted)),
        ],
      ),
    );
  }
}

final adminProductionCatalogProvider = FutureProvider<List<ProductionServiceCatalog>>((ref) {
  return ref.read(productionServiceProvider).getCatalog(includeInactive: true);
});

final adminProductionAssigneesProvider = FutureProvider<List<ProductionAssignee>>((ref) {
  return ref.read(productionServiceProvider).getAssignees(includeInactive: true);
});

final adminProductionOrdersProvider = FutureProvider<(List<ProductionOrder>, List<ProductionOrderItem>)>((ref) async {
  final service = ref.read(productionServiceProvider);
  final orders = await service.getAllOrders();
  final items = await service.getItemsForOrders(orders.map((e) => e.id).toList());
  return (orders, items);
});

final _catalogProvider = adminProductionCatalogProvider;
final _assigneesProvider = adminProductionAssigneesProvider;
final _ordersProvider = adminProductionOrdersProvider;

String _shortError(Object e) {
  final msg = e.toString().replaceAll('Exception: ', '').trim();
  if (msg.contains('row-level security') || msg.contains('permission denied')) {
    return 'Нет доступа для этого действия (RLS).';
  }
  if (msg.contains('duplicate key')) {
    return 'Такая запись уже существует.';
  }
  if (msg.length > 140) return '${msg.substring(0, 140)}...';
  return msg.isEmpty ? 'Не удалось выполнить действие' : msg;
}
