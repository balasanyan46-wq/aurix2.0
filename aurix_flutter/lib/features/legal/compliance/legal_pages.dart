import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/legal/compliance/legal_content.dart';

class LegalHubPage extends StatelessWidget {
  const LegalHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegalHero(
                    title: 'AURIX Legal & Compliance',
                    subtitle:
                        'Юридические документы для сайта и приложения. Прозрачно, по делу и без перегруза.',
                    onBack: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: legalDocOrder
                        .map((slug) => legalDocBySlug(slug))
                        .whereType<LegalDoc>()
                        .map(
                          (doc) => _DocCard(
                            doc: doc,
                            onTap: () => context.push(legalDocPath(doc.slug)),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  _LegalFooterNav(
                    onOpen: (slug) => context.push(legalDocPath(slug)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({super.key, required this.slug});

  final String slug;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  final _sectionKeys = <int, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final doc = legalDocBySlug(widget.slug);
    if (doc == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () { if (context.canPop()) context.pop(); else context.go('/legal'); },
            child: const Text('Документ не найден. Вернуться в Legal Hub'),
          ),
        ),
      );
    }

    for (var i = 0; i < doc.sections.length; i++) {
      _sectionKeys.putIfAbsent(i, () => GlobalKey());
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final horizontalPadding = isDesktop ? 28.0 : 18.0;
    final body = _DocBody(
      doc: doc,
      sectionKeys: _sectionKeys,
      onRelatedTap: (slug) => context.push(legalDocPath(slug)),
    );

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    horizontalPadding, 20, horizontalPadding, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LegalHero(
                          title: doc.title,
                          subtitle: doc.shortDescription,
                          note: doc.heroNote,
                          updatedAt: doc.lastUpdated,
                          onBack: () { if (context.canPop()) context.pop(); else context.go('/legal'); },
                          onCopyLink: () async {
                            await Clipboard.setData(ClipboardData(
                                text: Uri.base
                                    .resolve(legalDocPath(doc.slug))
                                    .toString()));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Ссылка скопирована')),
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        if (!isDesktop)
                          _TocCompact(
                            sections: doc.sections,
                            onTap: (index) => Scrollable.ensureVisible(
                              _sectionKeys[index]!.currentContext!,
                              duration: const Duration(milliseconds: 280),
                            ),
                          ),
                        const SizedBox(height: 8),
                        body,
                        const SizedBox(height: 20),
                        _LegalFooterNav(
                            onOpen: (slug) => context.push(legalDocPath(slug))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (isDesktop)
              SizedBox(
                width: 290,
                child: _StickyTocPanel(
                  sections: doc.sections,
                  onTap: (index) => Scrollable.ensureVisible(
                    _sectionKeys[index]!.currentContext!,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DocBody extends StatelessWidget {
  const _DocBody({
    required this.doc,
    required this.sectionKeys,
    required this.onRelatedTap,
  });

  final LegalDoc doc;
  final Map<int, GlobalKey> sectionKeys;
  final ValueChanged<String> onRelatedTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...List.generate(doc.sections.length, (index) {
          final section = doc.sections[index];
          return Padding(
            key: sectionKeys[index],
            padding: const EdgeInsets.only(bottom: 16),
            child: _SectionCard(section: section),
          );
        }),
        if (doc.relatedSlugs.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AurixTokens.glass(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AurixTokens.stroke(0.18)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: doc.relatedSlugs
                  .map((slug) => legalDocBySlug(slug))
                  .whereType<LegalDoc>()
                  .map(
                    (item) => ActionChip(
                      avatar: Icon(legalDocIcon(item.slug),
                          size: 16, color: AurixTokens.orange),
                      label: Text(item.title),
                      onPressed: () => onRelatedTap(item.slug),
                      side: BorderSide(color: AurixTokens.stroke(0.22)),
                      backgroundColor: AurixTokens.bg1,
                      labelStyle: const TextStyle(
                          color: AurixTokens.text, fontWeight: FontWeight.w600),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final LegalDocSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AurixTokens.stroke(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            section.body,
            style: const TextStyle(
              color: AurixTokens.textSecondary,
              height: 1.6,
              fontSize: 14,
            ),
          ),
          if (section.points.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...section.points.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle,
                          size: 6, color: AurixTokens.orange),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        point,
                        style: const TextStyle(
                            color: AurixTokens.text,
                            height: 1.55,
                            fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (section.calloutLabel != null && section.calloutText != null) ...[
            const SizedBox(height: 10),
            _Callout(label: section.calloutLabel!, text: section.calloutText!),
          ],
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AurixTokens.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: AurixTokens.orange,
                  fontWeight: FontWeight.w800,
                  fontSize: 11)),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(color: AurixTokens.text, height: 1.5)),
        ],
      ),
    );
  }
}

class _LegalHero extends StatelessWidget {
  const _LegalHero({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.note,
    this.updatedAt,
    this.onCopyLink,
  });

  final String title;
  final String subtitle;
  final String? note;
  final String? updatedAt;
  final VoidCallback onBack;
  final VoidCallback? onCopyLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.stroke(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Назад',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              if (onCopyLink != null)
                OutlinedButton.icon(
                  onPressed: onCopyLink,
                  icon: const Icon(Icons.link_rounded, size: 16),
                  label: const Text('Скопировать ссылку'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
                color: AurixTokens.textSecondary, height: 1.6, fontSize: 15),
          ),
          if (note != null) ...[
            const SizedBox(height: 12),
            _Callout(label: 'Коротко', text: note!),
          ],
          if (updatedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Последнее обновление: $updatedAt',
              style: TextStyle(
                  color: AurixTokens.muted.withValues(alpha: 0.95),
                  fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _StickyTocPanel extends StatelessWidget {
  const _StickyTocPanel({required this.sections, required this.onTap});

  final List<LegalDocSection> sections;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 20),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AurixTokens.bg1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AurixTokens.stroke(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Оглавление',
                  style: TextStyle(
                      color: AurixTokens.text, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...List.generate(
                sections.length,
                (index) => TextButton(
                  onPressed: () => onTap(index),
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                  child: Text(
                    sections[index].title,
                    style: const TextStyle(
                        fontSize: 12.5, color: AurixTokens.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TocCompact extends StatelessWidget {
  const _TocCompact({required this.sections, required this.onTap});

  final List<LegalDocSection> sections;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.17)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(
          sections.length,
          (index) => ActionChip(
            label: Text('${index + 1}'),
            onPressed: () => onTap(index),
            backgroundColor: AurixTokens.bg1,
            side: BorderSide(color: AurixTokens.stroke(0.22)),
          ),
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, required this.onTap});

  final LegalDoc doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AurixTokens.glass(0.035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AurixTokens.stroke(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(legalDocIcon(doc.slug), color: AurixTokens.orange),
              const SizedBox(height: 10),
              Text(
                doc.title,
                style: const TextStyle(
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                doc.shortDescription,
                style: const TextStyle(
                    color: AurixTokens.textSecondary,
                    height: 1.5,
                    fontSize: 13.5),
              ),
              const SizedBox(height: 10),
              Text(
                'Обновлено: ${doc.lastUpdated}',
                style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalFooterNav extends StatelessWidget {
  const _LegalFooterNav({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.stroke(0.18)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: legalDocOrder
            .map((slug) => legalDocBySlug(slug))
            .whereType<LegalDoc>()
            .map(
              (doc) => TextButton(
                onPressed: () => onOpen(doc.slug),
                child: Text(doc.title, style: const TextStyle(fontSize: 12.5)),
              ),
            )
            .toList(),
      ),
    );
  }
}
