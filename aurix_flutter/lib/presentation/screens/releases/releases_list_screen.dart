import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/config/responsive.dart';

final myReleasesProvider = FutureProvider<List<ReleaseModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(releaseRepositoryProvider).getReleasesByOwner(user.id);
});

/// Мои релизы — дизайн по HTML макету.
/// Табы, таблица, pagination, статусы.
class ReleasesListScreen extends ConsumerStatefulWidget {
  const ReleasesListScreen({super.key});

  @override
  ConsumerState<ReleasesListScreen> createState() => _ReleasesListScreenState();
}

class _ReleasesListScreenState extends ConsumerState<ReleasesListScreen> {
  String _tab = 'all';
  final int _pageSize = 10;
  int _page = 0;

  List<ReleaseModel> _filter(List<ReleaseModel> list) {
    var out = list;
    switch (_tab) {
      case 'active':
        out = out.where((r) => r.status == 'live' || r.status == 'scheduled').toList();
        break;
      case 'review':
        out = out.where((r) => r.status == 'submitted' || r.status == 'in_review').toList();
        break;
      case 'drafts':
        out = out.where((r) => r.status == 'draft').toList();
        break;
      default:
        break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final releasesAsync = ref.watch(myReleasesProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final padding = isDesktop ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: releasesAsync.when(
        data: (list) {
          final filtered = _filter(list);
          final totalPages = (filtered.length / _pageSize).ceil().clamp(1, 999);
          final page = _page.clamp(0, totalPages - 1);
          final paged = filtered.skip(page * _pageSize).take(_pageSize).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myReleasesProvider),
            color: AurixTokens.orange,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title & CTA
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Мои релизы',
                              style: TextStyle(
                                color: AurixTokens.text,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Управляйте вашей музыкой и отслеживайте статус публикации',
                              style: TextStyle(color: AurixTokens.muted, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: () => context.push('/releases/create'),
                        icon: const Icon(Icons.add_circle, size: 20),
                        label: const Text('Создать релиз'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AurixTokens.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Tabs
                  _ReleasesTabs(
                    tab: _tab,
                    allCount: list.length,
                    activeCount: list.where((r) => r.status == 'live' || r.status == 'scheduled').length,
                    reviewCount: list.where((r) => r.status == 'submitted' || r.status == 'in_review').length,
                    draftsCount: list.where((r) => r.status == 'draft').length,
                    onTab: (t) => setState(() { _tab = t; _page = 0; }),
                  ),
                  const SizedBox(height: 24),

                  // Table / List
                  if (paged.isEmpty)
                    _EmptyState(onCreate: () => context.push('/releases/create'))
                  else
                    _ReleasesTable(
                      releases: paged,
                      isDesktop: isDesktop,
                      onTap: (r) => context.push('/releases/${r.id}'),
                      onEdit: (r) => context.push('/releases/${r.id}'),
                      onAnalytics: (r) => context.push('/releases/${r.id}'),
                    ),

                  // Pagination
                  if (filtered.isNotEmpty && totalPages > 1) ...[
                    const SizedBox(height: 16),
                    _PaginationBar(
                      page: page,
                      totalPages: totalPages,
                      total: filtered.length,
                      pageSize: _pageSize,
                      onPage: (p) => setState(() => _page = p),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AurixTokens.muted),
              const SizedBox(height: 16),
              Text('Ошибка: $e', style: TextStyle(color: AurixTokens.muted), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(myReleasesProvider),
                style: FilledButton.styleFrom(backgroundColor: AurixTokens.orange),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleasesTabs extends StatelessWidget {
  final String tab;
  final int allCount;
  final int activeCount;
  final int reviewCount;
  final int draftsCount;
  final void Function(String) onTab;

  const _ReleasesTabs({
    required this.tab,
    required this.allCount,
    required this.activeCount,
    required this.reviewCount,
    required this.draftsCount,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AurixTokens.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TabItem(label: 'Все', count: allCount, selected: tab == 'all', onTap: () => onTab('all')),
            const SizedBox(width: 32),
            _TabItem(label: 'Активные', count: activeCount, selected: tab == 'active', onTap: () => onTab('active')),
            const SizedBox(width: 32),
            _TabItem(label: 'На проверке', count: reviewCount, selected: tab == 'review', onTap: () => onTab('review')),
            const SizedBox(width: 32),
            _TabItem(label: 'Черновики', count: draftsCount, selected: tab == 'drafts', onTap: () => onTab('drafts')),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TabItem({required this.label, required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AurixTokens.orange : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AurixTokens.orange : AurixTokens.muted,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AurixTokens.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(color: AurixTokens.orange, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReleasesTable extends StatelessWidget {
  final List<ReleaseModel> releases;
  final bool isDesktop;
  final void Function(ReleaseModel) onTap;
  final void Function(ReleaseModel) onEdit;
  final void Function(ReleaseModel) onAnalytics;

  const _ReleasesTable({
    required this.releases,
    required this.isDesktop,
    required this.onTap,
    required this.onEdit,
    required this.onAnalytics,
  });

  String _releaseTypeLabel(String t) {
    switch (t.toLowerCase()) {
      case 'single': return 'Сингл';
      case 'ep': return 'EP';
      case 'album': return 'Альбом';
      default: return t;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        children: [
          if (isDesktop) _TableHeader(),
          ...releases.map((r) => _ReleaseRow(
                release: r,
                isDesktop: isDesktop,
                releaseTypeLabel: _releaseTypeLabel(r.releaseType),
                onTap: () => onTap(r),
                onEdit: () => onEdit(r),
                onAnalytics: () => onAnalytics(r),
              )),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AurixTokens.bg2.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text('Обложка', style: _headerStyle())),
          Expanded(flex: 2, child: Text('Название и артист', style: _headerStyle())),
          SizedBox(width: 80, child: Text('Тип', style: _headerStyle())),
          SizedBox(width: 110, child: Text('Дата выхода', style: _headerStyle())),
          SizedBox(width: 120, child: Text('Статус', style: _headerStyle())),
          SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: Text('Действия', style: _headerStyle()))),
        ],
      ),
    );
  }

  TextStyle _headerStyle() => TextStyle(
        color: AurixTokens.muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );
}

class _ReleaseRow extends StatelessWidget {
  final ReleaseModel release;
  final bool isDesktop;
  final String releaseTypeLabel;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onAnalytics;

  const _ReleaseRow({
    required this.release,
    required this.isDesktop,
    required this.releaseTypeLabel,
    required this.onTap,
    required this.onEdit,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final status = _statusBadge(release.status);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AurixTokens.border)),
        ),
        child: isDesktop
            ? Row(
                children: [
                  _Cover(url: release.coverUrl),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(release.title, style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(release.artist ?? 'Aurix Music', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  SizedBox(width: 80, child: Text(releaseTypeLabel, style: TextStyle(color: AurixTokens.muted, fontSize: 14))),
                  SizedBox(
                    width: 110,
                    child: Text(
                      release.releaseDate != null ? DateFormat('d MMM yyyy', 'ru').format(release.releaseDate!) : '—',
                      style: TextStyle(color: AurixTokens.muted, fontSize: 14),
                    ),
                  ),
                  SizedBox(width: 120, child: status),
                  SizedBox(
                    width: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _ActionBtn(icon: Icons.edit, onTap: onEdit),
                        _ActionBtn(icon: Icons.bar_chart, onTap: onAnalytics),
                        _ActionBtn(icon: Icons.more_vert, onTap: () {}),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Cover(url: release.coverUrl),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(release.title, style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700)),
                            Text('${releaseTypeLabel} • ${release.artist ?? "Aurix Music"}', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      status,
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ActionBtn(icon: Icons.edit, onTap: onEdit),
                      _ActionBtn(icon: Icons.bar_chart, onTap: onAnalytics),
                      _ActionBtn(icon: Icons.more_vert, onTap: () {}),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (label, bg, fg, border) = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  (String, Color, Color, Color) _statusStyle(String s) {
    switch (s) {
      case 'live':
      case 'scheduled':
        return ('Опубликовано', AurixTokens.positive.withValues(alpha: 0.15), AurixTokens.positive, AurixTokens.positive.withValues(alpha: 0.3));
      case 'submitted':
      case 'in_review':
        return ('На проверке', AurixTokens.orange.withValues(alpha: 0.15), AurixTokens.orange, AurixTokens.orange.withValues(alpha: 0.3));
      default:
        return ('Черновик', AurixTokens.bg2, AurixTokens.muted, AurixTokens.border);
    }
  }
}

class _Cover extends StatelessWidget {
  final String? url;

  const _Cover({this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AurixTokens.bg2,
        image: url != null && url!.isNotEmpty
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      child: url == null || url!.isEmpty ? Icon(Icons.album_outlined, color: AurixTokens.muted, size: 24) : null,
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: AurixTokens.muted),
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(36, 36),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.album_outlined, size: 64, color: AurixTokens.muted),
          const SizedBox(height: 16),
          Text('Пока нет релизов', style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Создайте первый релиз и начните публиковать музыку', style: TextStyle(color: AurixTokens.muted)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_circle),
            label: const Text('Создать релиз'),
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.orange),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final int pageSize;
  final void Function(int) onPage;

  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.pageSize,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final from = page * pageSize + 1;
    final to = (from + pageSize - 1).clamp(0, total);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AurixTokens.bg2.withValues(alpha: 0.3),
        border: Border(top: BorderSide(color: AurixTokens.border)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Показано $from–$to из $total релизов',
            style: TextStyle(color: AurixTokens.muted, fontSize: 12),
          ),
          Row(
            children: [
              _PageBtn(label: 'Назад', enabled: page > 0, onTap: () => onPage(page - 1)),
              const SizedBox(width: 8),
              ...List.generate(totalPages.clamp(0, 5), (i) {
                final p = totalPages <= 5 ? i : (page < 2 ? i : (page >= totalPages - 2 ? totalPages - 5 + i : page - 2 + i));
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _PageBtn(
                    label: '${p + 1}',
                    selected: p == page,
                    onTap: () => onPage(p),
                  ),
                );
              }),
              const SizedBox(width: 8),
              _PageBtn(label: 'Вперёд', enabled: page < totalPages - 1, onTap: () => onPage(page + 1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PageBtn({required this.label, this.selected = false, this.enabled = true, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AurixTokens.orange : null,
          border: Border.all(color: selected ? AurixTokens.orange : AurixTokens.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AurixTokens.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
