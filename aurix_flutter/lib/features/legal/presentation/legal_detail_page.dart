import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/features/legal/data/legal_template_model.dart';
import 'package:aurix_flutter/features/legal/presentation/widgets/legal_preview_pane.dart';
import 'package:aurix_flutter/features/legal/presentation/widgets/legal_field_input.dart';
import 'package:aurix_flutter/features/legal/services/legal_pdf_service.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

final _templateProvider = FutureProvider.family<LegalTemplateModel?, String>((ref, id) async {
  final repo = ref.watch(legalRepositoryProvider);
  return repo.getTemplateById(id);
});

class LegalDetailPage extends ConsumerStatefulWidget {
  final String templateId;

  const LegalDetailPage({super.key, required this.templateId});

  @override
  ConsumerState<LegalDetailPage> createState() => _LegalDetailPageState();
}

class _LegalDetailPageState extends ConsumerState<LegalDetailPage> {
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;
  String? _initializedTemplateId;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers(LegalTemplateModel t, Map<String, String>? profileDefaults) {
    if (_initializedTemplateId == t.id) return;
    _initializedTemplateId = t.id;
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    for (final key in t.formKeys) {
      String initial = '';
      if (profileDefaults != null && profileDefaults[key] != null) {
        initial = profileDefaults[key]!;
      }
      _controllers[key] = TextEditingController(text: initial);
    }
  }

  String _filledText(LegalTemplateModel t) {
    var text = t.body;
    for (final e in _controllers.entries) {
      text = text.replaceAll('{{${e.key}}}', e.value.text.trim().isEmpty ? '__________' : e.value.text.trim());
    }
    text = text.replaceAllMapped(RegExp(r'\{\{([A-Z_0-9]+)\}\}'), (_) => '__________');
    return text;
  }

  Map<String, String> _payload() {
    final m = <String, String>{};
    for (final e in _controllers.entries) {
      m[e.key] = e.value.text.trim();
    }
    return m;
  }

  Future<void> _saveToHistory(
    BuildContext context,
    WidgetRef ref,
    LegalTemplateModel template,
    String filledText,
    Map<String, String> payload,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(legalRepositoryProvider);
      final doc = await repo.createDocumentRecord(template: template, payload: payload);
      debugPrint('[LegalDetail] createDocumentRecord templateId=${template.id} documentId=${doc.id}');
      final bytes = await LegalPdfService.generatePdfBytes(title: template.title, body: filledText);
      final path = await repo.uploadPdf(user.id, doc.id, bytes);
      debugPrint('[LegalDetail] uploadPdf path=$path');
      await repo.updateDocumentPdfPath(doc.id, path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено в историю')));
        context.go('/legal/history');
      }
    } catch (e) {
      debugPrint('[LegalDetail] saveToHistory error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${formatSupabaseError(e)}')),
        );
      }
    } finally {
      if (context.mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncTemplate = ref.watch(_templateProvider(widget.templateId));
    final profileAsync = ref.watch(currentProfileProvider);

    return asyncTemplate.when(
      data: (template) {
        if (template == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/legal'));
          return const Center(child: CircularProgressIndicator(color: AurixTokens.orange));
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
        _initControllers(template, profileDefaults);

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
                    previewText: _filledText(template),
                    onBack: () => context.go('/legal'),
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: 320,
                  child: _FormColumn(
                    template: template,
                    filledText: _filledText(template),
                    payload: _payload(),
                    saving: _saving,
                    onSavingChange: (v) => setState(() => _saving = v),
                    controllers: _controllers,
                    onChanged: () => setState(() {}),
                    showButtons: true,
                    onSaveToHistory: null,
                  ),
                ),
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
                onPressed: () => context.go('/legal'),
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
                  child: _FormColumn(
                    template: template,
                    filledText: _filledText(template),
                    payload: _payload(),
                    saving: _saving,
                    onSavingChange: (v) => setState(() => _saving = v),
                    controllers: _controllers,
                    onChanged: () => setState(() {}),
                    showButtons: false,
                    onSaveToHistory: null,
                  ),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.all(padding),
                  child: LegalPreviewPane(
                    title: template.title,
                    previewText: _filledText(template),
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
                            body: _filledText(template),
                          );
                          if (context.mounted) {
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
                        onPressed: _saving ? null : () => _saveToHistory(context, ref, template, _filledText(template), _payload()),
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
              AurixButton(text: 'Назад', onPressed: () => context.go('/legal')),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormColumn extends ConsumerWidget {
  final LegalTemplateModel template;
  final String filledText;
  final Map<String, String> payload;
  final bool saving;
  final ValueChanged<bool> onSavingChange;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onChanged;
  final bool showButtons;
  final VoidCallback? onSaveToHistory;

  const _FormColumn({
    required this.template,
    required this.filledText,
    required this.payload,
    required this.saving,
    required this.onSavingChange,
    required this.controllers,
    required this.onChanged,
    this.showButtons = true,
    this.onSaveToHistory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                controller: controllers[key]!,
                onChanged: (_) => onChanged(),
              )),
          if (showButtons) ...[
            const SizedBox(height: 24),
            AurixButton(
              text: 'Скачать PDF',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: saving ? null : () async {
                final ok = await LegalPdfService.sharePdf(
                  context: context,
                  title: template.title,
                  body: filledText,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'PDF готов' : 'Не удалось сохранить PDF')),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            AurixButton(
              text: saving ? 'Сохранение...' : 'Сохранить в историю',
              icon: Icons.save_rounded,
              onPressed: saving ? null : () => _saveToHistory(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveToHistory(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      return;
    }
    onSavingChange(true);
    try {
      final repo = ref.read(legalRepositoryProvider);
      final doc = await repo.createDocumentRecord(template: template, payload: payload);
      debugPrint('[LegalDetail] createDocumentRecord templateId=${template.id} documentId=${doc.id}');
      final bytes = await LegalPdfService.generatePdfBytes(title: template.title, body: filledText);
      final path = await repo.uploadPdf(user.id, doc.id, bytes);
      debugPrint('[LegalDetail] uploadPdf path=$path');
      await repo.updateDocumentPdfPath(doc.id, path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено в историю')));
        context.go('/legal/history');
      }
    } catch (e) {
      debugPrint('[LegalDetail] saveToHistory error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${formatSupabaseError(e)}')),
        );
      }
    } finally {
      onSavingChange(false);
    }
  }
}
