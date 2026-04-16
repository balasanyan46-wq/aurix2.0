import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'flow_model.dart';

/// Producer Flow overlay — shows current step and action button.
///
/// Appears at the top of the studio when flow is active.
/// One step at a time. After last step → "ready for release" screen.
class FlowOverlay extends StatefulWidget {
  final List<FlowStep> steps;
  final ValueChanged<FlowStep> onExecute;
  final VoidCallback onDismiss;
  final VoidCallback onRelease;
  final VoidCallback onExport;

  const FlowOverlay({
    super.key,
    required this.steps,
    required this.onExecute,
    required this.onDismiss,
    required this.onRelease,
    required this.onExport,
  });

  @override
  State<FlowOverlay> createState() => _FlowOverlayState();
}

class _FlowOverlayState extends State<FlowOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  FlowStep? get _currentStep {
    for (final s in widget.steps) {
      if (!s.completed) return s;
    }
    return null;
  }

  int get _completedCount => widget.steps.where((s) => s.completed).length;
  bool get _allDone => _currentStep == null && widget.steps.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => FadeTransition(
        opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
        child: child,
      ),
      child: _allDone ? _buildDone(context) : _buildStep(context),
    );
  }

  Widget _buildStep(BuildContext context) {
    final step = _currentStep!;
    final stepNum = _completedCount + 1;
    final total = widget.steps.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AurixTokens.s12, vertical: AurixTokens.s6),
      padding: const EdgeInsets.all(AurixTokens.s12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        color: AurixTokens.surface1.withValues(alpha: 0.6),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Step indicator
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AurixTokens.accent.withValues(alpha: 0.12),
              border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.3)),
            ),
            child: Center(child: Text(
              '$stepNum',
              style: TextStyle(
                fontFamily: AurixTokens.fontDisplay, fontSize: 14,
                fontWeight: FontWeight.w700, color: AurixTokens.accent),
            )),
          ),
          const SizedBox(width: AurixTokens.s10),

          // Text
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(step.title, style: TextStyle(
                  fontFamily: AurixTokens.fontBody, fontSize: 14,
                  fontWeight: FontWeight.w700, color: AurixTokens.text)),
                const SizedBox(width: 6),
                Text('$stepNum/$total', style: TextStyle(
                  fontFamily: AurixTokens.fontMono, fontSize: 10,
                  color: AurixTokens.micro)),
              ]),
              const SizedBox(height: 2),
              Text(step.description, style: TextStyle(
                fontFamily: AurixTokens.fontBody, fontSize: 12,
                color: AurixTokens.muted, height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          )),
          const SizedBox(width: AurixTokens.s8),

          // Action button
          _FlowBtn(
            label: step.action == FlowActions.prepareRelease ? 'Экспорт' : 'Сделать',
            onTap: () => widget.onExecute(step),
          ),

          // Dismiss
          GestureDetector(
            onTap: widget.onDismiss,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.close_rounded, size: 16, color: AurixTokens.micro),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AurixTokens.s12, vertical: AurixTokens.s6),
      padding: const EdgeInsets.all(AurixTokens.s16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        gradient: LinearGradient(
          colors: [
            AurixTokens.positive.withValues(alpha: 0.08),
            AurixTokens.accent.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AurixTokens.positive.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.check_rounded, size: 20, color: AurixTokens.positive),
            ),
            const SizedBox(width: AurixTokens.s10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Трек готов к релизу', style: TextStyle(
                  fontFamily: AurixTokens.fontDisplay, fontSize: 16,
                  fontWeight: FontWeight.w700, color: AurixTokens.text)),
                const SizedBox(height: 2),
                Text('Все шаги пройдены — звучит как надо.', style: TextStyle(
                  fontFamily: AurixTokens.fontBody, fontSize: 12, color: AurixTokens.muted)),
              ],
            )),
            GestureDetector(
              onTap: widget.onDismiss,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.close_rounded, size: 16, color: AurixTokens.micro),
              ),
            ),
          ]),
          const SizedBox(height: AurixTokens.s12),

          // Action buttons
          Row(children: [
            Expanded(child: _FlowBtn(label: 'Экспорт', onTap: widget.onExport, primary: true)),
            const SizedBox(width: 8),
            Expanded(child: _FlowBtn(label: 'Выпустить', onTap: widget.onRelease)),
            const SizedBox(width: 8),
            Expanded(child: _FlowBtn(
              label: 'Промо',
              onTap: () => context.push('/promo'),
              muted: true,
            )),
          ]),
        ],
      ),
    );
  }
}

class _FlowBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool muted;
  const _FlowBtn({required this.label, required this.onTap, this.primary = false, this.muted = false});
  @override State<_FlowBtn> createState() => _FlowBtnState();
}

class _FlowBtnState extends State<_FlowBtn> with SingleTickerProviderStateMixin {
  late AnimationController _b;
  @override void initState() { super.initState();
    _b = AnimationController(vsync: this, duration: const Duration(milliseconds: 100)); }
  @override void dispose() { _b.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.primary ? AurixTokens.accent
        : widget.muted ? AurixTokens.muted : AurixTokens.positive;
    return GestureDetector(
      onTapDown: (_) => _b.forward(),
      onTapUp: (_) { _b.reverse(); widget.onTap(); },
      onTapCancel: () => _b.reverse(),
      child: AnimatedBuilder(
        animation: _b,
        builder: (_, c) => Transform.scale(scale: 1 - _b.value * 0.04, child: c),
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
            color: widget.primary ? color : color.withValues(alpha: 0.1),
            border: widget.primary ? null : Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Text(widget.label, style: TextStyle(
            fontFamily: AurixTokens.fontBody, fontSize: 12,
            fontWeight: FontWeight.w700,
            color: widget.primary ? Colors.white : color)),
        ),
      ),
    );
  }
}
