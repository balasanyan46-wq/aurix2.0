import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/features/casting/data/casting_providers.dart';
import 'package:aurix_flutter/features/casting/data/casting_repository.dart';
import 'package:aurix_flutter/features/casting/domain/casting_application.dart';

final _dateFmt = DateFormat('dd.MM.yyyy HH:mm');

Color _statusColor(String s) => switch (s) {
  'paid' => AurixTokens.accent,
  'approved' => AurixTokens.positive,
  'rejected' => AurixTokens.danger,
  'invited' => AurixTokens.aiAccent,
  _ => AurixTokens.muted,
};

String _statusLabel(String s) => switch (s) {
  'paid' => 'Оплачено',
  'approved' => 'Одобрен',
  'rejected' => 'Отклонён',
  'invited' => 'Приглашён',
  _ => s,
};

Color _planColor(String p) => switch (p) {
  'base' => AurixTokens.muted,
  'pro' => AurixTokens.accent,
  'vip' => AurixTokens.aiAccent,
  _ => AurixTokens.muted,
};

class AdminCastingTab extends ConsumerStatefulWidget {
  const AdminCastingTab({super.key});
  @override
  ConsumerState<AdminCastingTab> createState() => _AdminCastingTabState();
}

class _AdminCastingTabState extends ConsumerState<AdminCastingTab> {
  String _filterStatus = '';
  String _filterCity = '';
  String _searchQuery = '';
  String _sortField = 'date';
  bool _sortAsc = false;

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(adminCastingApplicationsProvider);
    final statsAsync = ref.watch(adminCastingStatsProvider);

    return appsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
      error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.danger))),
      data: (allApps) {
        final apps = _applyFilters(allApps);
        final stats = statsAsync.valueOrNull;

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const PremiumSectionCard(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: PremiumSectionHeader(
                  title: 'КОД АРТИСТА',
                  subtitle: 'Участники, оплаты, статусы',
                ),
              ),
              const SizedBox(height: 12),

              // Stats
              if (stats != null) SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _StatChip('Участников', stats.total, AurixTokens.text),
                  const SizedBox(width: 8),
                  _StatChip('Оплачено', stats.paidCount, AurixTokens.accent),
                  const SizedBox(width: 8),
                  _StatChip('Одобрено', stats.approvedCount, AurixTokens.positive),
                  const SizedBox(width: 8),
                  _StatChip('Приглашено', stats.invitedCount, AurixTokens.aiAccent),
                  const SizedBox(width: 8),
                  _StatChip('Выручка', 0, AurixTokens.warning, overrideText: stats.revenueFormatted),
                ]),
              ),
              const SizedBox(height: 12),

              // Filters
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(
                  width: 220, height: 40,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: AurixTokens.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Поиск по имени...', prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AurixTokens.muted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12), filled: true, fillColor: AurixTokens.surface1,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AurixTokens.stroke(0.2))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AurixTokens.stroke(0.2))),
                    ),
                  ),
                ),
                _Drop(value: _filterStatus, hint: 'Статус', items: const {
                  '': 'Все', 'paid': 'Оплачено', 'approved': 'Одобрен', 'rejected': 'Отклонён', 'invited': 'Приглашён',
                }, onChanged: (v) => setState(() => _filterStatus = v ?? '')),
                _Drop(value: _filterCity, hint: 'Город', items: {
                  '': 'Все города', for (final c in allApps.map((a) => a.city).where((c) => c.isNotEmpty).toSet()) c: c,
                }, onChanged: (v) => setState(() => _filterCity = v ?? '')),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AurixTokens.muted, size: 20),
                  onPressed: () { ref.invalidate(adminCastingApplicationsProvider); ref.invalidate(adminCastingStatsProvider); },
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(alignment: Alignment.centerLeft, child: Text('${apps.length} участников', style: const TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600))),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: apps.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inbox_rounded, color: AurixTokens.muted.withValues(alpha: 0.4), size: 48),
                    const SizedBox(height: 12),
                    const Text('Нет участников', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                  ]))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: apps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _Row(
                      app: apps[i],
                      onTap: () => _openDetail(apps[i]),
                      onStatusChange: (s) => _changeStatus(apps[i].id, s),
                    ),
                  ),
          ),
        ]);
      },
    );
  }

  List<CastingApplication> _applyFilters(List<CastingApplication> all) {
    var list = all.toList();
    if (_filterStatus.isNotEmpty) list = list.where((a) => a.status == _filterStatus).toList();
    if (_filterCity.isNotEmpty) list = list.where((a) => a.city == _filterCity).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((a) => a.name.toLowerCase().contains(q) || a.artistName.toLowerCase().contains(q)).toList();
    }
    list.sort((a, b) {
      final cmp = _sortField == 'name' ? a.name.compareTo(b.name) : _sortField == 'city' ? a.city.compareTo(b.city) : a.createdAt.compareTo(b.createdAt);
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  Future<void> _changeStatus(int id, String status) async {
    try {
      await CastingRepository.instance.adminUpdateStatus(id, status);
      ref.invalidate(adminCastingApplicationsProvider);
      ref.invalidate(adminCastingStatsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Статус: ${_statusLabel(status)}'), backgroundColor: AurixTokens.bg2,
        behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger, behavior: SnackBarBehavior.floating));
    }
  }

  void _openDetail(CastingApplication app) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _DetailSheet(app: app, onStatusChange: (s) { Navigator.of(context).pop(); _changeStatus(app.id, s); }),
    );
  }
}

