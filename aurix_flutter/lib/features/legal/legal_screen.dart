import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/legal/data/legal_document_model.dart';
import 'package:aurix_flutter/features/legal/data/legal_template_model.dart';
import 'package:aurix_flutter/features/legal/data/legal_repository.dart';
import 'package:aurix_flutter/features/legal/presentation/widgets/legal_template_card.dart';
import 'package:aurix_flutter/features/legal/presentation/widgets/legal_category_chips.dart';
import 'package:aurix_flutter/features/legal/presentation/widgets/legal_preview_pane.dart';
import 'package:aurix_flutter/features/legal/presentation/widgets/legal_field_input.dart';
import 'package:aurix_flutter/features/legal/services/legal_pdf_service.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

final _templatesQueryProvider = FutureProvider.family<List<LegalTemplateModel>, ({String? query, LegalCategory? category})>((ref, params) async {
  final repo = ref.watch(legalRepositoryProvider);
  return repo.fetchTemplates(query: params.query, category: params.category);
});

final _templateProvider = FutureProvider.family<LegalTemplateModel?, String>((ref, id) async {
  final repo = ref.watch(legalRepositoryProvider);
  return repo.getTemplateById(id);
});

final _myDocumentsProvider = FutureProvider<List<LegalDocumentModel>>((ref) async {
  final repo = ref.watch(legalRepositoryProvider);
  return repo.fetchMyDocuments();
});

enum _LegalView { list, detail, history }

/// Юридика: Supabase-интеграция. Используется в DesignShell и MainShellScreen (без go_router).
class LegalScreen extends ConsumerStatefulWidget {
  const LegalScreen({super.key});

