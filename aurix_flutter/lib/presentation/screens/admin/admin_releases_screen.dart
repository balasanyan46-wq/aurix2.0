import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/models/release_model.dart';

final allReleasesAdminProvider = FutureProvider<List<ReleaseModel>>((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return [];
  return ref.watch(releaseRepositoryProvider).getAllReleases();
});

class AdminReleasesScreen extends ConsumerWidget {
  const AdminReleasesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releases = ref.watch(allReleasesAdminProvider);
    final isAdmin = ref.watch(isAdminProvider);

    final body = isAdmin.when(
      data: (admin) {
        if (!admin && !embedded) {
          return const Center(child: Text('Доступ запрещён'));
        }
        return releases.when(
          data: (list) => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              return Card(
                child: ListTile(
                  title: Text(r.title),
                  subtitle: Text('${r.releaseType} • ${r.status}${r.releaseDate != null ? ' • ${DateFormat.yMMMd().format(r.releaseDate!)}' : ''}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openAdminRelease(context, ref, r),
                ),
              );
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Ошибка: $e'), FilledButton(onPressed: () => ref.invalidate(allReleasesAdminProvider), child: const Text('Повторить'))])),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Ошибка')),
    );

    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Все релизы (админ)'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: body,
    );
  }

  void _openAdminRelease(BuildContext context, WidgetRef ref, ReleaseModel r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AdminReleaseSheet(release: r, onUpdated: () => ref.invalidate(allReleasesAdminProvider)),
    );
  }
}

class _AdminReleaseSheet extends ConsumerStatefulWidget {
  const _AdminReleaseSheet({required this.release, required this.onUpdated});
  final ReleaseModel release;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_AdminReleaseSheet> createState() => _AdminReleaseSheetState();
}

class _AdminReleaseSheetState extends ConsumerState<_AdminReleaseSheet> {
  late String _status;
  final _noteController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = widget.release.status;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref.read(releaseRepositoryProvider).updateRelease(widget.release.id, status: _status);
      if (_noteController.text.trim().isNotEmpty) {
        final adminId = ref.read(currentUserProvider)?.id;
        if (adminId != null) {
          await ref.read(releaseRepositoryProvider).addAdminNote(releaseId: widget.release.id, adminId: adminId, note: _noteController.text.trim());
        }
      }
      widget.onUpdated();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено')));
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.release.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status, // ignore: deprecated_member_use
              decoration: const InputDecoration(labelText: 'Статус'),
              items: const [
                DropdownMenuItem(value: 'draft', child: Text('draft')),
                DropdownMenuItem(value: 'submitted', child: Text('submitted')),
                DropdownMenuItem(value: 'in_review', child: Text('in_review')),
                DropdownMenuItem(value: 'approved', child: Text('approved')),
                DropdownMenuItem(value: 'rejected', child: Text('rejected')),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Заметка администратора (admin_note)'),
              maxLines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _updateStatus,
              child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
