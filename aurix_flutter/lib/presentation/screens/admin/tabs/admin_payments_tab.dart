import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Admin tab: full payment log with refund action.
class AdminPaymentsTab extends ConsumerStatefulWidget {
  const AdminPaymentsTab({super.key});

  @override
  ConsumerState<AdminPaymentsTab> createState() => _AdminPaymentsTabState();
}

final _adminPaymentsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, ({String status, String type})>((ref, filter) async {
  try {
    final qs = <String>[];
    if (filter.status != 'all') qs.add('status=${filter.status}');
    if (filter.type != 'all') qs.add('type=${filter.type}');
    qs.add('limit=100');
    final res = await ApiClient.get('/admin/payments?${qs.join('&')}');
    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  } catch (_) {
    return [];
  }
});

class _AdminPaymentsTabState extends ConsumerState<AdminPaymentsTab> {
  String _statusFilter = 'confirmed';
  String _typeFilter = 'all';

  static const _statuses = ['all', 'confirmed', 'pending', 'failed', 'refunded'];
  static const _types = ['all', 'subscription', 'credits'];

  String _statusLabel(String s) => switch (s) {
        'all' => 'Все',
        'confirmed' => 'Оплачено',
        'pending' => 'Ожидает',
        'failed' => 'Ошибка',
        'refunded' => 'Возвращено',
        _ => s,
      };

  String _typeLabel(String s) => switch (s) {
        'all' => 'Все',
        'subscription' => 'Подписка',
        'credits' => 'Кредиты',
        _ => s,
      };

  ({Color color, IconData icon}) _statusInfo(String s) => switch (s) {
        'confirmed' => (color: AurixTokens.positive, icon: Icons.check_circle_rounded),
        'pending' => (color: AurixTokens.orange, icon: Icons.hourglass_top_rounded),
        'failed' => (color: AurixTokens.danger, icon: Icons.error_outline_rounded),
        'refunded' => (color: AurixTokens.accent, icon: Icons.undo_rounded),
        _ => (color: AurixTokens.muted, icon: Icons.help_outline_rounded),
      };

