import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/models/release_model.dart';

class ReleasesListScreen extends ConsumerStatefulWidget {
  const ReleasesListScreen({super.key});

  @override
  ConsumerState<ReleasesListScreen> createState() => _ReleasesListScreenState();
}

class _ReleasesListScreenState extends ConsumerState<ReleasesListScreen> {
  String _search = '';
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final releases = ref.watch(releasesProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

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
                _buildHeader(context, isDesktop),
                const SizedBox(height: 24),

                // Search & filter
                _buildSearchAndFilter(),
                const SizedBox(height: 20),

                // Content
                releases.when(
                  data: (list) {
                    final filtered = _filterReleases(list);
                    if (list.isEmpty) return _buildEmptyState(context);
                    if (filtered.isEmpty) return _buildNoResults();
                    return Column(
                      children: filtered.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReleaseCard(release: r, onTap: () => context.push('/releases/${r.id}')),
                      )).toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
                  ),
                  error: (e, _) => _buildError(e.toString()),
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
        if (!r.title.toLowerCase().contains(q) && !(r.artist ?? '').toLowerCase().contains(q)) return false;
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
            hintText: 'Поиск по названию или артисту...',
            hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: AurixTokens.muted, size: 20),
            filled: true,
            fillColor: AurixTokens.bg1,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AurixTokens.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AurixTokens.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AurixTokens.orange.withValues(alpha: 0.5))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['all', 'draft', 'submitted', 'approved', 'rejected', 'live'].map((s) {
              final isSelected = _statusFilter == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_statusLabel(s)),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _statusFilter = s),
                  selectedColor: AurixTokens.orange.withValues(alpha: 0.2),
                  backgroundColor: AurixTokens.bg1,
                  labelStyle: TextStyle(
                    color: isSelected ? AurixTokens.orange : AurixTokens.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: isSelected ? AurixTokens.orange.withValues(alpha: 0.4) : AurixTokens.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AurixTokens.orange.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.album_outlined, size: 48, color: AurixTokens.orange.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          Text('Пока нет релизов', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Создайте первый релиз — загрузите обложку, добавьте треки\nи отправьте на модерацию.',
            style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.5),
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
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Center(
        child: Text('Ничего не найдено', style: TextStyle(color: AurixTokens.muted)),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text('Ошибка загрузки', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(msg, style: TextStyle(color: AurixTokens.muted, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(releasesProvider),
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.orange, foregroundColor: Colors.black),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String s) => switch (s) {
        'all' => 'Все',
        'draft' => 'Черновик',
        'submitted' => 'На модерации',
        'approved' => 'Одобрен',
        'rejected' => 'Отклонён',
        'live' => 'Опубликован',
        _ => s,
      };
}

// ─── Release Card ───────────────────────────────────────────────────────

class _ReleaseCard extends StatefulWidget {
  final ReleaseModel release;
  final VoidCallback onTap;

  const _ReleaseCard({required this.release, required this.onTap});

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _hovered ? AurixTokens.bg2 : AurixTokens.bg1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hovered ? AurixTokens.borderLight : AurixTokens.border),
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
                      image: r.coverUrl != null
                          ? DecorationImage(image: NetworkImage(r.coverUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: r.coverUrl == null
                        ? Icon(Icons.album_rounded, color: AurixTokens.muted.withValues(alpha: 0.5), size: 28)
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
                          style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (r.artist != null && r.artist!.isNotEmpty) r.artist!,
                            typeLabel,
                            if (r.releaseDate != null) DateFormat('dd.MM.yy').format(r.releaseDate!),
                          ].join(' · '),
                          style: TextStyle(color: AurixTokens.muted, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: AurixTokens.muted.withValues(alpha: 0.5), size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String s) => switch (s) {
        'submitted' => Colors.amber,
        'approved' => AurixTokens.positive,
        'live' => AurixTokens.positive,
        'rejected' => Colors.redAccent,
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