// ── Widgets ──

class _StatChip extends StatelessWidget {
  final String label; final int count; final Color color; final String? overrideText;
  const _StatChip(this.label, this.count, this.color, {this.overrideText});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(overrideText ?? '$count', style: TextStyle(fontFamily: AurixTokens.fontMono, color: color, fontSize: 16, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _Drop extends StatelessWidget {
  final String value; final String hint; final Map<String, String> items; final ValueChanged<String?> onChanged;
  const _Drop({required this.value, required this.hint, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40, padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AurixTokens.surface1, borderRadius: BorderRadius.circular(12), border: Border.all(color: AurixTokens.stroke(0.2))),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value.isEmpty ? '' : value, dropdownColor: AurixTokens.bg2,
        style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontFamily: AurixTokens.fontBody),
        icon: const Icon(Icons.expand_more_rounded, size: 16, color: AurixTokens.muted),
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: onChanged,
      )),
    );
  }
}

class _Row extends StatelessWidget {
  final CastingApplication app; final VoidCallback onTap; final ValueChanged<String> onStatusChange;
  const _Row({required this.app, required this.onTap, required this.onStatusChange});
  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(app.status);
    final pc = _planColor(app.plan);
    final isWide = MediaQuery.sizeOf(context).width > 700;
    return Material(color: Colors.transparent, child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: AurixTokens.surface1.withValues(alpha: 0.5), border: Border.all(color: AurixTokens.stroke(0.12))),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: sc, boxShadow: [BoxShadow(color: sc.withValues(alpha: 0.4), blurRadius: 6)])),
          const SizedBox(width: 14),
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.name, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(app.phone, style: const TextStyle(color: AurixTokens.muted, fontSize: 12), overflow: TextOverflow.ellipsis),
          ])),
          if (isWide) ...[
            Expanded(flex: 2, child: Text(app.city, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
            SizedBox(width: 80, child: Text(_dateFmt.format(app.createdAt.toLocal()), style: TextStyle(fontFamily: AurixTokens.fontMono, color: AurixTokens.muted, fontSize: 10, fontFeatures: AurixTokens.tabularFigures))),
          ],
          // Plan badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: pc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: pc.withValues(alpha: 0.3))),
            child: Text(app.planLabel, style: TextStyle(color: pc, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
          // Amount
          SizedBox(width: 60, child: Text(app.amountFormatted, textAlign: TextAlign.right, style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]))),
          const SizedBox(width: 8),
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: sc.withValues(alpha: 0.3))),
            child: Text(_statusLabel(app.status), style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AurixTokens.muted, size: 18),
            color: AurixTokens.bg2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: onStatusChange,
            itemBuilder: (_) => [
              if (app.status != 'approved') PopupMenuItem(value: 'approved', child: Row(children: [Icon(Icons.check_circle_rounded, color: AurixTokens.positive, size: 16), const SizedBox(width: 8), Text('Одобрить', style: TextStyle(color: AurixTokens.positive, fontSize: 13))])),
              if (app.status != 'invited') PopupMenuItem(value: 'invited', child: Row(children: [Icon(Icons.star_rounded, color: AurixTokens.aiAccent, size: 16), const SizedBox(width: 8), Text('Пригласить', style: TextStyle(color: AurixTokens.aiAccent, fontSize: 13))])),
              if (app.status != 'rejected') PopupMenuItem(value: 'rejected', child: Row(children: [Icon(Icons.cancel_rounded, color: AurixTokens.danger, size: 16), const SizedBox(width: 8), Text('Отклонить', style: TextStyle(color: AurixTokens.danger, fontSize: 13))])),
            ],
          ),
        ]),
      ),
    ));
  }
}

