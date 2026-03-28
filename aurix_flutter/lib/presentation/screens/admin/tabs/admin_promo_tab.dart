import 'dart:convert';

import 'package:aurix_flutter/data/models/promo_request_model.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/crm_providers.dart';
import 'package:aurix_flutter/data/providers/promo_providers.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AdminPromoTab extends ConsumerStatefulWidget {
  const AdminPromoTab({super.key});

  @override
  ConsumerState<AdminPromoTab> createState() => _AdminPromoTabState();
}

class _AdminPromoTabState extends ConsumerState<AdminPromoTab> {
  String _status = 'all';
  String _type = 'all';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final reqAsync = ref.watch(adminPromoRequestsProvider);
    final profiles =
        ref.watch(allProfilesProvider).valueOrNull ?? const <ProfileModel>[];
    final releases = ref.watch(allReleasesAdminProvider).valueOrNull ??
        const <ReleaseModel>[];
    final loading =
        reqAsync.isLoading && (reqAsync.valueOrNull?.isEmpty ?? true);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionCard(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: PremiumSectionHeader(
              title: 'Промо · Админ',
              subtitle:
                  'Все заявки на продвижение, статусы и управление менеджерами.',
            ),
          ),
          const SizedBox(height: 12),
          PremiumSectionCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _filterDropdown(
                        value: _status,
                        items: const [
                          'all',
                          'submitted',
                          'under_review',
                          'approved',
                          'rejected',
                          'in_progress',
                          'completed'
                        ],
                        label: 'Статус',
                        onChanged: (v) => setState(() => _status = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _filterDropdown(
                        value: _type,
                        items: const [
                          'all',
                          'dsp_pitch',
                          'aurix_pitch',
                          'influencer',
                          'ads'
                        ],
                        label: 'Тип',
                        onChanged: (v) => setState(() => _type = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) =>
                      setState(() => _search = v.trim().toLowerCase()),
                  style: const TextStyle(color: AurixTokens.text),
                  decoration: InputDecoration(
                    hintText: 'Поиск по артисту / релизу',
                    hintStyle: const TextStyle(color: AurixTokens.muted),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AurixTokens.muted),
                    filled: true,
                    fillColor: AurixTokens.bg2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AurixTokens.stroke(0.18)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const _AdminPromoLoadingSkeleton()
          else
            reqAsync.when(
              data: (items) {
                final filtered = items.where((r) {
                  if (_status != 'all' && r.status != _status) return false;
                  if (_type != 'all' && r.type != _type) return false;
                  if (_search.isEmpty) return true;
                  final profile = profiles
                      .where((p) => p.userId == r.userId)
                      .cast<ProfileModel?>()
                      .firstWhere(
                        (v) => v != null,
                        orElse: () => null,
                      );
                  final release = releases
                      .where((rel) => rel.id == r.releaseId)
                      .cast<ReleaseModel?>()
                      .firstWhere(
                        (v) => v != null,
                        orElse: () => null,
                      );
                  final hay =
                      '${profile?.displayNameOrName ?? ''} ${release?.title ?? ''}'
                          .toLowerCase();
                  return hay.contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return _empty('Нет заявок под текущие фильтры');
                }

                return Column(
                  children: filtered.map((r) {
                    final profile = profiles
                        .where((p) => p.userId == r.userId)
                        .cast<ProfileModel?>()
                        .firstWhere(
                          (v) => v != null,
                          orElse: () => null,
                        );
                    final release = releases
                        .where((rel) => rel.id == r.releaseId)
                        .cast<ReleaseModel?>()
                        .firstWhere(
                          (v) => v != null,
                          orElse: () => null,
                        );
                    return _card(
                      child: InkWell(
                        onTap: () => _openDetails(r),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_typeLabel(r.type)} · ${release?.title ?? r.releaseId}',
                                      style: const TextStyle(
                                        color: AurixTokens.text,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _StatusPill(status: r.status),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${profile?.displayNameOrName ?? r.userId} · ${DateFormat('dd.MM.yyyy HH:mm').format(r.createdAt)}',
                                style: const TextStyle(
                                    color: AurixTokens.muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AurixTokens.orange)),
              error: (e, _) => Text('Ошибка: $e',
                  style: const TextStyle(color: AurixTokens.danger)),
            ),
        ],
      ),
    );
  }

  Future<void> _openDetails(PromoRequestModel request) async {
    final notesCtrl = TextEditingController(text: request.adminNotes ?? '');
    final managerCtrl =
        TextEditingController(text: request.assignedManager ?? '');
    var status = request.status;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AurixTokens.bg1,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final eventsAsync = ref.watch(promoEventsProvider(request.id));
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
                      _typeLabel(request.type),
                      style: const TextStyle(
                          color: AurixTokens.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    _filterDropdown(
                      value: status,
                      items: const [
                        'submitted',
                        'under_review',
                        'approved',
                        'rejected',
                        'in_progress',
                        'completed'
                      ],
                      label: 'Статус',
                      onChanged: (v) => setSheet(() => status = v),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: managerCtrl,
                      style: const TextStyle(color: AurixTokens.text),
                      decoration: const InputDecoration(
                        labelText: 'Assigned manager (uuid)',
                        labelStyle: TextStyle(color: AurixTokens.muted),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: AurixTokens.text),
                      decoration: const InputDecoration(
                        labelText: 'Admin notes',
                        labelStyle: TextStyle(color: AurixTokens.muted),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AurixTokens.bg2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AurixTokens.stroke(0.16)),
                      ),
                      child: SelectableText(
                        const JsonEncoder.withIndent('  ')
                            .convert(request.formData),
                        style: const TextStyle(
                            color: AurixTokens.textSecondary, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('История событий',
                        style: TextStyle(
                            color: AurixTokens.text,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    eventsAsync.when(
                      data: (events) {
                        if (events.isEmpty) {
                          return const Text('Нет событий',
                              style: TextStyle(color: AurixTokens.muted));
                        }
                        return Column(
                          children: events.map((e) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.history_rounded,
                                      size: 14, color: AurixTokens.muted),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${e.eventType} · ${DateFormat('dd.MM HH:mm').format(e.createdAt)}',
                                      style: const TextStyle(
                                          color: AurixTokens.textSecondary,
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(
                            color: AurixTokens.orange, strokeWidth: 2),
                      ),
                      error: (_, __) => const Text('Ошибка загрузки событий',
                          style: TextStyle(color: AurixTokens.danger)),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AurixTokens.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AurixTokens.orange.withValues(alpha: 0.24)),
                      ),
                      child: FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                setSheet(() => saving = true);
                                try {
                                  final repo =
                                      ref.read(promoRepositoryProvider);
                                  if (status != request.status) {
                                    await repo.updateStatus(
                                        requestId: request.id, status: status);
                                  }
                                  await repo.updateAdminFields(
                                    requestId: request.id,
                                    adminNotes: notesCtrl.text.trim(),
                                    assignedManager: managerCtrl.text.trim(),
                                  );
                                  ref.invalidate(adminPromoRequestsProvider);
                                  ref.invalidate(
                                      promoEventsProvider(request.id));
                                  ref.invalidate(adminCrmLeadsProvider);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    const SnackBar(
                                        content: Text('Заявка обновлена')),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    SnackBar(content: Text('Ошибка: $e')),
                                  );
                                } finally {
                                  if (context.mounted) {
                                    setSheet(() => saving = false);
                                  }
                                }
                              },
                        icon: saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.save_rounded, size: 16),
                        style: FilledButton.styleFrom(
                          backgroundColor: AurixTokens.orange,
                          foregroundColor: Colors.black,
                        ),
                        label: const Text('Сохранить изменения'),
                      ),
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

  Widget _filterDropdown({
    required String value,
    required List<String> items,
    required String label,
    required void Function(String) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AurixTokens.muted),
        filled: true,
        fillColor: AurixTokens.bg1,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dropdownColor: AurixTokens.bg1,
      items: items
          .map((v) => DropdownMenuItem<String>(
                value: v,
                child: Text(v, style: const TextStyle(color: AurixTokens.text)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _card({required Widget child}) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return PremiumHoverLift(
      enabled: isDesktop,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AurixTokens.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AurixTokens.stroke(0.2)),
        ),
        child: child,
      ),
    );
  }

  static Widget _empty(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AurixTokens.bg1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AurixTokens.stroke(0.16)),
        ),
        child: Text(text, style: const TextStyle(color: AurixTokens.muted)),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return PremiumStatusPill(label: status, status: status);
  }
}

class _AdminPromoLoadingSkeleton extends StatelessWidget {
  const _AdminPromoLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        PremiumSectionCard(child: PremiumSkeletonBox(height: 92)),
        SizedBox(height: 12),
        PremiumSectionCard(child: PremiumSkeletonBox(height: 70)),
        SizedBox(height: 10),
        PremiumSectionCard(child: PremiumSkeletonBox(height: 70)),
        SizedBox(height: 10),
        PremiumSectionCard(child: PremiumSkeletonBox(height: 70)),
      ],
    );
  }
}

String _typeLabel(String type) => switch (type) {
      'dsp_pitch' => 'DSP Pitch',
      'aurix_pitch' => 'Aurix Pitch',
      'influencer' => 'Influencer',
      'ads' => 'Ads',
      _ => type,
    };
