import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'suggestion_model.dart';

/// Overlay that renders AI suggestion tooltips on the timeline.
class AiSuggestionsOverlay extends StatelessWidget {
  final List<AiSuggestion> suggestions;
  final double pixelsPerSecond;
  final double scrollOffset;
  final double trackAreaTop; // offset from top of stack
  final ValueChanged<AiSuggestion> onAccept;
  final ValueChanged<AiSuggestion> onDismiss;

  const AiSuggestionsOverlay({
    super.key,
    required this.suggestions,
    required this.pixelsPerSecond,
    required this.scrollOffset,
    this.trackAreaTop = 0,
    required this.onAccept,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final visible = suggestions.where((s) => !s.dismissed).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: [
          for (int i = 0; i < visible.length; i++)
            _SuggestionBubble(
              suggestion: visible[i],
              x: visible[i].position * pixelsPerSecond - scrollOffset + 140,
              y: 8 + i * 52.0, // stagger vertically
              onAccept: () => onAccept(visible[i]),
              onDismiss: () => onDismiss(visible[i]),
            ),
        ],
      ),
    );
  }
}

class _SuggestionBubble extends StatefulWidget {
  final AiSuggestion suggestion;
  final double x;
  final double y;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const _SuggestionBubble({
    required this.suggestion,
    required this.x,
    required this.y,
    required this.onAccept,
    required this.onDismiss,
  });

  @override
  State<_SuggestionBubble> createState() => _SuggestionBubbleState();
}

class _SuggestionBubbleState extends State<_SuggestionBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _slide = Tween(begin: const Offset(0, 8), end: Offset.zero).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  Color get _typeColor => switch (widget.suggestion.type) {
    SuggestionType.timing   => AurixTokens.accent,
    SuggestionType.vocal    => AurixTokens.positive,
    SuggestionType.structure => AurixTokens.warning,
    SuggestionType.mix      => AurixTokens.aiAccent,
  };

  IconData get _typeIcon => switch (widget.suggestion.type) {
    SuggestionType.timing   => Icons.straighten_rounded,
    SuggestionType.vocal    => Icons.record_voice_over_rounded,
    SuggestionType.structure => Icons.view_timeline_rounded,
    SuggestionType.mix      => Icons.tune_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = _typeColor;
    // Clamp x so bubble stays visible
    final screenW = MediaQuery.sizeOf(context).width;
    final clampedX = widget.x.clamp(4.0, screenW - 220);

    return Positioned(
      left: clampedX,
      top: widget.y,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Opacity(
          opacity: _opacity.value,
          child: Transform.translate(offset: _slide.value, child: child),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AurixTokens.bg1.withValues(alpha: 0.7),
                border: Border.all(color: c.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: c.withValues(alpha: 0.08),
                    blurRadius: 12,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Type icon
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: c.withValues(alpha: 0.12),
                    ),
                    child: Icon(_typeIcon, size: 13, color: c),
                  ),
                  const SizedBox(width: 8),

                  // Text
                  Flexible(
                    child: Text(
                      widget.suggestion.text,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AurixTokens.text,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Accept button
                  _BubbleBtn(
                    icon: Icons.check_rounded,
                    color: c,
                    onTap: widget.onAccept,
                  ),
                  const SizedBox(width: 3),

                  // Dismiss
                  _BubbleBtn(
                    icon: Icons.close_rounded,
                    color: AurixTokens.micro,
                    onTap: widget.onDismiss,
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

class _BubbleBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BubbleBtn({required this.icon, required this.color, required this.onTap});
  @override
  State<_BubbleBtn> createState() => _BubbleBtnState();
}

class _BubbleBtnState extends State<_BubbleBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _b;
  @override void initState() { super.initState();
    _b = AnimationController(vsync: this, duration: const Duration(milliseconds: 80)); }
  @override void dispose() { _b.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _b.forward(),
      onTapUp: (_) { _b.reverse(); widget.onTap(); },
      onTapCancel: () => _b.reverse(),
      child: AnimatedBuilder(
        animation: _b,
        builder: (_, c) => Transform.scale(scale: 1 - _b.value * 0.1, child: c),
        child: Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: widget.color.withValues(alpha: 0.12),
          ),
          child: Icon(widget.icon, size: 12, color: widget.color),
        ),
      ),
    );
  }
}
