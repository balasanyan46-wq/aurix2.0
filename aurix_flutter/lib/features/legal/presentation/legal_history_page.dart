import 'package:flutter/material.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/features/legal/data/legal_document_model.dart';
import 'package:aurix_flutter/features/legal/data/legal_repository.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';

final _myDocumentsProvider = FutureProvider<List<LegalDocumentModel>>((ref) async {
  final repo = ref.watch(legalRepositoryProvider);
  return repo.fetchMyDocuments();
});

class LegalHistoryPage extends ConsumerWidget {
  const LegalHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myDocumentsProvider);

    final padding = horizontalPadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
                onPressed: () => context.go('/legal'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'История документов',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AurixTokens.text,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Сохранённые сгенерированные документы',
                      style: TextStyle(color: AurixTokens.muted, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          async.when(
            data: (docs) {
              if (docs.isEmpty) {
                return _EmptyState(onBack: () => context.go('/legal'));
              }
              return Column(
                children: docs
                    .map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _DocumentCard(doc: d, repo: ref.read(legalRepositoryProvider)),
                        ))
                    .toList(),
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: AurixTokens.orange))),
            error: (e, _) => _ErrorState(
              message: formatSupabaseError(e),
              onRetry: () => ref.invalidate(_myDocumentsProvider),
              onBack: () => context.go('/legal'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final LegalDocumentModel doc;
  final LegalRepository repo;

  const _DocumentCard({required this.doc, required this.repo});

  @override
  Widget build(BuildContext context) {
    final hasPdf = doc.filePdfPath != null && doc.filePdfPath!.isNotEmpty;
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(doc.createdAt);

    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AurixTokens.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.description_outlined, color: AurixTokens.orange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AurixTokens.text,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(dateStr, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                if (doc.status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(doc.status, style: TextStyle(color: AurixTokens.orange, fontSize: 12)),
                  ),
              ],
            ),
          ),
          if (hasPdf) ...[
            AurixButton(
              text: 'Скачать',
              icon: Icons.download_rounded,
              onPressed: () => _download(context),
            ),
            const SizedBox(width: 12),
            AurixButton(
              text: 'Открыть',
              icon: Icons.open_in_new_rounded,
              onPressed: () => _open(context),
            ),
          ] else
            Text('PDF не загружен', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    if (doc.filePdfPath == null) return;
    try {
      final url = await repo.signedPdfUrl(doc.filePdfPath!, expiresIn: 3600);
      if (url == null || !context.mounted) return;
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Открыто в браузере')));
      }
    } catch (e) {
      debugPrint('[LegalHistory] signedUrl error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${formatSupabaseError(e)}')));
      }
    }
  }

  Future<void> _open(BuildContext context) => _download(context);
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onBack;

  const _EmptyState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 64, color: AurixTokens.muted),
            const SizedBox(height: 24),
            Text(
              'Нет сохранённых документов',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AurixTokens.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Заполните шаблон и нажмите «Сохранить в историю»',
              style: TextStyle(color: AurixTokens.muted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AurixButton(text: 'К каталогу', icon: Icons.arrow_back_rounded, onPressed: onBack),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorState({required this.message, required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AurixTokens.orange),
            const SizedBox(height: 24),
            Text('Ошибка загрузки', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AurixTokens.text)),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: AurixTokens.muted, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AurixButton(text: 'Повторить', onPressed: onRetry),
                const SizedBox(width: 16),
                AurixButton(text: 'Назад', onPressed: onBack),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
