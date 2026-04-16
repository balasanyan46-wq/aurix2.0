import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/core/api/api_client.dart';

/// Admin tab for managing release service prices.
class AdminServicesTab extends ConsumerStatefulWidget {
  const AdminServicesTab({super.key});

  @override
  ConsumerState<AdminServicesTab> createState() => _AdminServicesTabState();
}

class _AdminServicesTabState extends ConsumerState<AdminServicesTab> {
  List<_ServiceRow> _services = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.get('/system/service-prices');
      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final list = data['services'] as List? ?? [];
      if (mounted) {
        setState(() {
          _services = list.map((j) {
            final m = j is Map<String, dynamic> ? j : Map<String, dynamic>.from(j as Map);
            return _ServiceRow.fromJson(m);
          }).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _saveService(_ServiceRow s) async {
    setState(() => _saving = true);
    try {
      await ApiClient.put('/system/service-prices/${s.id}', data: {
        'name': s.nameCtrl.text.trim(),
        'description': s.descCtrl.text.trim(),
        'price': double.tryParse(s.priceCtrl.text.trim()) ?? 0,
        'step': int.tryParse(s.stepCtrl.text.trim()) ?? 0,
        'enabled': s.enabled,
        'sort_order': int.tryParse(s.sortCtrl.text.trim()) ?? 0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.nameCtrl.text} — сохранено'), backgroundColor: AurixTokens.positive),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteService(_ServiceRow s) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AurixTokens.bg1,
      title: const Text('Удалить услугу?', style: TextStyle(color: AurixTokens.text)),
      content: Text('Удалить "${s.nameCtrl.text}"?', style: const TextStyle(color: AurixTokens.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Удалить', style: TextStyle(color: AurixTokens.danger))),
      ],
    ));
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/system/service-prices/${s.id}');
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _addService() async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');

    final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AurixTokens.bg1,
      title: const Text('Новая услуга', style: TextStyle(color: AurixTokens.text)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _dialogField('ID (латиницей)', idCtrl, 'new_service'),
        const SizedBox(height: 10),
        _dialogField('Название', nameCtrl, 'Новая услуга'),
        const SizedBox(height: 10),
        _dialogField('Цена', priceCtrl, '0'),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Создать', style: TextStyle(color: AurixTokens.accent))),
      ],
    ));

    if (result != true) return;
    if (idCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) return;

    try {
      await ApiClient.post('/system/service-prices', data: {
        'id': idCtrl.text.trim(),
        'name': nameCtrl.text.trim(),
        'price': double.tryParse(priceCtrl.text.trim()) ?? 0,
      });
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Widget _dialogField(String label, TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: TextStyle(color: AurixTokens.muted, fontSize: 13),
        hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.4), fontSize: 13),
        filled: true, fillColor: AurixTokens.bg2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: AurixTokens.bg1,
        child: Row(children: [
          Icon(Icons.sell_rounded, size: 20, color: AurixTokens.accent),
          const SizedBox(width: 10),
          const Expanded(child: Text('Услуги и цены', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700))),
          if (_saving) ...[
            const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.accent)),
            const SizedBox(width: 8),
          ],
          OutlinedButton.icon(
            onPressed: _addService,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Добавить'),
            style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.accent),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: AurixTokens.muted),
            onPressed: _load,
            tooltip: 'Обновить',
          ),
        ]),
      ),

      // Content
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AurixTokens.accent))
            : _error != null
                ? Center(child: Text('Ошибка: $_error', style: const TextStyle(color: AurixTokens.danger)))
                : _services.isEmpty
                    ? Center(child: Text('Нет услуг', style: TextStyle(color: AurixTokens.muted)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _services.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ServiceCard(
                          service: _services[i],
                          onSave: () => _saveService(_services[i]),
                          onDelete: () => _deleteService(_services[i]),
                          onToggle: (v) => setState(() => _services[i].enabled = v),
                        ),
                      ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════

class _ServiceRow {
  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController stepCtrl;
  final TextEditingController sortCtrl;
  bool enabled;

  _ServiceRow({
    required this.id,
    required String name,
    required String description,
    required double price,
    required int step,
    required int sortOrder,
    required this.enabled,
  })  : nameCtrl = TextEditingController(text: name),
        descCtrl = TextEditingController(text: description),
        priceCtrl = TextEditingController(text: price.toStringAsFixed(0)),
        stepCtrl = TextEditingController(text: '$step'),
        sortCtrl = TextEditingController(text: '$sortOrder');

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory _ServiceRow.fromJson(Map<String, dynamic> j) => _ServiceRow(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    description: (j['description'] ?? '').toString(),
    price: _toDouble(j['price']),
    step: _toInt(j['step']),
    sortOrder: _toInt(j['sort_order']),
    enabled: j['enabled'] == true,
  );
}

// ═══════════════════════════════════════════════════════════════

class _ServiceCard extends StatelessWidget {
  final _ServiceRow service;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _ServiceCard({
    required this.service,
    required this.onSave,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: service.enabled ? AurixTokens.accent.withValues(alpha: 0.2) : AurixTokens.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header: ID + toggle + actions
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AurixTokens.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(service.id, style: TextStyle(color: AurixTokens.accent, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          ),
          const Spacer(),
          Switch(value: service.enabled, onChanged: onToggle, activeColor: AurixTokens.accent),
          IconButton(icon: Icon(Icons.save_rounded, size: 20, color: AurixTokens.positive), onPressed: onSave, tooltip: 'Сохранить'),
          IconButton(icon: Icon(Icons.delete_outline_rounded, size: 20, color: AurixTokens.danger), onPressed: onDelete, tooltip: 'Удалить'),
        ]),
        const SizedBox(height: 12),

        // Fields
        _cardField('Название', service.nameCtrl),
        const SizedBox(height: 10),
        _cardField('Описание', service.descCtrl),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _cardField('Цена (\u20bd)', service.priceCtrl, isNumber: true)),
          const SizedBox(width: 10),
          Expanded(child: _cardField('Шаг wizard', service.stepCtrl, isNumber: true)),
          const SizedBox(width: 10),
          Expanded(child: _cardField('Сортировка', service.sortCtrl, isNumber: true)),
        ]),
      ]),
    );
  }

  Widget _cardField(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))] : null,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        labelStyle: TextStyle(color: AurixTokens.muted, fontSize: 12),
        filled: true,
        fillColor: AurixTokens.bg2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.accent.withValues(alpha: 0.4))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
