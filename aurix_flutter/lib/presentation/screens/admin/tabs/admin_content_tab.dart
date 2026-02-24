import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/features/legal/data/legal_template_model.dart';

final _templatesProvider = FutureProvider<List<LegalTemplateModel>>((ref) async {
  return ref.read(legalRepositoryProvider).fetchTemplates();
});

class AdminContentTab extends ConsumerWidget {
  const AdminContentTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(_templatesProvider);
    final profilesAsync = ref.watch(allProfilesProvider);
    final releasesAsync = ref.watch(allReleasesAdminProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('КОНТЕНТ И ПЛАТФОРМА', style: TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text('Управление контентом, шаблонами и обзор платформы.', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),

          const SizedBox(height: 24),

          // Platform quick stats
          _SectionHeader('ПЛАТФОРМА'),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            final cards = [
              _InfoCard(
                icon: Icons.gavel_rounded,
                label: 'Юр. шаблонов',
                value: templatesAsync.when(data: (t) => '${t.length}', loading: () => '...', error: (_, __) => '—'),
                color: AurixTokens.orange,
              ),
              _InfoCard(
                icon: Icons.people_rounded,
                label: 'Пользователей',
                value: profilesAsync.when(data: (p) => '${p.length}', loading: () => '...', error: (_, __) => '—'),
                color: AurixTokens.positive,
              ),
              _InfoCard(
                icon: Icons.album_rounded,
                label: 'Релизов',
                value: releasesAsync.when(data: (r) => '${r.length}', loading: () => '...', error: (_, __) => '—'),
                color: Colors.blue,
              ),
              _InfoCard(
                icon: Icons.check_circle_rounded,
                label: 'Одобрено',
                value: releasesAsync.when(
                  data: (r) => '${r.where((rel) => rel.status == 'approved' || rel.status == 'live').length}',
                  loading: () => '...',
                  error: (_, __) => '—',
                ),
                color: AurixTokens.positive,
              ),
            ];
            if (isWide) {
              return Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: c))).toList());
            }
            return Wrap(spacing: 10, runSpacing: 10, children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 10) / 2, child: c)).toList());
          }),

          const SizedBox(height: 28),

          // Release types breakdown
          _SectionHeader('ТИПЫ РЕЛИЗОВ'),
          const SizedBox(height: 12),
          releasesAsync.when(
            data: (releases) {
              final types = <String, int>{};
              for (final r in releases) {
                types[r.releaseType] = (types[r.releaseType] ?? 0) + 1;
              }
              if (types.isEmpty) return _emptyCard('Нет данных');
              final sorted = types.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final max = sorted.first.value.toDouble();
              return _card(
                child: Column(
                  children: sorted.map((e) {
                    final pct = releases.isEmpty ? 0.0 : e.value / releases.length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 80, child: Text(_releaseTypeLabel(e.key), style: const TextStyle(color: AurixTokens.text, fontSize: 13))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LayoutBuilder(builder: (ctx, c) {
                              return Container(
                                height: 20,
                                width: c.maxWidth * (max > 0 ? e.value / max : 0),
                                decoration: BoxDecoration(
                                  color: AurixTokens.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 60,
                            child: Text('${e.value} (${(pct * 100).toStringAsFixed(0)}%)',
                              style: const TextStyle(color: AurixTokens.muted, fontSize: 12, fontFeatures: AurixTokens.tabularFigures),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => _loading(),
            error: (e, _) => _errorWidget(e.toString()),
          ),

          const SizedBox(height: 28),

          // Genres breakdown
          _SectionHeader('ЖАНРЫ'),
          const SizedBox(height: 12),
          releasesAsync.when(
            data: (releases) {
              final genres = <String, int>{};
              for (final r in releases) {
                final g = (r.genre != null && r.genre!.isNotEmpty) ? r.genre! : 'Не указан';
                genres[g] = (genres[g] ?? 0) + 1;
              }
              if (genres.isEmpty) return _emptyCard('Нет данных');
              final sorted = genres.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final top = sorted.take(10).toList();
              return _card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: top.map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AurixTokens.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.2)),
                      ),
                      child: Text('${e.key} (${e.value})', style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w500)),
                    )).toList(),
                  ),
                ),
              );
            },
            loading: () => _loading(),
            error: (e, _) => _errorWidget(e.toString()),
          ),

          const SizedBox(height: 28),

          // Legal templates
          _SectionHeader('ЮРИДИЧЕСКИЕ ШАБЛОНЫ'),
          const SizedBox(height: 12),
          templatesAsync.when(
            data: (templates) {
              if (templates.isEmpty) return _emptyCard('Нет шаблонов');
              return Column(
                children: templates.map((t) => _TemplateCard(template: t)).toList(),
              );
            },
            loading: () => _loading(),
            error: (e, _) => _errorWidget(e.toString()),
          ),
        ],
      ),
    );
  }

  static String _releaseTypeLabel(String type) => switch (type) {
        'single' => 'Сингл',
        'ep' => 'EP',
        'album' => 'Альбом',
        'compilation' => 'Сборник',
        _ => type,
      };

  static Widget _loading() => const Center(
    child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
  );

  static Widget _errorWidget(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
    child: Text('Ошибка: $msg', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
  );

  static Widget _emptyCard(String text) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AurixTokens.bg1, borderRadius: BorderRadius.circular(10), border: Border.all(color: AurixTokens.border)),
    child: Center(child: Text(text, style: const TextStyle(color: AurixTokens.muted, fontSize: 13))),
  );

  static Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(color: AurixTokens.bg1, borderRadius: BorderRadius.circular(10), border: Border.all(color: AurixTokens.border)),
    child: child,
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AurixTokens.bg1, borderRadius: BorderRadius.circular(10), border: Border.all(color: AurixTokens.border)),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures)),
              Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});
  final LegalTemplateModel template;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AurixTokens.bg1, borderRadius: BorderRadius.circular(10), border: Border.all(color: AurixTokens.border)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: AurixTokens.muted,
        collapsedIconColor: AurixTokens.muted,
        title: Text(template.title, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            _categoryBadge(template.category),
            const SizedBox(width: 8),
            if (template.version != null) Text('v${template.version}', style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(template.description, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 13, height: 1.5)),
          ),
          if (template.formKeys.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('ПОЛЯ ФОРМЫ', style: TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: template.formKeys.map((k) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AurixTokens.bg2, borderRadius: BorderRadius.circular(4)),
                child: Text(k, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 11, fontFamily: 'monospace')),
              )).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AurixTokens.bg0, borderRadius: BorderRadius.circular(8)),
              child: SingleChildScrollView(
                child: SelectableText(template.body, style: const TextStyle(color: AurixTokens.muted, fontSize: 12, fontFamily: 'monospace', height: 1.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryBadge(LegalCategory cat) {
    final color = switch (cat) {
      LegalCategory.distribution => Colors.blue,
      LegalCategory.team => AurixTokens.positive,
      LegalCategory.production => AurixTokens.orange,
      LegalCategory.nda => Colors.amber,
      LegalCategory.all => AurixTokens.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(cat.label.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
