import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/admin_config.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/core/download_helper.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(appStateProvider).isAdmin ||
        (user?.email != null && adminEmails.contains(user!.email!.toLowerCase()));
    if (!isAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, size: 64, color: AurixTokens.muted),
            const SizedBox(height: 16),
            Text('Admin access required', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Switch to Admin role in Settings', style: TextStyle(color: AurixTokens.muted)),
          ],
        ),
      );
    }

    return _AdminContent();
  }
}

class _AdminContent extends ConsumerStatefulWidget {
  const _AdminContent();

  @override
  ConsumerState<_AdminContent> createState() => _AdminContentState();
}

class _AdminContentState extends ConsumerState<_AdminContent> {
  ReleaseStatus? _filterStatus;
  String _artistFilter = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminReleasesProvider);
    return async.when(
      data: (allReleases) {
        var list = allReleases;
        if (_filterStatus != null) {
          list = list.where((r) => releaseStatusFromString(r.status) == _filterStatus).toList();
        }
        if (_artistFilter.isNotEmpty) {
          list = list.where((r) => r.title.toLowerCase().contains(_artistFilter.toLowerCase())).toList();
        }
        return _AdminBody(
          ref: ref,
          releases: list,
          filterStatus: _filterStatus,
          artistFilter: _artistFilter,
          onFilterStatusChanged: (v) => setState(() => _filterStatus = v),
          onArtistFilterChanged: (v) => setState(() => _artistFilter = v),
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
      error: (e, _) => Center(child: Text('Ошибка: $e', style: TextStyle(color: AurixTokens.muted))),
    );
  }
}

class _AdminBody extends StatelessWidget {
  final WidgetRef ref;
  final List<ReleaseModel> releases;
  final ReleaseStatus? filterStatus;
  final String artistFilter;
  final ValueChanged<ReleaseStatus?> onFilterStatusChanged;
  final ValueChanged<String> onArtistFilterChanged;

  const _AdminBody({
    required this.ref,
    required this.releases,
    required this.filterStatus,
    required this.artistFilter,
    required this.onFilterStatusChanged,
    required this.onArtistFilterChanged,
  });

  Future<void> _downloadMetadata(BuildContext context, String releaseId, String title) async {
    try {
      final service = ref.read(releaseExportServiceProvider);
      final jsonStr = await service.getMetadataJson(releaseId);
      final safeName = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
      await downloadText(jsonStr, '${safeName}_metadata.json');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Метаданные скачаны')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = horizontalPadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Manage releases', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 720;
              final filterField = TextField(
                decoration: InputDecoration(
                  hintText: 'Фильтр по названию',
                  hintStyle: TextStyle(color: AurixTokens.muted),
                  filled: true,
                  fillColor: AurixTokens.glass(0.08),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: const TextStyle(color: AurixTokens.text),
                onChanged: onArtistFilterChanged,
              );

              final statusDropdown = DropdownButton<ReleaseStatus?>(
                value: filterStatus,
                hint: Text('По статусу', style: TextStyle(color: AurixTokens.muted)),
                dropdownColor: AurixTokens.bg1,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Все')),
                  ...ReleaseStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label))),
                ],
                onChanged: onFilterStatusChanged,
              );

              final uploadBtn = OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Upload CSV'),
                style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
              );

              if (!narrow) {
                return Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
                      child: filterField,
                    ),
                    const SizedBox(width: 16),
                    statusDropdown,
                    const Spacer(),
                    uploadBtn,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  filterField,
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      statusDropdown,
                      uploadBtn,
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          AurixGlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ...releases.map((r) => _AdminReleaseRow(
                  release: r,
                  onDownloadMetadata: () => _downloadMetadata(context, r.id, r.title),
                )),
                if (releases.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Нет релизов', style: TextStyle(color: AurixTokens.muted)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminReleaseRow extends ConsumerWidget {
  final ReleaseModel release;
  final VoidCallback onDownloadMetadata;

  const _AdminReleaseRow({required this.release, required this.onDownloadMetadata});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = releaseStatusFromString(release.status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AurixTokens.stroke(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(release.title, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600)),
                    Text('${release.releaseType}${release.artist != null ? ' • ${release.artist}' : ''}', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                  ],
                ),
              ),
              Text(status.label, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onDownloadMetadata,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Скачать метаданные'),
              ),
              const SizedBox(width: 8),
              if (release.coverUrl != null)
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(release.coverUrl!), mode: LaunchMode.platformDefault),
                  icon: const Icon(Icons.image, size: 18),
                  label: const Text('Обложка'),
                ),
              const SizedBox(width: 8),
              _TrackDownloadsButton(releaseId: release.id),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackDownloadsButton extends ConsumerWidget {
  final String releaseId;

  const _TrackDownloadsButton({required this.releaseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () => _showTracksDialog(context, ref),
      icon: const Icon(Icons.music_note, size: 18),
      label: const Text('Треки'),
    );
  }

  Future<void> _showTracksDialog(BuildContext context, WidgetRef ref) async {
    final trackRepo = ref.read(trackRepositoryProvider);
    final tracks = await trackRepo.getTracksByRelease(releaseId);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Скачать треки'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tracks.length,
            itemBuilder: (_, i) {
              final t = tracks[i];
              return ListTile(
                leading: const Icon(Icons.audiotrack, size: 20, color: AurixTokens.orange),
                title: Text(t.title ?? 'Трек ${i + 1}', style: const TextStyle(color: AurixTokens.text, fontSize: 14)),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => launchUrl(Uri.parse(t.audioUrl), mode: LaunchMode.platformDefault),
                  color: AurixTokens.orange,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
