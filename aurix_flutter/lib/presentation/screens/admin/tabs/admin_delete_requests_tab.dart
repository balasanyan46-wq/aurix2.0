import 'package:aurix_flutter/data/models/release_delete_request_model.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AdminDeleteRequestsTab extends ConsumerStatefulWidget {
  const AdminDeleteRequestsTab({super.key});

  @override
  ConsumerState<AdminDeleteRequestsTab> createState() => _AdminDeleteRequestsTabState();
}

class _AdminDeleteRequestsTabState extends ConsumerState<AdminDeleteRequestsTab> {
  String _statusFilter = 'pending';
  String? _processingId;

  @override
  Widget build(BuildContext context) {
    final reqAsync = ref.watch(allReleaseDeleteRequestsProvider);
    final releases = ref.watch(allReleasesAdminProvider).valueOrNull ?? const <ReleaseModel>[];
    final releaseById = {for (final r in releases) r.id: r};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              const Text(
                'Запросы на удаление',
                style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _filterChip('pending', 'Ожидают'),
              const SizedBox(width: 8),
              _filterChip('approved', 'Одобрены'),
              const SizedBox(width: 8),
              _filterChip('rejected', 'Отклонены'),
            ],
          ),
        ),
        Expanded(
          child: reqAsync.when(
            data: (list) {
              final filtered = list.where((e) => e.status == _statusFilter).toList();
              if (filtered.isEmpty) {
                return const Center(
                  child: Text('Запросов нет', style: TextStyle(color: AurixTokens.muted)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final req = filtered[i];
                  final rel = releaseById[req.releaseId];
                  return _RequestCard(
                    request: req,
                    release: rel,
                    processing: _processingId == req.id,
                    onApprove: () => _approve(req, rel),
                    onReject: () => _reject(req),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      ref.invalidate(allReleaseDeleteRequestsProvider);
                      ref.invalidate(allReleasesAdminProvider);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Повторить'),
                    style: TextButton.styleFrom(foregroundColor: AurixTokens.orange),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = value),
      selectedColor: AurixTokens.orange.withValues(alpha: 0.2),
      backgroundColor: AurixTokens.bg2,
      labelStyle: TextStyle(color: selected ? AurixTokens.orange : AurixTokens.muted, fontSize: 12),
    );
  }

  Future<void> _approve(ReleaseDeleteRequestModel req, ReleaseModel? rel) async {
    if (_processingId != null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Подтвердить удаление?', style: TextStyle(color: AurixTokens.text)),
        content: Text(
          'Релиз «${rel?.title ?? req.releaseId}» будет полностью удалён из базы и хранилища. Это действие необратимо.',
          style: const TextStyle(color: AurixTokens.muted, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.danger),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _processingId = req.id);
    try {
      final adminId = ref.read(currentUserProvider)?.id;
      if (adminId == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: администратор не найден')));
        return;
      }

      await ref.read(releaseDeleteRequestRepositoryProvider).processByAdmin(
        requestId: req.id,
        decision: 'approve',
        comment: 'Одобрено администратором',
      );
      // Keep physical release deletion in app layer for storage cleanup.
      await ref.read(releaseRepositoryProvider).deleteReleaseFully(req.releaseId);
      await ref.read(adminLogRepositoryProvider).log(
            adminId: adminId,
            action: 'release_delete_request_approved',
            targetType: 'release',
            targetId: req.releaseId,
            details: {'requestId': req.id, 'releaseTitle': rel?.title},
          );

      ref.invalidate(allReleaseDeleteRequestsProvider);
      ref.invalidate(allReleasesAdminProvider);
      ref.invalidate(releasesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Запрос одобрен, релиз удалён'),
            backgroundColor: AurixTokens.positive,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _reject(ReleaseDeleteRequestModel req) async {
    if (_processingId != null) return;
    final commentCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Отклонить запрос', style: TextStyle(color: AurixTokens.text)),
        content: TextField(
          controller: commentCtrl,
          style: const TextStyle(color: AurixTokens.text),
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Комментарий (необязательно)',
            hintStyle: TextStyle(color: AurixTokens.muted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отклонить')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _processingId = req.id);
    try {
      final adminId = ref.read(currentUserProvider)?.id;
      if (adminId == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: администратор не найден')));
        return;
      }

      await ref.read(releaseDeleteRequestRepositoryProvider).processByAdmin(
            requestId: req.id,
            decision: 'reject',
            comment: commentCtrl.text.trim(),
          );
      await ref.read(adminLogRepositoryProvider).log(
            adminId: adminId,
            action: 'release_delete_request_rejected',
            targetType: 'release_delete_request',
            targetId: req.id,
            details: {'releaseId': req.releaseId},
          );

      ref.invalidate(allReleaseDeleteRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запрос отклонён')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      commentCtrl.dispose();
      if (mounted) setState(() => _processingId = null);
    }
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.release,
    required this.processing,
    required this.onApprove,
    required this.onReject,
  });

  final ReleaseDeleteRequestModel request;
  final ReleaseModel? release;
  final bool processing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final created = DateFormat('dd.MM.yyyy HH:mm').format(request.createdAt);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  release?.title ?? 'Релиз уже удалён',
                  style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                request.statusLabel,
                style: TextStyle(
                  color: request.status == 'pending'
                      ? AurixTokens.warning
                      : request.status == 'approved'
                          ? AurixTokens.positive
                          : AurixTokens.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('release_id: ${request.releaseId}', style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
          Text('Создан: $created', style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
          if (request.reason != null && request.reason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Причина: ${request.reason!}', style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 12)),
          ],
          if (request.status == 'pending') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (processing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange),
                  )
                else ...[
                  FilledButton(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(backgroundColor: AurixTokens.positive, foregroundColor: Colors.black),
                    child: const Text('Одобрить'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.danger),
                    child: const Text('Отклонить'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