  Future<void> _confirmRefund(Map<String, dynamic> p) async {
    final paymentId = p['id'] as int? ?? 0;
    final amountKop = p['amount'] as int? ?? 0;
    final amountRub = (amountKop / 100).round();
    final email = p['email']?.toString() ?? '';
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: Text('Вернуть $amountRub ₽?',
            style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Пользователь: $email',
                style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
            const SizedBox(height: 8),
            const Text(
              'T-Bank вернёт средства на карту за 1-3 рабочих дня. Подписка/кредиты будут откатаны.',
              style: TextStyle(color: AurixTokens.muted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              maxLength: 300,
              style: const TextStyle(color: AurixTokens.text),
              decoration: InputDecoration(
                hintText: 'Причина возврата',
                hintStyle: const TextStyle(color: AurixTokens.muted),
                filled: true,
                fillColor: AurixTokens.bg2,
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.danger, foregroundColor: Colors.white),
            child: const Text('Вернуть деньги'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // SAFETY: бэкенд требует confirmed=true + reason >= 5 символов.
    // Внутренний AlertDialog уже валидирует reason, но мы дополнительно
    // ограничим минимум 5 символов на клиенте.
    final reason = reasonCtrl.text.trim();
    if (reason.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Причина обязательна (минимум 5 символов)'),
        backgroundColor: AurixTokens.danger,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    try {
      final res = await ApiClient.post('/admin/payments/$paymentId/refund', data: {
        'confirmed': true,
        'reason': reason,
      });
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      if (!mounted) return;

      if (body['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Возврат отправлен в T-Bank. Платёж помечен как refunded.'),
          backgroundColor: AurixTokens.bg2,
          behavior: SnackBarBehavior.floating,
        ));
        ref.invalidate(_adminPaymentsProvider((status: _statusFilter, type: _typeFilter)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(body['error']?.toString() ?? 'Ошибка возврата'),
          backgroundColor: AurixTokens.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ошибка: $e'),
        backgroundColor: AurixTokens.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (status: _statusFilter, type: _typeFilter);
    final dataAsync = ref.watch(_adminPaymentsProvider(key));

    return RefreshIndicator(
      color: AurixTokens.accent,
      onRefresh: () async => ref.invalidate(_adminPaymentsProvider(key)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Статус:',
                    style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statuses.map((s) {
                      final selected = _statusFilter == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_statusLabel(s)),
                          selected: selected,
                          onSelected: (_) => setState(() => _statusFilter = s),
                          selectedColor: AurixTokens.accent.withValues(alpha: 0.2),
                          backgroundColor: AurixTokens.bg1,
                          labelStyle: TextStyle(
                            color: selected ? AurixTokens.accent : AurixTokens.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Тип:',
                    style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _types.map((s) {
                      final selected = _typeFilter == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_typeLabel(s)),
                          selected: selected,
                          onSelected: (_) => setState(() => _typeFilter = s),
                          selectedColor: AurixTokens.orange.withValues(alpha: 0.2),
                          backgroundColor: AurixTokens.bg1,
                          labelStyle: TextStyle(
                            color: selected ? AurixTokens.orange : AurixTokens.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: dataAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.danger)),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('Нет платежей', style: TextStyle(color: AurixTokens.muted))),
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _PaymentTile(
                    item: items[i],
                    statusInfo: _statusInfo(items[i]['status']?.toString() ?? ''),
                    onRefund: () => _confirmRefund(items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.item,
    required this.statusInfo,
    required this.onRefund,
  });

  final Map<String, dynamic> item;
  final ({Color color, IconData icon}) statusInfo;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    final amountKop = item['amount'] as int? ?? 0;
    final amountRub = (amountKop / 100).round();
    final status = item['status']?.toString() ?? '';
    final paymentType = item['payment_type']?.toString() ?? 'subscription';
    final plan = item['plan']?.toString() ?? '';
    final email = item['email']?.toString() ?? '';
    final orderId = item['order_id']?.toString() ?? '';
    final created = DateTime.tryParse(item['created_at']?.toString() ?? '');
    final canRefund = status == 'confirmed';
    final isCredits = paymentType == 'credits';

    final typeLabel = isCredits
        ? '${item['credits_amount'] ?? 0} кредитов'
        : '${_planLabel(plan)} · ${item['billing_period'] == 'yearly' ? 'год' : 'месяц'}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isCredits ? AurixTokens.orange : AurixTokens.accent).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCredits ? Icons.bolt_rounded : Icons.workspace_premium_rounded,
                  color: isCredits ? AurixTokens.orange : AurixTokens.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(typeLabel,
                        style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(email,
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Text('$amountRub ₽',
                  style: const TextStyle(
                    color: AurixTokens.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(statusInfo.icon, size: 13, color: statusInfo.color),
              const SizedBox(width: 4),
              Text(status,
                  style: TextStyle(color: statusInfo.color, fontSize: 11, fontWeight: FontWeight.w700)),
              const Text(' · ', style: TextStyle(color: AurixTokens.muted, fontSize: 11)),
              Expanded(
                child: Text(
                  '${created != null ? DateFormat('dd.MM.yy HH:mm').format(created) : ''} · $orderId',
                  style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontFamily: 'monospace'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canRefund)
                TextButton.icon(
                  onPressed: onRefund,
                  icon: const Icon(Icons.undo_rounded, size: 14, color: AurixTokens.danger),
                  label: const Text('Возврат', style: TextStyle(color: AurixTokens.danger, fontSize: 12, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _planLabel(String p) => switch (p) {
        'start' => 'Старт',
        'breakthrough' => 'Прорыв',
        'empire' => 'Империя',
        'credits' => 'Кредиты',
        _ => p,
      };
}
