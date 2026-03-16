import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/data/models/billing_subscription_model.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/presentation/providers/subscription_provider.dart';

class AdminSubscriptionsTab extends ConsumerStatefulWidget {
  const AdminSubscriptionsTab({super.key});

  @override
  ConsumerState<AdminSubscriptionsTab> createState() =>
      _AdminSubscriptionsTabState();
}

class _AdminSubscriptionsTabState extends ConsumerState<AdminSubscriptionsTab> {
  String _query = '';
  String _status = 'all';

  void _invalidateAll() {
    ref.invalidate(adminBillingSubscriptionsProvider);
    ref.invalidate(allProfilesProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentBillingSubscriptionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final subsAsync = ref.watch(adminBillingSubscriptionsProvider);
    final profiles = ref.watch(allProfilesProvider).valueOrNull ?? const [];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: AurixTokens.bg1.withValues(alpha: 0.84),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Поиск по email/имени/uid',
                    hintStyle:
                        const TextStyle(color: AurixTokens.muted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search,
                        color: AurixTokens.muted, size: 20),
                    filled: true,
                    fillColor: AurixTokens.bg2.withValues(alpha: 0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AurixTokens.border),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(),
            ],
          ),
        ),
        Expanded(
          child: subsAsync.when(
            data: (rows) {
              final mapped = rows.where((s) {
                final p = profiles.cast<dynamic>().firstWhere(
                      (x) => x?.userId == s.userId,
                      orElse: () => null,
                    ) as ProfileModel?;
                final effectiveStatus = _effectiveStatus(sub: s, profile: p);
                if (_status != 'all' && effectiveStatus != _status) return false;
                if (_query.isEmpty) return true;
                final name = (p?.displayNameOrName ?? '').toString().toLowerCase();
                final email = (p?.email ?? '').toString().toLowerCase();
                return s.userId.toLowerCase().contains(_query) ||
                    name.contains(_query) ||
                    email.contains(_query);
              }).toList();

              if (mapped.isEmpty) {
                return Center(
                  child: Text(
                    'Подписок не найдено',
                    style: TextStyle(color: AurixTokens.muted),
                  ),
                );
              }

              return ListView.separated(
                padding: EdgeInsets.all(horizontalPadding(context)),
                itemCount: mapped.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final s = mapped[i];
                  final p = profiles.cast<dynamic>().firstWhere(
                        (x) => x?.userId == s.userId,
                        orElse: () => null,
                      ) as ProfileModel?;
                  return _rowCard(
                    sub: s,
                    displayName: p?.displayNameOrName ?? s.userId,
                    email: p?.email ?? '—',
                    profile: p,
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AurixTokens.orange),
            ),
            error: (e, _) => Center(
              child: Text('Ошибка: $e',
                  style: const TextStyle(color: AurixTokens.muted)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip() {
    const options = ['all', 'trial', 'active', 'past_due', 'expired', 'canceled'];
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => _status = v),
      color: AurixTokens.bg2,
      itemBuilder: (_) => options
          .map((x) => PopupMenuItem<String>(
                value: x,
                child: Text(
                  x,
                  style: TextStyle(
                    color: _status == x ? AurixTokens.orange : AurixTokens.text,
                  ),
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AurixTokens.bg2.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AurixTokens.stroke(0.24)),
        ),
        child: Row(
          children: [
            Text('Статус: $_status',
                style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: AurixTokens.muted),
          ],
        ),
      ),
    );
  }

  Widget _rowCard({
    required BillingSubscriptionModel sub,
    required String displayName,
    required String email,
    required ProfileModel? profile,
  }) {
    final effectivePlan = _effectivePlan(sub: sub, profile: profile);
    final effectiveStatus = _effectiveStatus(sub: sub, profile: profile);
    final effectiveEnd = _effectiveEnd(sub: sub, profile: profile);
    final end = DateFormat('dd.MM.yyyy').format(effectiveEnd);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            spreadRadius: -10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: const TextStyle(
                        color: AurixTokens.text, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(email,
                    style:
                        const TextStyle(color: AurixTokens.muted, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  'Тариф: ${_planLabel(effectivePlan)} · Статус: $effectiveStatus · До: $end',
                  style: const TextStyle(color: AurixTokens.text, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openActions(sub),
            child: const Text('Управлять'),
          ),
        ],
      ),
    );
  }

  String _planLabel(String id) {
    switch (id) {
      case 'breakthrough':
        return 'Прорыв';
      case 'empire':
        return 'Империя';
      default:
        return 'Старт';
    }
  }

  String _effectivePlan({
    required BillingSubscriptionModel sub,
    required ProfileModel? profile,
  }) {
    final p = (profile?.planId ?? '').trim();
    return p.isEmpty ? sub.planId : p;
  }

  String _effectiveStatus({
    required BillingSubscriptionModel sub,
    required ProfileModel? profile,
  }) {
    final p = (profile?.subscriptionStatus ?? '').trim();
    return p.isEmpty ? sub.status : p;
  }

  DateTime _effectiveEnd({
    required BillingSubscriptionModel sub,
    required ProfileModel? profile,
  }) {
    return profile?.subscriptionEnd ?? sub.currentPeriodEnd;
  }

  Future<void> _openActions(BillingSubscriptionModel sub) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AurixTokens.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle, color: AurixTokens.orange),
                title: const Text('Активировать'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final days = await _askDurationDays();
                  if (days == null) return;
                  try {
                    await ref
                        .read(billingSubscriptionRepositoryProvider)
                        .activate(
                          userId: sub.userId,
                          planId: sub.planId,
                          extendDays: days,
                        );
                    _invalidateAll();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Активировано на $days дн.')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline,
                    color: AurixTokens.orange),
                title: const Text('Продлить +30 дней'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await ref
                        .read(billingSubscriptionRepositoryProvider)
                        .extend(current: sub, extendDays: 30);
                    _invalidateAll();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Продлено на 30 дней')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                title: const Text('Отменить сейчас'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await ref
                        .read(billingSubscriptionRepositoryProvider)
                        .cancel(current: sub, atPeriodEnd: false);
                    _invalidateAll();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Подписка отменена')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.swap_horiz, color: AurixTokens.orange),
                title: const Text('Сменить тариф'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _changePlanDialog(sub);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePlanDialog(BillingSubscriptionModel sub) async {
    var selected = sub.planId;
    var durationDays = 30;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Сменить тариф',
            style: TextStyle(color: AurixTokens.text)),
        content: StatefulBuilder(
          builder: (dialogCtx, setSt) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selected,
                dropdownColor: AurixTokens.bg2,
                items: const [
                  DropdownMenuItem(value: 'start', child: Text('Старт')),
                  DropdownMenuItem(value: 'breakthrough', child: Text('Прорыв')),
                  DropdownMenuItem(value: 'empire', child: Text('Империя')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setSt(() => selected = v);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: durationDays,
                dropdownColor: AurixTokens.bg2,
                decoration: const InputDecoration(labelText: 'Срок (дней)'),
                items: const [7, 14, 30, 60, 90, 180, 365]
                    .map((d) =>
                        DropdownMenuItem<int>(value: d, child: Text('$d дней')))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setSt(() => durationDays = v);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.orange,
              foregroundColor: Colors.black,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await ref.read(billingSubscriptionRepositoryProvider).activate(
            userId: sub.userId,
            planId: selected,
            extendDays: durationDays,
          );
      _invalidateAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Тариф ${_planLabel(selected)} назначен на $durationDays дн.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<int?> _askDurationDays() async {
    int selected = 30;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Срок тарифа',
            style: TextStyle(color: AurixTokens.text)),
        content: StatefulBuilder(
          builder: (dialogCtx, setSt) => DropdownButtonFormField<int>(
            initialValue: selected,
            dropdownColor: AurixTokens.bg2,
            decoration: const InputDecoration(labelText: 'Срок (дней)'),
            items: const [7, 14, 30, 60, 90, 180, 365]
                .map((d) =>
                    DropdownMenuItem<int>(value: d, child: Text('$d дней')))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setSt(() => selected = v);
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.orange,
              foregroundColor: Colors.black,
            ),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return selected;
  }
}

