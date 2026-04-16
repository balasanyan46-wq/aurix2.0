import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

Map<String, dynamic> _m(dynamic d) {
  if (d is Map<String, dynamic>) return d;
  if (d is Map) return Map<String, dynamic>.from(d);
  return {};
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return double.tryParse(v)?.toInt() ?? 0;
  return 0;
}

final _adminBeatsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.get('/beats/admin/all');
  final body = _m(res.data);
  return ((body['beats'] as List?) ?? []).map((e) => _m(e)).toList();
});

class AdminBeatsTab extends ConsumerWidget {
  const AdminBeatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beatsAsync = ref.watch(_adminBeatsProvider);

    return beatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
      error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.danger))),
      data: (beats) {
        if (beats.isEmpty) {
          return const Center(child: Text('Нет битов', style: TextStyle(color: AurixTokens.muted)));
        }
        final pending = beats.where((b) => b['status'] == 'pending').toList();
        final active = beats.where((b) => b['status'] == 'active').toList();
        final rejected = beats.where((b) => b['status'] == 'rejected').toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pending.isNotEmpty) ...[
              _sectionTitle('НА МОДЕРАЦИИ (${pending.length})'),
              ...pending.map((b) => _BeatAdminCard(beat: b, onChanged: () => ref.invalidate(_adminBeatsProvider))),
              const SizedBox(height: 20),
            ],
            _sectionTitle('АКТИВНЫЕ (${active.length})'),
            if (active.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('Нет активных битов', style: TextStyle(color: AurixTokens.muted))),
            ...active.map((b) => _BeatAdminCard(beat: b, onChanged: () => ref.invalidate(_adminBeatsProvider))),
            if (rejected.isNotEmpty) ...[
              const SizedBox(height: 20),
              _sectionTitle('ОТКЛОНЁННЫЕ (${rejected.length})'),
              ...rejected.map((b) => _BeatAdminCard(beat: b, onChanged: () => ref.invalidate(_adminBeatsProvider))),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(
          color: AurixTokens.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(
          fontFamily: AurixTokens.fontHeading, color: AurixTokens.textSecondary,
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5,
        )),
      ],
    ),
  );
}

class _BeatAdminCard extends StatelessWidget {
  final Map<String, dynamic> beat;
  final VoidCallback onChanged;

  const _BeatAdminCard({required this.beat, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final status = (beat['status'] ?? '').toString();
    final isPending = status == 'pending';
    final df = DateFormat('dd.MM.yy HH:mm');
    final createdAt = DateTime.tryParse(beat['created_at']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        gradient: AurixTokens.cardGradient,
        border: Border.all(
          color: isPending ? AurixTokens.warning.withValues(alpha: 0.3) : AurixTokens.stroke(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48, height: 48,
                  child: beat['cover_url'] != null
                      ? Image.network(beat['cover_url'].toString(), fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder())
                      : _placeholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (beat['title'] ?? '').toString(),
                      style: TextStyle(fontFamily: AurixTokens.fontHeading, color: AurixTokens.text,
                        fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${beat['seller_name'] ?? beat['seller_email'] ?? 'ID: ${beat['seller_id']}'}'
                      ' · ${beat['genre'] ?? '—'} · ${_toInt(beat['bpm'])} BPM',
                      style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_statusLabel(status), style: TextStyle(
                  color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Prices + stats
          Row(
            children: [
              Text('Лизинг: ${_toInt(beat['price_lease'])}₽', style: _priceStyle),
              const SizedBox(width: 12),
              Text('Безлимит: ${_toInt(beat['price_unlimited'])}₽', style: _priceStyle),
              const SizedBox(width: 12),
              Text('Экс: ${_toInt(beat['price_exclusive'])}₽', style: _priceStyle),
              const Spacer(),
              if (createdAt != null)
                Text(df.format(createdAt.toLocal()), style: const TextStyle(color: AurixTokens.micro, fontSize: 10)),
            ],
          ),
          // Admin actions for pending
          if (isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: FilledButton.icon(
                      onPressed: () => _approve(context),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Одобрить'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AurixTokens.positive,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () => _reject(context),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Отклонить'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AurixTokens.danger,
                        side: BorderSide(color: AurixTokens.danger.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    try {
      await ApiClient.post('/beats/${beat['id']}/approve');
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Бит одобрен'), backgroundColor: AurixTokens.positive));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Причина отклонения', style: TextStyle(color: AurixTokens.text)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AurixTokens.text),
          decoration: const InputDecoration(hintText: 'Опишите причину...', hintStyle: TextStyle(color: AurixTokens.muted)),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.danger),
            child: const Text('Отклонить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.post('/beats/${beat['id']}/reject-beat', data: {'reason': ctrl.text.trim()});
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Бит отклонён'), backgroundColor: AurixTokens.warning));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Widget _placeholder() => Container(
    color: AurixTokens.surface2,
    child: const Icon(Icons.audiotrack_rounded, color: AurixTokens.muted, size: 20),
  );

  Color _statusColor(String s) => switch (s) {
    'pending' => AurixTokens.warning,
    'active' => AurixTokens.positive,
    'rejected' => AurixTokens.danger,
    'sold' => AurixTokens.muted,
    _ => AurixTokens.muted,
  };

  String _statusLabel(String s) => switch (s) {
    'pending' => 'На модерации',
    'active' => 'Активен',
    'rejected' => 'Отклонён',
    'sold' => 'Продан',
    _ => s,
  };

  static const _priceStyle = TextStyle(color: AurixTokens.textSecondary, fontSize: 11);
}