  @override
  ConsumerState<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends ConsumerState<LegalScreen> {
  _LegalView _view = _LegalView.list;
  String? _selectedTemplateId;
  final _searchController = TextEditingController();
  LegalCategory _selectedCategory = LegalCategory.all;
  final Map<String, TextEditingController> _formControllers = {};
  String? _initializedTemplateId;
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _formControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _openTemplate(String id) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _view = _LegalView.detail;
        _selectedTemplateId = id;
        _initializedTemplateId = null;
      });
    });
  }

  void _goToHistory() {
    setState(() {
      _view = _LegalView.history;
      ref.invalidate(_myDocumentsProvider);
    });
  }

  void _backToList() {
    setState(() {
      _view = _LegalView.list;
      _selectedTemplateId = null;
    });
  }

  void _initFormControllers(LegalTemplateModel t, Map<String, String>? profileDefaults) {
    if (_initializedTemplateId == t.id) return;
    _initializedTemplateId = t.id;
    for (final c in _formControllers.values) {
      c.dispose();
    }
    _formControllers.clear();
    for (final key in t.formKeys) {
      String initial = profileDefaults?[key] ?? '';
      _formControllers[key] = TextEditingController(text: initial);
    }
  }

  String _filledText(LegalTemplateModel t) {
    var text = t.body;
    for (final e in _formControllers.entries) {
      text = text.replaceAll('{{${e.key}}}', e.value.text.trim().isEmpty ? '__________' : e.value.text.trim());
    }
    text = text.replaceAllMapped(RegExp(r'\{\{([A-Z_0-9]+)\}\}'), (_) => '__________');
    return text;
  }

  Map<String, String> _payload() {
    final m = <String, String>{};
    for (final e in _formControllers.entries) {
      m[e.key] = e.value.text.trim();
    }
    return m;
  }

  Future<void> _saveToHistory(LegalTemplateModel template, String filledText, Map<String, String> payload) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(legalRepositoryProvider);
      final doc = await repo.createDocumentRecord(template: template, payload: payload);
      debugPrint('[LegalScreen] createDocumentRecord templateId=${template.id} documentId=${doc.id}');
      final bytes = await LegalPdfService.generatePdfBytes(title: template.title, body: filledText);
      final path = await repo.uploadPdf(user.id, doc.id, bytes);
      debugPrint('[LegalScreen] uploadPdf path=$path');
      await repo.updateDocumentPdfPath(doc.id, path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено в историю')));
        _goToHistory();
      }
    } catch (e) {
      debugPrint('[LegalScreen] saveToHistory error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${formatSupabaseError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_view == _LegalView.list) {
      return _buildList();
    }
    if (_view == _LegalView.history) {
      return _buildHistory();
    }
    if (_view == _LegalView.detail && _selectedTemplateId != null) {
      return _buildDetail(_selectedTemplateId!);
    }
    return _buildList();
  }

  Widget _buildList() {
    final query = _searchController.text.trim();
    final q = query.isEmpty ? null : query;
    final cat = _selectedCategory == LegalCategory.all ? null : _selectedCategory;
    final async = ref.watch(_templatesQueryProvider((query: q, category: cat)));

    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final padding = horizontalPadding(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Юридические документы',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AurixTokens.text,
                            fontSize: isDesktop ? null : 22,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Шаблоны договоров и соглашений для музыкальной индустрии',
                      style: TextStyle(color: AurixTokens.muted, fontSize: isDesktop ? 15 : 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AurixButton(
                text: 'История',
                icon: Icons.history_rounded,
                onPressed: _goToHistory,
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: AurixTokens.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Поиск по шаблонам...',
              hintStyle: TextStyle(color: AurixTokens.muted, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: AurixTokens.muted, size: 20),
              filled: true,
              fillColor: AurixTokens.glass(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AurixTokens.stroke()),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          LegalCategoryChips(
            selected: _selectedCategory,
            onSelected: (c) => setState(() => _selectedCategory = c),
          ),
          const SizedBox(height: 24),
          async.when(
            data: (templates) {
              debugPrint('[LegalScreen] templates count=${templates.length}');
              if (templates.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Text(
                      'Ничего не найдено',
                      style: TextStyle(color: AurixTokens.muted, fontSize: 16),
                    ),
                  ),
                );
              }
              if (!isDesktop) {
                return Column(
                  children: templates
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LegalTemplateCard(
                              template: t,
                              compact: true,
                              onOpen: () => _openTemplate(t.id),
                            ),
                          ))
                      .toList(),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: templates.length,
                    itemBuilder: (context, index) {
                      final t = templates[index];
                      return LegalTemplateCard(
                        template: t,
                        onOpen: () => _openTemplate(t.id),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: AurixTokens.orange)),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ошибка загрузки', style: TextStyle(color: AurixTokens.orange)),
                    const SizedBox(height: 8),
                    Text(formatSupabaseError(e), style: TextStyle(color: AurixTokens.muted, fontSize: 12), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    AurixButton(
                      text: 'Повторить',
                      onPressed: () => ref.invalidate(_templatesQueryProvider((query: q, category: cat))),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(String templateId) {
    final asyncTemplate = ref.watch(_templateProvider(templateId));
    final profileAsync = ref.watch(currentProfileProvider);

    return asyncTemplate.when(
      data: (template) {
        if (template == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AurixTokens.orange),
                const SizedBox(height: 16),
                Text('Шаблон не найден', style: TextStyle(color: AurixTokens.muted)),
                const SizedBox(height: 16),
                AurixButton(text: 'Назад', onPressed: _backToList),
              ],
            ),
          );
        }
        Map<String, String>? profileDefaults;
        final p = profileAsync.valueOrNull;
        if (p != null) {
          profileDefaults = {
            'ARTIST_NAME': p.name ?? p.displayName ?? p.artistName ?? p.email,
            'CITY': p.city ?? '',
            'PHONE': p.phone ?? '',
            'BIO': p.bio ?? '',
          };
        }
        _initFormControllers(template, profileDefaults);

        final filledText = _filledText(template);
        final payload = _payload();
        final isWide = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
        final padding = horizontalPadding(context);

        if (isWide) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: LegalPreviewPane(
                    title: template.title,
                    previewText: filledText,
                    onBack: _backToList,
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(width: 320, child: _buildFormColumn(template, filledText, payload, showButtons: true)),
              ],
            ),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
                onPressed: _backToList,
              ),
              title: Text(
                template.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AurixTokens.text,
                      fontWeight: FontWeight.w600,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
              bottom: TabBar(
                labelColor: AurixTokens.orange,
                unselectedLabelColor: AurixTokens.muted,
                indicatorColor: AurixTokens.orange,
                tabs: const [
                  Tab(text: 'Форма'),
                  Tab(text: 'Просмотр'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.all(padding),
                  child: _buildFormColumn(template, filledText, payload, showButtons: false),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.all(padding),
                  child: LegalPreviewPane(
                    title: template.title,
                    previewText: filledText,
                    onBack: null,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Container(
                padding: EdgeInsets.fromLTRB(padding, 12, padding, 12),
                decoration: BoxDecoration(
                  color: AurixTokens.bg1.withValues(alpha: 0.95),
                  border: Border(top: BorderSide(color: AurixTokens.stroke())),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AurixButton(
                        text: 'Скачать PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        onPressed: _saving ? null : () async {
                          final ok = await LegalPdfService.sharePdf(
                            context: context,
                            title: template.title,
                            body: filledText,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'PDF готов' : 'Не удалось сохранить PDF')),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AurixButton(
                        text: _saving ? 'Сохранение...' : 'Сохранить',
                        icon: Icons.save_rounded,
                        onPressed: _saving ? null : () => _saveToHistory(template, filledText, payload),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ошибка загрузки шаблона', style: TextStyle(color: AurixTokens.orange)),
              const SizedBox(height: 8),
              Text(formatSupabaseError(e), style: TextStyle(color: AurixTokens.muted, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              AurixButton(text: 'Назад', onPressed: _backToList),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormColumn(LegalTemplateModel template, String filledText, Map<String, String> payload, {bool showButtons = true}) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Быстрая персонализация',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AurixTokens.orange,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          ...template.formKeys.map((key) => LegalFieldInput(
                label: key,
                controller: _formControllers[key]!,
                onChanged: (_) => setState(() {}),
              )),
          if (showButtons) ...[
            const SizedBox(height: 24),
            AurixButton(
              text: 'Скачать PDF',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: _saving ? null : () async {
                final ok = await LegalPdfService.sharePdf(
                  context: context,
                  title: template.title,
                  body: filledText,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'PDF готов' : 'Не удалось сохранить PDF')),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            AurixButton(
              text: _saving ? 'Сохранение...' : 'Сохранить в историю',
              icon: Icons.save_rounded,
              onPressed: _saving ? null : () => _saveToHistory(template, filledText, payload),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistory() {
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
                onPressed: _backToList,
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
                return _buildEmptyHistory();
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
            loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: AurixTokens.orange)),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AurixTokens.orange),
                    const SizedBox(height: 24),
                    Text('Ошибка загрузки', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AurixTokens.text)),
                    const SizedBox(height: 8),
                    Text(formatSupabaseError(e), style: TextStyle(color: AurixTokens.muted, fontSize: 12), textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AurixButton(text: 'Повторить', onPressed: () => ref.invalidate(_myDocumentsProvider)),
                        const SizedBox(width: 16),
                        AurixButton(text: 'Назад', onPressed: _backToList),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
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
            AurixButton(text: 'К каталогу', icon: Icons.arrow_back_rounded, onPressed: _backToList),
          ],
        ),
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
      debugPrint('[LegalScreen] signedPdfUrl path=${doc.filePdfPath}');
      if (url == null || !context.mounted) return;
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Открыто в браузере')));
      }
    } catch (e) {
      debugPrint('[LegalScreen] signedUrl error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${formatSupabaseError(e)}')));
      }
    }
  }

  Future<void> _open(BuildContext context) => _download(context);
}
