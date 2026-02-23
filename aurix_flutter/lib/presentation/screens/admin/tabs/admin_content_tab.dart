import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/features/legal/data/legal_template_model.dart';

final _templatesProvider = FutureProvider.autoDispose<List<LegalTemplateModel>>((ref) async {
  return ref.read(legalRepositoryProvider).fetchTemplates();
});

class AdminContentTab extends ConsumerWidget {
  const AdminContentTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(_templatesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'КОНТЕНТ',
            style: TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          const Text(
            'Юридические шаблоны и контент платформы.',
            style: TextStyle(color: AurixTokens.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          const Text(
            'ЮРИДИЧЕСКИЕ ШАБЛОНЫ',
            style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          templatesAsync.when(
            data: (templates) {
              if (templates.isEmpty) {
                return _emptyCard('Нет шаблонов');
              }
              return Column(
                children: templates.map((t) => _TemplateCard(template: t)).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2),
              ),
            ),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Ошибка: $e', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _emptyCard(String text) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AurixTokens.bg1,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AurixTokens.border),
    ),
    child: Center(child: Text(text, style: const TextStyle(color: AurixTokens.muted, fontSize: 13))),
  );
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});
  final LegalTemplateModel template;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: AurixTokens.muted,
        collapsedIconColor: AurixTokens.muted,
        title: Text(
          template.title,
          style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            _categoryBadge(template.category),
            const SizedBox(width: 8),
            if (template.version != null)
              Text('v${template.version}', style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              template.description,
              style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 13, height: 1.5),
            ),
          ),
          if (template.formKeys.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ПОЛЯ ФОРМЫ',
                style: TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: template.formKeys.map((k) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AurixTokens.bg2,
                  borderRadius: BorderRadius.circular(4),
                ),
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
              decoration: BoxDecoration(
                color: AurixTokens.bg0,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  template.body,
                  style: const TextStyle(color: AurixTokens.muted, fontSize: 12, fontFamily: 'monospace', height: 1.6),
                ),
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        cat.label.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
