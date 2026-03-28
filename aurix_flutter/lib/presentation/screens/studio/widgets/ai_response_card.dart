import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

class AiResponseCard extends StatefulWidget {
  final String content;
  final Color accent;
  final String characterName;

  const AiResponseCard({
    super.key,
    required this.content,
    required this.accent,
    required this.characterName,
  });

  @override
  State<AiResponseCard> createState() => _AiResponseCardState();
}

class _AiResponseCardState extends State<AiResponseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Скопировано'),
        backgroundColor: AurixTokens.bg2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.accent.withValues(alpha: 0.06),
                AurixTokens.bg2.withValues(alpha: 0.25),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.accent.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.05),
                blurRadius: 24,
                spreadRadius: -8,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.accent.withValues(alpha: 0.15),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, size: 13, color: widget.accent),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.characterName,
                  style: TextStyle(
                    color: widget.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _copy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AurixTokens.glass(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AurixTokens.stroke(0.08)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.copy_rounded, size: 13, color: AurixTokens.muted),
                      const SizedBox(width: 4),
                      Text('Копировать', style: TextStyle(color: AurixTokens.muted, fontSize: 11)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // Content — render sections
              _RichContent(content: widget.content, accent: widget.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders markdown-like bold headers and plain text.
class _RichContent extends StatelessWidget {
  final String content;
  final Color accent;

  const _RichContent({required this.content, required this.accent});

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Bold header: **text**
      final headerMatch = RegExp(r'^\*\*(.+?)\*\*$').firstMatch(trimmed);
      if (headerMatch != null) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
        widgets.add(Text(
          headerMatch.group(1)!,
          style: TextStyle(
            color: accent,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ));
        widgets.add(const SizedBox(height: 4));
        continue;
      }

      // Section header [text]
      final sectionMatch = RegExp(r'^\[(.+?)\]$').firstMatch(trimmed);
      if (sectionMatch != null) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
        widgets.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            sectionMatch.group(1)!,
            style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ));
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Regular text
      widgets.add(Text(
        trimmed,
        style: TextStyle(color: AurixTokens.text.withValues(alpha: 0.9), fontSize: 14, height: 1.55),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}