class _DetailSheet extends StatelessWidget {
  final CastingApplication app; final ValueChanged<String> onStatusChange;
  const _DetailSheet({required this.app, required this.onStatusChange});
  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(app.status);
    final pc = _planColor(app.plan);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      margin: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(color: AurixTokens.bg1, borderRadius: BorderRadius.circular(24), border: Border.all(color: AurixTokens.stroke(0.2)), boxShadow: AurixTokens.elevatedShadow),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AurixTokens.muted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          // Header
          Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: pc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: pc.withValues(alpha: 0.3))),
              child: Center(child: Text(app.planLabel, style: TextStyle(fontFamily: AurixTokens.fontMono, color: pc, fontSize: 14, fontWeight: FontWeight.w800)))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.name, style: const TextStyle(fontFamily: AurixTokens.fontHeading, color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: sc.withValues(alpha: 0.3))),
                  child: Text(_statusLabel(app.status), style: TextStyle(color: sc, fontSize: 11, fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Text(app.amountFormatted, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w800)),
              ]),
            ])),
          ]),
          const SizedBox(height: 28),
          _Field('Имя', app.name),
          _Field('Телефон', app.phone),
          _Field('Город', app.city),
          _Field('Тариф', app.planLabel),
          _Field('Сумма', app.amountFormatted),
          _Field('Дата', _dateFmt.format(app.createdAt.toLocal())),
          if (app.paidAt != null) _Field('Оплачено', _dateFmt.format(app.paidAt!.toLocal())),
          const SizedBox(height: 24),
          Text('ДЕЙСТВИЯ', style: TextStyle(fontFamily: AurixTokens.fontMono, color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Row(children: [
            if (app.status != 'approved') Expanded(child: _Btn(label: 'ОДОБРИТЬ', icon: Icons.check_circle_rounded, color: AurixTokens.positive, onPressed: () => onStatusChange('approved'))),
            if (app.status != 'approved' && app.status != 'invited') const SizedBox(width: 10),
            if (app.status != 'invited') Expanded(child: _Btn(label: 'ПРИГЛАСИТЬ', icon: Icons.star_rounded, color: AurixTokens.aiAccent, onPressed: () => onStatusChange('invited'))),
          ]),
          if (app.status != 'rejected') ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: _Btn(label: 'ОТКЛОНИТЬ', icon: Icons.cancel_rounded, color: AurixTokens.danger, onPressed: () => onStatusChange('rejected'))),
          ],
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label; final String value;
  const _Field(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600))),
    ]));
  }
}

class _Btn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onPressed;
  const _Btn({required this.label, required this.icon, required this.color, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.transparent, child: InkWell(
      onTap: onPressed, borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.25))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 18), const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ]),
      ),
    ));
  }
}
