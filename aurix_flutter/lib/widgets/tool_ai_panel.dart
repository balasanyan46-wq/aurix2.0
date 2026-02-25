import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/services/ai_chat_service.dart';
import 'package:aurix_flutter/tools/tools_registry.dart';

class ToolAiPanel extends StatefulWidget {
  final ToolDefinition tool;
  final Map<String, dynamic> Function() buildFormData;

  const ToolAiPanel({
    super.key,
    required this.tool,
    required this.buildFormData,
  });

  @override
  State<ToolAiPanel> createState() => _ToolAiPanelState();
}

class _ToolAiPanelState extends State<ToolAiPanel> {
  final _service = AiChatService();

  bool _loading = false;
  String? _error;
  String? _reply;
  String? _quick;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final formData = <String, dynamic>{
        ...widget.buildFormData(),
        if (_quick != null) 'quickPrompt': _quick,
      };
      final message = widget.tool.buildMessage(formData);
      final reply = await _service.send(message: message, history: const []);
      if (!mounted) return;
      setState(() {
        _reply = reply;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _copy() async {
    if (_reply == null || _reply!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _reply!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано')));
  }

  void _clear() {
    setState(() {
      _error = null;
      _reply = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              if (_reply != null) ...[
                TextButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Скопировать'),
                ),
                TextButton(
                  onPressed: _clear,
                  child: const Text('Очистить'),
                ),
              ],
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
                  onSelected: (v) => setState(() => _quick = v ? p : null),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _generate,
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.orange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text('Сгенерировать'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AurixTokens.text, fontSize: 13, height: 1.35),
              ),
            ),
          ],
          if (_reply != null) ...[
            const SizedBox(height: 12),
            Text('AI-результат', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AurixTokens.bg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AurixTokens.stroke(0.12)),
              ),
              child: SelectableText(
                _reply!,
                style: const TextStyle(color: AurixTokens.text, fontSize: 13.5, height: 1.45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

