import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/services/ai_chat_service.dart';
import 'package:aurix_flutter/tools/tools_registry.dart';
import 'package:aurix_flutter/widgets/animated_ai_result_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/ai/ai_persistence_guard.dart';

class ToolAiPanel extends ConsumerStatefulWidget {
  final ToolDefinition tool;
  final Map<String, dynamic> Function() buildFormData;

  const ToolAiPanel({
    super.key,
    required this.tool,
    required this.buildFormData,
  });

  @override
  ConsumerState<ToolAiPanel> createState() => _ToolAiPanelState();
}

class _ToolAiPanelState extends ConsumerState<ToolAiPanel> {
  final _service = AiChatService();

  String? _quick;
  bool _sheetOpen = false;
  bool _loadedSaved = false;

  late final ValueNotifier<_AiPanelVm> _vm = ValueNotifier(const _AiPanelVm());

  Future<void> _generate() async {
    _openResultSheet();
    _vm.value = _vm.value.copyWith(isLoading: true, clearError: true);
    try {
      final formData = <String, dynamic>{
        ...widget.buildFormData(),
        if (_quick != null) 'quickPrompt': _quick,
      };
      final message = widget.tool.buildMessage(formData);
      final reply = await _service.send(message: message, history: const []);
      if (!mounted) return;
      _vm.value = _vm.value.copyWith(isLoading: false, markdownText: reply, clearError: true);
      await _persistRun(formData: formData, reply: reply, error: null);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      _vm.value = _vm.value.copyWith(isLoading: false, errorText: msg);
      try {
        final formData = <String, dynamic>{
          ...widget.buildFormData(),
          if (_quick != null) 'quickPrompt': _quick,
        };
        await _persistRun(formData: formData, reply: null, error: msg);
      } catch (_) {}
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedSaved) return;
    _loadedSaved = true;
    unawaited(_loadLatestSaved());
  }

  Future<void> _loadLatestSaved() async {
    try {
      final base = widget.buildFormData();
      final res = _extractResource(base);
      final toolId = widget.tool.id.name;
      final saved = await ref.read(aiToolResultsRepositoryProvider).getLatestResult(
            toolId: toolId,
            resourceType: res.$1,
            resourceId: res.$2,
          );
      if (!mounted) return;
      if (saved != null && saved.trim().isNotEmpty) {
        _vm.value = _vm.value.copyWith(markdownText: saved);
      }
    } on AiSchemaMissingException {
      // migrations not applied yet - ignore
    } catch (_) {}
  }

  Future<void> _persistRun({required Map<String, dynamic> formData, required String? reply, required String? error}) async {
    final repo = ref.read(aiToolResultsRepositoryProvider);
    final toolId = widget.tool.id.name;
    final res = _extractResource(formData);
    try {
      await repo.saveRun(
        toolId: toolId,
        resourceType: res.$1,
        resourceId: res.$2,
        input: formData,
        quickPrompt: _quick,
        resultMarkdown: reply,
        errorText: error,
      );
    } on AiSchemaMissingException {
      // migrations not applied yet - ignore (no crash)
    } catch (e) {
      debugPrint('[ToolAiPanel] persist error: ${formatSupabaseError(e)}');
    }
  }

  Future<void> _copy() async {
    final t = _vm.value.markdownText;
    if (t == null || t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано')));
  }

  void _clear() {
    _vm.value = const _AiPanelVm();
  }

  void _openResultSheet() {
    if (_sheetOpen) return;
    _sheetOpen = true;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) {
        final inset = MediaQuery.viewInsetsOf(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: inset.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.86,
            minChildSize: 0.55,
            maxChildSize: 0.96,
            builder: (ctx, scrollCtrl) {
              return Container(
                decoration: BoxDecoration(
                  color: AurixTokens.bg1,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border.all(color: AurixTokens.stroke(0.18)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AurixTokens.muted.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: AurixTokens.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.tool.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: AurixTokens.muted,
                            tooltip: 'Закрыть',
                          ),
                        ],
                      ),
                    ),
                    if (widget.tool.subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 14, right: 14, bottom: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(widget.tool.subtitle, style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12)),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        children: [
                          ValueListenableBuilder<_AiPanelVm>(
                            valueListenable: _vm,
                            builder: (context, v, _) {
                              return AnimatedAiResultPanel(
                                isLoading: v.isLoading,
                                errorText: v.errorText,
                                markdownText: v.markdownText,
                                onCopy: _copy,
                                onClear: _clear,
                                onRetry: _generate,
                                enableTypewriter: true,
                                enableStaggerSections: true,
                                showHeader: false,
                                motivations: const [
                                  'Собираем план, который реально можно сделать.',
                                  'Делаем шаги короткими и выполнимыми.',
                                  'Сейчас будет структурно: что делать и как измерять.',
                                  'Собираем чек-лист, чтобы не терять фокус.',
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      _sheetOpen = false;
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasReply = _vm.value.markdownText != null && _vm.value.markdownText!.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.stroke(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AurixTokens.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.tool.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (hasReply)
                TextButton(
                  onPressed: _openResultSheet,
                  child: const Text('Открыть результат'),
                ),
            ],
          ),
          if (widget.tool.subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(widget.tool.subtitle, style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
          ],
          if (widget.tool.quickPrompts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: widget.tool.quickPrompts.map((p) {
                final selected = _quick == p;
                return ChoiceChip(
                  label: Text(p),
                  selected: selected,
                  onSelected: _loading ? null : (v) => setState(() => _quick = v ? p : null),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _vm.value.isLoading ? null : _generate,
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.orange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: _vm.value.isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text('Сгенерировать'),
          ),
          if (hasReply) ...[
            const SizedBox(height: 10),
            Text(
              'Результат готов — открой окно выше.',
              style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

@immutable
class _AiPanelVm {
  final bool isLoading;
  final String? errorText;
  final String? markdownText;
  const _AiPanelVm({this.isLoading = false, this.errorText, this.markdownText});

  _AiPanelVm copyWith({
    bool? isLoading,
    String? errorText,
    bool clearError = false,
    String? markdownText,
    bool clearMarkdown = false,
  }) {
    return _AiPanelVm(
      isLoading: isLoading ?? this.isLoading,
      errorText: clearError ? null : (errorText ?? this.errorText),
      markdownText: clearMarkdown ? null : (markdownText ?? this.markdownText),
    );
  }
}

// Returns (resourceType, resourceId)
(String, String?) _extractResource(Map<String, dynamic> formData) {
  try {
    final track = formData['track'];
    if (track is Map && track['id'] != null) {
      return ('track', track['id'].toString());
    }
  } catch (_) {}
  try {
    final release = formData['release'];
    if (release is Map && release['id'] != null) {
      return ('release', release['id'].toString());
    }
  } catch (_) {}
  return ('other', null);
}

