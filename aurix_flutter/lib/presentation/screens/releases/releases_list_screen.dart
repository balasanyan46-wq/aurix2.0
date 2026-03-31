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
import 'package:aurix_flutter/core/services/event_tracker.dart';

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
      color: AurixTokens.accent,
      onRefresh: () async => ref.invalidate(releasesProvider),
      child: PremiumPageScaffold(
        title: '\u041c\u043e\u0438 \u0440\u0435\u043b\u0438\u0437\u044b',
        subtitle: '\u0423\u043f\u0440\u0430\u0432\u043b\u044f\u0439\u0442\u0435 \u0440\u0435\u043b\u0438\u0437\u0430\u043c\u0438 \u0438 \u043e\u0442\u0441\u043b\u0435\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0441\u0442\u0430\u0442\u0443\u0441\u044b',
        systemLabel: 'RELEASE CONTROL',
        systemColor: AurixTokens.aiAccent,
        trailing: isDesktop
            ? _CreateButton(onTap: () {
                EventTracker.track('created_release');
                context.push('/releases/create');
              })
            : IconButton(
                onPressed: () {
                  EventTracker.track('created_release');
                  context.push('/releases/create');
                },
                icon: const Icon(Icons.add_rounded, color: AurixTokens.accent),
                style: IconButton.styleFrom(
                  backgroundColor: AurixTokens.accent.withValues(alpha: 0.12),
                ),
              ),
        children: [
          // Search & filter
          FadeInSlide(delayMs: 60, child: _buildSearchAndFilter()),
          const SizedBox(height: 16),

          // Stats summary
          FadeInSlide(
            delayMs: 90,
            child: releases.when(
              data: (list) => _ReleasesStats(releases: list),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 16),

          // Content
          releases.when(
            data: (list) {
              final filtered = _filterReleases(list);
              if (list.isEmpty) {
                return FadeInSlide(delayMs: 120, child: _buildEmptyState(context));
              }
              if (filtered.isEmpty) {
                return FadeInSlide(delayMs: 120, child: _buildNoResults());
              }
              return Column(
                children: [
                  for (int i = 0; i < filtered.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FadeInSlide(
                        delayMs: 100 + (i * 40).clamp(0, 400),
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
                title: '\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438',
                message: e.toString(),
                onRetry: () => ref.invalidate(releasesProvider),
              ),
            ),
          ),
        ],
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

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        // Search field
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
            color: AurixTokens.surface1.withValues(alpha: 0.4),
            border: Border.all(color: AurixTokens.stroke(0.12)),
          ),
          child: TextField(
            style: TextStyle(
              fontFamily: AurixTokens.fontBody,
              color: AurixTokens.text,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: '\u041f\u043e\u0438\u0441\u043a \u043f\u043e \u043d\u0430\u0437\u0432\u0430\u043d\u0438\u044e \u0438\u043b\u0438 \u0430\u0440\u0442\u0438\u0441\u0442\u0443\u2026',
              hintStyle: TextStyle(
                fontFamily: AurixTokens.fontBody,
                color: AurixTokens.micro,
                fontSize: 14,
              ),
              prefixIcon: Icon(Icons.search_rounded, color: AurixTokens.micro, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        const SizedBox(height: 12),
        // Filter chips
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
                    duration: AurixTokens.dFast,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AurixTokens.accent.withValues(alpha: 0.16)
                          : AurixTokens.surface1.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
                      border: Border.all(
                        color: isSelected
                            ? AurixTokens.accent.withValues(alpha: 0.38)
                            : AurixTokens.stroke(0.14),
                      ),
                    ),
                    child: Text(
                      _statusLabel(s),
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
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
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 32),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AurixTokens.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.12)),
            ),
            child: Icon(Icons.album_rounded, size: 28, color: AurixTokens.accent.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text(
            '\u041f\u043e\u043a\u0430 \u043d\u0435\u0442 \u0440\u0435\u043b\u0438\u0437\u043e\u0432',
            style: TextStyle(
              fontFamily: AurixTokens.fontHeading,
              color: AurixTokens.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\u0421\u043e\u0437\u0434\u0430\u0439\u0442\u0435 \u043f\u0435\u0440\u0432\u044b\u0439 \u0440\u0435\u043b\u0438\u0437 \u2014 \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u0435 \u043e\u0431\u043b\u043e\u0436\u043a\u0443, \u0434\u043e\u0431\u0430\u0432\u044c\u0442\u0435 \u0442\u0440\u0435\u043a\u0438\n\u0438 \u043e\u0442\u043f\u0440\u0430\u0432\u044c\u0442\u0435 \u043d\u0430 \u043c\u043e\u0434\u0435\u0440\u0430\u0446\u0438\u044e.',
            style: TextStyle(
              fontFamily: AurixTokens.fontBody,
              color: AurixTokens.muted,
              fontSize: 13,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AurixButton(
            text: '\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u043f\u0435\u0440\u0432\u044b\u0439 \u0440\u0435\u043b\u0438\u0437',
            icon: Icons.add_rounded,
            onPressed: () => context.push('/releases/create'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return PremiumSectionCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 28, color: AurixTokens.micro),
          const SizedBox(height: 12),
          Text(
            '\u041d\u0438\u0447\u0435\u0433\u043e \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d\u043e',
            style: TextStyle(
              fontFamily: AurixTokens.fontBody,
              color: AurixTokens.muted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String s) => switch (s) {
        'all' => '\u0412\u0441\u0435',
        'draft' => '\u0427\u0435\u0440\u043d\u043e\u0432\u0438\u043a',
        'submitted' => '\u041d\u0430 \u043c\u043e\u0434\u0435\u0440\u0430\u0446\u0438\u0438',
        'approved' => '\u041e\u0434\u043e\u0431\u0440\u0435\u043d',
        'rejected' => '\u041e\u0442\u043a\u043b\u043e\u043d\u0451\u043d',
        'live' => '\u041e\u043f\u0443\u0431\u043b\u0438\u043a\u043e\u0432\u0430\u043d',
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
          content: Text('\u0417\u0430\u043f\u0440\u043e\u0441 \u043d\u0430 \u0443\u0434\u0430\u043b\u0435\u043d\u0438\u0435 \u0443\u0436\u0435 \u043e\u0442\u043f\u0440\u0430\u0432\u043b\u0435\u043d'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '\u0417\u0430\u043f\u0440\u043e\u0441\u0438\u0442\u044c \u0443\u0434\u0430\u043b\u0435\u043d\u0438\u0435?',
          style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            color: AurixTokens.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '\u0420\u0435\u043b\u0438\u0437 "${release.title}" \u043d\u0435 \u0443\u0434\u0430\u043b\u0438\u0442\u0441\u044f \u0441\u0440\u0430\u0437\u0443. \u0417\u0430\u043f\u0440\u043e\u0441 \u0443\u0439\u0434\u0451\u0442 \u0430\u0434\u043c\u0438\u043d\u0438\u0441\u0442\u0440\u0430\u0442\u043e\u0440\u0443 \u043d\u0430 \u043f\u043e\u0434\u0442\u0432\u0435\u0440\u0436\u0434\u0435\u043d\u0438\u0435.',
          style: TextStyle(
            fontFamily: AurixTokens.fontBody,
            color: AurixTokens.muted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('\u041e\u0442\u043c\u0435\u043d\u0430'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('\u041e\u0442\u043f\u0440\u0430\u0432\u0438\u0442\u044c'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _requestingReleaseId = release.id);
    try {
      final userId = ref.read(currentUserProvider)?.id;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('\u041e\u0448\u0438\u0431\u043a\u0430: \u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u0435\u043b\u044c \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d')),
          );
        }
        return;
      }
      await ref.read(releaseDeleteRequestRepositoryProvider).requestDelete(
            releaseId: release.id,
            requesterId: userId,
            reason: '\u0417\u0430\u043f\u0440\u043e\u0441 \u0438\u0437 \u0432\u043a\u043b\u0430\u0434\u043a\u0438 "\u0420\u0435\u043b\u0438\u0437\u044b"',
          );
      ref.invalidate(myReleaseDeleteRequestsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('\u0417\u0430\u043f\u0440\u043e\u0441 \u043d\u0430 \u0443\u0434\u0430\u043b\u0435\u043d\u0438\u0435 \u043e\u0442\u043f\u0440\u0430\u0432\u043b\u0435\u043d \u0430\u0434\u043c\u0438\u043d\u0438\u0441\u0442\u0440\u0430\u0442\u043e\u0440\u0443'),
          backgroundColor: AurixTokens.accent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043e\u0442\u043f\u0440\u0430\u0432\u0438\u0442\u044c \u0437\u0430\u043f\u0440\u043e\u0441: $e')),
      );
    } finally {
      if (mounted) setState(() => _requestingReleaseId = null);
    }
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Create Button
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _CreateButton extends StatefulWidget {
  const _CreateButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_CreateButton> createState() => _CreateButtonState();
}

class _CreateButtonState extends State<_CreateButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AurixTokens.accent.withValues(alpha: _hovered ? 0.22 : 0.14),
                AurixTokens.aiAccent.withValues(alpha: _hovered ? 0.16 : 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AurixTokens.accent.withValues(alpha: _hovered ? 0.4 : 0.25),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AurixTokens.accent.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 16, color: AurixTokens.accent),
              const SizedBox(width: 6),
              Text(
                '\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u0440\u0435\u043b\u0438\u0437',
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: AurixTokens.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Stats Summary Bar
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _ReleasesStats extends StatelessWidget {
  const _ReleasesStats({required this.releases});
  final List<ReleaseModel> releases;

  @override
  Widget build(BuildContext context) {
    if (releases.isEmpty) return const SizedBox.shrink();

    final live = releases.where((r) => r.status == 'live').length;
    final pending = releases.where((r) => r.status == 'submitted').length;
    final drafts = releases.where((r) => r.status == 'draft').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        gradient: LinearGradient(
          colors: [
            AurixTokens.surface1.withValues(alpha: 0.5),
            AurixTokens.surface2.withValues(alpha: 0.3),
          ],
        ),
        border: Border.all(color: AurixTokens.stroke(0.12)),
      ),
      child: Row(
        children: [
          _QuickStat(
            label: '\u0412\u0441\u0435\u0433\u043e',
            value: '${releases.length}',
            color: AurixTokens.text,
          ),
          const SizedBox(width: 20),
          _QuickStat(
            label: '\u041e\u043f\u0443\u0431\u043b\u0438\u043a\u043e\u0432\u0430\u043d\u043e',
            value: '$live',
            color: AurixTokens.positive,
          ),
          const SizedBox(width: 20),
          _QuickStat(
            label: '\u041d\u0430 \u043c\u043e\u0434\u0435\u0440\u0430\u0446\u0438\u0438',
            value: '$pending',
            color: AurixTokens.warning,
          ),
          const SizedBox(width: 20),
          _QuickStat(
            label: '\u0427\u0435\u0440\u043d\u043e\u0432\u0438\u043a\u0438',
            value: '$drafts',
            color: AurixTokens.muted,
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: AurixTokens.fontMono,
            color: AurixTokens.micro,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: AurixTokens.fontMono,
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFeatures: AurixTokens.tabularFigures,
          ),
        ),
      ],
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Release Card
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

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
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dMedium,
          curve: AurixTokens.cEase,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _hovered
                    ? statusColor.withValues(alpha: 0.04)
                    : AurixTokens.surface1.withValues(alpha: 0.4),
                AurixTokens.bg1.withValues(alpha: 0.9),
              ],
            ),
            border: Border.all(
              color: _hovered
                  ? statusColor.withValues(alpha: 0.25)
                  : AurixTokens.stroke(0.14),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.08),
                      blurRadius: 24,
                      spreadRadius: -8,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Cover
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      AurixTokens.accent.withValues(alpha: 0.12),
                      AurixTokens.aiAccent.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(color: AurixTokens.stroke(0.12)),
                  image: r.coverUrl != null && r.coverUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(ApiClient.fixUrl(r.coverUrl)),
                          fit: BoxFit.cover,
                          onError: (_, __) {},
                        )
                      : null,
                ),
                child: r.coverUrl == null || r.coverUrl!.isEmpty
                    ? Icon(
                        Icons.album_rounded,
                        color: AurixTokens.micro,
                        size: 24,
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (r.artist != null && r.artist!.isNotEmpty) r.artist!,
                        typeLabel,
                        if (r.releaseDate != null)
                          DateFormat('dd.MM.yy').format(r.releaseDate!),
                      ].join(' \u00b7 '),
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.micro,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.22)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              // Delete request status
              if (widget.requestStatus == 'pending') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AurixTokens.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AurixTokens.warning.withValues(alpha: 0.22)),
                  ),
                  child: Text(
                    '\u0417\u0430\u043f\u0440\u043e\u0441',
                    style: TextStyle(
                      fontFamily: AurixTokens.fontMono,
                      color: AurixTokens.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ] else if (widget.requesting) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AurixTokens.accent.withValues(alpha: 0.6),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                  tooltip: '\u0414\u0435\u0439\u0441\u0442\u0432\u0438\u044f',
                  color: AurixTokens.bg2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (v) {
                    if (v == 'open') widget.onTap();
                    if (v == 'request_delete') widget.onRequestDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: 'open',
                      child: Text(
                        '\u041e\u0442\u043a\u0440\u044b\u0442\u044c',
                        style: TextStyle(
                          fontFamily: AurixTokens.fontBody,
                          color: AurixTokens.text,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'request_delete',
                      child: Text(
                        '\u0417\u0430\u043f\u0440\u043e\u0441\u0438\u0442\u044c \u0443\u0434\u0430\u043b\u0435\u043d\u0438\u0435',
                        style: TextStyle(
                          fontFamily: AurixTokens.fontBody,
                          color: AurixTokens.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  child: AnimatedContainer(
                    duration: AurixTokens.dFast,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _hovered
                          ? AurixTokens.surface2.withValues(alpha: 0.6)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: AurixTokens.micro,
                      size: 18,
                    ),
                  ),
                ),
              ],

              const SizedBox(width: 4),
              AnimatedContainer(
                duration: AurixTokens.dFast,
                transform: Matrix4.translationValues(
                  _hovered ? 2.0 : 0.0,
                  0.0,
                  0.0,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: _hovered ? AurixTokens.text : AurixTokens.micro,
                  size: 18,
                ),
              ),
            ],
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
        'draft' => '\u0427\u0435\u0440\u043d\u043e\u0432\u0438\u043a',
        'submitted' => '\u041c\u043e\u0434\u0435\u0440\u0430\u0446\u0438\u044f',
        'approved' => '\u041e\u0434\u043e\u0431\u0440\u0435\u043d',
        'rejected' => '\u041e\u0442\u043a\u043b\u043e\u043d\u0451\u043d',
        'live' => '\u041e\u043f\u0443\u0431\u043b\u0438\u043a\u043e\u0432\u0430\u043d',
        _ => s,
      };

  static String _typeLabel(String t) => switch (t) {
        'single' => '\u0421\u0438\u043d\u0433\u043b',
        'ep' => 'EP',
        'album' => '\u0410\u043b\u044c\u0431\u043e\u043c',
        _ => t,
      };
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Loading Skeleton
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _ReleasesLoadingSkeleton extends StatelessWidget {
  const _ReleasesLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 10),
      child: Column(
        children: [
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
          PremiumSkeletonBox(height: 56, width: 56, radius: 12),
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
          PremiumSkeletonBox(height: 24, width: 80, radius: 8),
        ],
      ),
    );
  }
}
