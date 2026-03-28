import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/core/api/api_client.dart';

class ReleasesListScreen extends ConsumerStatefulWidget {
  const ReleasesListScreen({super.key});

  @override
  ConsumerState<ReleasesListScreen> createState() => _ReleasesListScreenState();
}

class _ReleasesListScreenState extends ConsumerState<ReleasesListScreen> {
  String _search = '';
  String _statusFilter = 'all';
  String? _requestingReleaseId;

  @override
  Widget build(BuildContext context) {
    final releases = ref.watch(releasesProvider);
    final requests =
        ref.watch(myReleaseDeleteRequestsProvider).valueOrNull ?? const [];
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final requestByRelease = <String, String>{
      for (final r in requests) r.releaseId: r.status,
    };

    return RefreshIndicator(
      color: AurixTokens.orange,
      onRefresh: () async => ref.invalidate(releasesProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 32 : 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                FadeInSlide(child: _buildHeader(context, isDesktop)),
                const SizedBox(height: 24),

                // Search & filter
                FadeInSlide(delayMs: 50, child: _buildSearchAndFilter()),
                const SizedBox(height: 20),

                // Content
                releases.when(
                  data: (list) {
                    final filtered = _filterReleases(list);
                    if (list.isEmpty) {
                      return FadeInSlide(delayMs: 100, child: _buildEmptyState(context));
                    }
                    if (filtered.isEmpty) {
                      return FadeInSlide(delayMs: 100, child: _buildNoResults());
                    }
                    return Column(
                      children: [
                        for (int i = 0; i < filtered.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: FadeInSlide(
                              delayMs: 80 + (i * 40).clamp(0, 400),
                              child: _ReleaseCard(
                                release: filtered[i],
                                requestStatus: requestByRelease[filtered[i].id],
                                requesting: _requestingReleaseId == filtered[i].id,
                                onTap: () => context.push('/releases/${filtered[i].id}'),
                                onRequestDelete: () => _onRequestDeletePressed(filtered[i]),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const _ReleasesLoadingSkeleton(),
                  error: (e, _) => FadeInSlide(
                    delayMs: 100,
                    child: PremiumErrorState(
                      title: 'Ошибка загрузки',
                      message: e.toString(),
                      onRetry: () => ref.invalidate(releasesProvider),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<ReleaseModel> _filterReleases(List<ReleaseModel> list) {
    return list.where((r) {
      if (_statusFilter != 'all' && r.status != _statusFilter) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!r.title.toLowerCase().contains(q) &&
            !(r.artist ?? '').toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildHeader(BuildContext context, bool isDesktop) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Мои релизы',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: isDesktop ? null : 22,
                    ),
              ),
              if (isDesktop) ...[
                const SizedBox(height: 4),
                Text(
                  'Управляйте релизами и отслеживайте статусы',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        isDesktop
            ? AurixButton(
                text: 'Создать релиз',
                icon: Icons.add_rounded,
                onPressed: () => context.push('/releases/create'),
              )
            : IconButton(
                onPressed: () => context.push('/releases/create'),
                icon: const Icon(Icons.add_rounded, color: AurixTokens.orange),
                style: IconButton.styleFrom(
                  backgroundColor: AurixTokens.orange.withValues(alpha: 0.12),
                ),
              ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        TextField(
          style: const TextStyle(color: AurixTokens.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Поиск по названию или артисту…',
            prefixIcon:
                const Icon(Icons.search_rounded, color: AurixTokens.muted, size: 20),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              'all',
              'draft',
              'submitted',
              'approved',
              'rejected',
              'live'
            ].map((s) {
              final isSelected = _statusFilter == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _statusFilter = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AurixTokens.accent.withValues(alpha: 0.16)
                          : AurixTokens.bg2.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
                      border: Border.all(
                        color: isSelected
                            ? AurixTokens.accent.withValues(alpha: 0.38)
                            : AurixTokens.stroke(0.18),
                      ),
                    ),
                    child: Text(
                      _statusLabel(s),
                      style: TextStyle(
                        color: isSelected ? AurixTokens.accent : AurixTokens.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return PremiumSectionCard(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AurixTokens.orange.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.album_outlined,
                size: 48, color: AurixTokens.orange.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          Text('Пока нет релизов',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Создайте первый релиз — загрузите обложку, добавьте треки\nи отправьте на модерацию.',
            style:
                TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          AurixButton(
            text: 'Создать первый релиз',
            icon: Icons.add_rounded,
            onPressed: () => context.push('/releases/create'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return PremiumSectionCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text('Ничего не найдено',
            style: TextStyle(color: AurixTokens.muted)),
      ),
    );
  }

  // Error state handled via PremiumErrorState in build method.

  static String _statusLabel(String s) => switch (s) {
        'all' => 'Все',
        'draft' => 'Черновик',
        'submitted' => 'На модерации',
        'approved' => 'Одобрен',
        'rejected' => 'Отклонён',
        'live' => 'Опубликован',
        _ => s,
      };

  Future<void> _onRequestDeletePressed(ReleaseModel release) async {
    if (_requestingReleaseId != null) return;
    final currentStatusByRelease = {
      for (final r in (ref.read(myReleaseDeleteRequestsProvider).valueOrNull ??
          const []))
        r.releaseId: r.status,
    };
    if (currentStatusByRelease[release.id] == 'pending') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Запрос на удаление уже отправлен'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Запросить удаление?',
            style: TextStyle(color: AurixTokens.text)),
        content: Text(
          'Релиз "${release.title}" не удалится сразу. Запрос уйдёт администратору на подтверждение.',
          style: const TextStyle(
              color: AurixTokens.muted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.orange),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _requestingReleaseId = release.id);
    try {
      final userId = ref.read(currentUserProvider)?.id;
      if (userId == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: пользователь не найден')));
        return;
      }
      await ref.read(releaseDeleteRequestRepositoryProvider).requestDelete(
            releaseId: release.id,
            requesterId: userId,
            reason: 'Запрос из вкладки "Релизы"',
          );
      ref.invalidate(myReleaseDeleteRequestsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Запрос на удаление отправлен администратору'),
          backgroundColor: AurixTokens.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить запрос: $e')),
      );
    } finally {
      if (mounted) setState(() => _requestingReleaseId = null);
    }
  }
}

// ─── Release Card ───────────────────────────────────────────────────────

class _ReleaseCard extends StatefulWidget {
  final ReleaseModel release;
  final String? requestStatus;
  final bool requesting;
  final VoidCallback onTap;
  final VoidCallback onRequestDelete;

  const _ReleaseCard({
    required this.release,
    required this.requestStatus,
    required this.requesting,
    required this.onTap,
    required this.onRequestDelete,
  });

  @override
  State<_ReleaseCard> createState() => _ReleaseCardState();
}

class _ReleaseCardState extends State<_ReleaseCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    final statusColor = _statusColor(r.status);
    final statusLabel = _statusLabel(r.status);
    final typeLabel = _typeLabel(r.releaseType);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: PremiumHoverLift(
        enabled: MediaQuery.sizeOf(context).width >= kDesktopBreakpoint,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _hovered ? AurixTokens.bg2 : AurixTokens.bg1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _hovered ? AurixTokens.borderLight : AurixTokens.border),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Cover
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AurixTokens.bg2,
                        borderRadius: BorderRadius.circular(10),
                        image: r.coverUrl != null && r.coverUrl!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(ApiClient.fixUrl(r.coverUrl)),
                                fit: BoxFit.cover,
                                onError: (_, __) {})
                            : null,
                      ),
                      child: r.coverUrl == null
                          ? Icon(Icons.album_rounded,
                              color: AurixTokens.muted.withValues(alpha: 0.5),
                              size: 28)
                          : null,
                    ),
                    const SizedBox(width: 16),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            style: const TextStyle(
                                color: AurixTokens.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (r.artist != null && r.artist!.isNotEmpty)
                                r.artist!,
                              typeLabel,
                              if (r.releaseDate != null)
                                DateFormat('dd.MM.yy').format(r.releaseDate!),
                            ].join(' · '),
                            style: TextStyle(
                                color: AurixTokens.muted, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Status badge
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    if (widget.requestStatus == 'pending')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AurixTokens.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AurixTokens.warning.withValues(alpha: 0.32)),
                        ),
                        child: const Text(
                          'Запрос отправлен',
                          style: TextStyle(
                              color: AurixTokens.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      )
                    else if (widget.requesting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AurixTokens.orange,
                        ),
                      )
                    else
                      PopupMenuButton<String>(
                        tooltip: 'Действия',
                        color: AurixTokens.bg2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        onSelected: (v) {
                          if (v == 'open') widget.onTap();
                          if (v == 'request_delete') widget.onRequestDelete();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem<String>(
                            value: 'open',
                            child: Text('Открыть',
                                style: TextStyle(color: AurixTokens.text)),
                          ),
                          PopupMenuItem<String>(
                            value: 'request_delete',
                            child: Text('Запросить удаление',
                                style: TextStyle(color: AurixTokens.danger)),
                          ),
                        ],
                        child: Icon(
                          Icons.more_horiz_rounded,
                          color: AurixTokens.muted.withValues(alpha: 0.7),
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        color: AurixTokens.muted.withValues(alpha: 0.5),
                        size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String s) => switch (s) {
        'submitted' => AurixTokens.warning,
        'approved' => AurixTokens.positive,
        'live' => AurixTokens.positive,
        'rejected' => AurixTokens.danger,
        _ => AurixTokens.muted,
      };

  static String _statusLabel(String s) => switch (s) {
        'draft' => 'Черновик',
        'submitted' => 'На модерации',
        'approved' => 'Одобрен',
        'rejected' => 'Отклонён',
        'live' => 'Опубликован',
        _ => s,
      };

  static String _typeLabel(String t) => switch (t) {
        'single' => 'Сингл',
        'ep' => 'EP',
        'album' => 'Альбом',
        _ => t,
      };
}

class _ReleasesLoadingSkeleton extends StatelessWidget {
  const _ReleasesLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 10),
      child: Column(
        children: [
          PremiumSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumSkeletonBox(height: 16, width: 220),
                SizedBox(height: 10),
                PremiumSkeletonBox(height: 42),
              ],
            ),
          ),
          SizedBox(height: 14),
          _ReleaseCardSkeleton(),
          SizedBox(height: 10),
          _ReleaseCardSkeleton(),
          SizedBox(height: 10),
          _ReleaseCardSkeleton(),
        ],
      ),
    );
  }
}

class _ReleaseCardSkeleton extends StatelessWidget {
  const _ReleaseCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: const [
          PremiumSkeletonBox(height: 56, width: 56, radius: 10),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumSkeletonBox(height: 14, width: 180),
                SizedBox(height: 8),
                PremiumSkeletonBox(height: 12, width: 140),
              ],
            ),
          ),
          SizedBox(width: 10),
          PremiumSkeletonBox(height: 24, width: 80, radius: 999),
        ],
      ),
    );
  }
}
