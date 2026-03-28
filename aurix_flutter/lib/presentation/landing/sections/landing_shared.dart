import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

// ── Responsive helpers ──────────────────────────────────────────

bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= 960;
bool isNarrow(BuildContext context) => MediaQuery.sizeOf(context).width < 720;

// ── Section wrapper ─────────────────────────────────────────────

class LandingSection extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double maxWidth;
  const LandingSection({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = 1140,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Padding(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: desktop ? 40 : 20,
            vertical: desktop ? 72 : 48,
          ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

// ── Section label ───────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const SectionLabel({super.key, required this.text, this.color = AurixTokens.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        color: color.withValues(alpha: 0.06),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

// ── Gradient headline helper ────────────────────────────────────

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final List<Color> colors;
  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.center,
    this.colors = const [AurixTokens.accent, AurixTokens.aiAccent],
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(colors: colors).createShader(bounds),
      child: Text(
        text,
        textAlign: textAlign,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}

// ── Primary CTA button ──────────────────────────────────────────

class PrimaryCta extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final double? width;
  const PrimaryCta({super.key, required this.label, required this.onTap, this.width});

  @override
  State<PrimaryCta> createState() => _PrimaryCtaState();
}

class _PrimaryCtaState extends State<PrimaryCta> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: _hover
                  ? [AurixTokens.accent, AurixTokens.accentWarm]
                  : [AurixTokens.accent, AurixTokens.accentMuted],
            ),
            boxShadow: [
              BoxShadow(
                color: AurixTokens.accent.withValues(alpha: _hover ? 0.35 : 0.18),
                blurRadius: _hover ? 28 : 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Outline CTA button ──────────────────────────────────────────

class OutlineCta extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const OutlineCta({super.key, required this.label, required this.onTap});

  @override
  State<OutlineCta> createState() => _OutlineCtaState();
}

class _OutlineCtaState extends State<OutlineCta> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover
                  ? AurixTokens.text.withValues(alpha: 0.3)
                  : AurixTokens.text.withValues(alpha: 0.14),
            ),
            color: _hover ? AurixTokens.text.withValues(alpha: 0.04) : Colors.transparent,
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _hover ? AurixTokens.text : AurixTokens.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Glass card ──────────────────────────────────────────────────

class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _hover ? AurixTokens.surface2 : AurixTokens.surface1,
            border: Border.all(
              color: _hover
                  ? AurixTokens.accent.withValues(alpha: 0.18)
                  : AurixTokens.stroke(0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? 0.4 : 0.25),
                blurRadius: _hover ? 20 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Split canvas layout ─────────────────────────────────────────

class SplitCanvas extends StatelessWidget {
  final Widget left;
  final Widget right;
  final bool reversed;
  final double gap;
  final double leftFlex;
  final double rightFlex;
  const SplitCanvas({
    super.key,
    required this.left,
    required this.right,
    this.reversed = false,
    this.gap = 56,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    if (!desktop) {
      return Column(
        children: reversed ? [right, SizedBox(height: gap * 0.7), left] : [left, SizedBox(height: gap * 0.7), right],
      );
    }
    final a = reversed ? right : left;
    final b = reversed ? left : right;
    final flexA = reversed ? rightFlex : leftFlex;
    final flexB = reversed ? leftFlex : rightFlex;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: (flexA * 10).round(), child: a),
        SizedBox(width: gap),
        Expanded(flex: (flexB * 10).round(), child: b),
      ],
    );
  }
}

// ── Mock UI panel (simulated product UI) ────────────────────────

class MockUIPanel extends StatelessWidget {
  final Widget child;
  final String? title;
  const MockUIPanel({super.key, required this.child, this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AurixTokens.surface1,
        border: Border.all(color: AurixTokens.stroke(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AurixTokens.stroke(0.08))),
            ),
            child: Row(
              children: [
                // macOS dots
                Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFF5F57))),
                const SizedBox(width: 6),
                Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFBD2E))),
                const SizedBox(width: 6),
                Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF27C93F))),
                if (title != null) ...[
                  const SizedBox(width: 16),
                  Text(title!, style: TextStyle(color: AurixTokens.micro, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Terminal panel (AI output simulation) ────────────────────────

class TerminalPanel extends StatelessWidget {
  final List<TerminalLine> lines;
  const TerminalPanel({super.key, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0A0A12),
        border: Border.all(color: AurixTokens.stroke(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AurixTokens.stroke(0.06))),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal_rounded, color: AurixTokens.accent.withValues(alpha: 0.6), size: 14),
                const SizedBox(width: 8),
                Text('AURIX AI', style: TextStyle(color: AurixTokens.micro, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.prefix,
                          style: TextStyle(
                            color: line.prefixColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            fontFamilyFallback: const ['Courier'],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            line.text,
                            style: TextStyle(
                              color: line.textColor,
                              fontSize: 12.5,
                              height: 1.5,
                              fontFamily: 'monospace',
                              fontFamilyFallback: const ['Courier'],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TerminalLine {
  final String prefix;
  final String text;
  final Color prefixColor;
  final Color textColor;
  const TerminalLine({
    required this.prefix,
    required this.text,
    this.prefixColor = AurixTokens.accent,
    this.textColor = AurixTokens.textSecondary,
  });
}

// ── Animated metric bar ─────────────────────────────────────────

class MetricBar extends StatelessWidget {
  final String label;
  final String value;
  final double fill;
  final Color color;
  const MetricBar({super.key, required this.label, required this.value, required this.fill, this.color = AurixTokens.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w500)),
            Text(value, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: AurixTokens.stroke(0.08),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fill.clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.6)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Timeline flow ───────────────────────────────────────────────

class TimelineFlow extends StatelessWidget {
  final List<TimelineStep> steps;
  const TimelineFlow({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    if (desktop) {
      return Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(child: _TimelineNode(step: steps[i], index: i)),
            if (i < steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AurixTokens.accent.withValues(alpha: 0.4),
                        AurixTokens.aiAccent.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          _TimelineNodeVertical(step: steps[i], index: i, isLast: i == steps.length - 1),
        ],
      ],
    );
  }
}

class TimelineStep {
  final IconData icon;
  final String label;
  final String description;
  const TimelineStep({required this.icon, required this.label, required this.description});
}

class _TimelineNode extends StatelessWidget {
  final TimelineStep step;
  final int index;
  const _TimelineNode({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AurixTokens.accent.withValues(alpha: 0.15),
                AurixTokens.aiAccent.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.3)),
          ),
          child: Icon(step.icon, color: AurixTokens.accent, size: 24),
        ),
        const SizedBox(height: 14),
        Text(
          step.label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          step.description,
          textAlign: TextAlign.center,
          style: TextStyle(color: AurixTokens.muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

class _TimelineNodeVertical extends StatelessWidget {
  final TimelineStep step;
  final int index;
  final bool isLast;
  const _TimelineNodeVertical({required this.step, required this.index, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line + dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AurixTokens.accent.withValues(alpha: 0.15), AurixTokens.aiAccent.withValues(alpha: 0.10)],
                    ),
                    border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(step.icon, color: AurixTokens.accent, size: 18),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AurixTokens.accent.withValues(alpha: 0.15),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(step.label, style: const TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(step.description, style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
