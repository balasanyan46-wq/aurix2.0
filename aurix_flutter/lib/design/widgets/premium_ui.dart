import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:flutter/material.dart';

class PremiumSectionCard extends StatelessWidget {
  const PremiumSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AurixTokens.bg1.withValues(alpha: 0.97),
            AurixTokens.bg2.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(color: AurixTokens.stroke(0.24)),
        boxShadow: [...AurixTokens.subtleShadow],
      ),
      child: child,
    );
  }
}

class PremiumSectionHeader extends StatelessWidget {
  const PremiumSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AurixTokens.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AurixTokens.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class PremiumStatusPill extends StatelessWidget {
  const PremiumStatusPill({
    super.key,
    required this.label,
    required this.status,
  });

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'submitted' => Colors.blueAccent,
      'under_review' => AurixTokens.warning,
      'approved' => AurixTokens.positive,
      'rejected' => AurixTokens.danger,
      'in_progress' => AurixTokens.orange,
      'completed' => AurixTokens.positive,
      'warning' => AurixTokens.warning,
      'positive' => AurixTokens.positive,
      _ => AurixTokens.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PremiumMetricTile extends StatelessWidget {
  const PremiumMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AurixTokens.muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? AurixTokens.text,
              fontSize: compact ? 14 : 18.5,
              fontWeight: FontWeight.w800,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_rounded,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 26, color: AurixTokens.muted),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class PremiumHoverLift extends StatefulWidget {
  const PremiumHoverLift({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<PremiumHoverLift> createState() => _PremiumHoverLiftState();
}

class _PremiumHoverLiftState extends State<PremiumHoverLift> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final translateY = _pressed
        ? 0.0
        : (_hovered ? -1.5 : 0.0);
    final scale = _pressed ? 0.995 : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, translateY, 0.0, 1.0)
            ..scaleByDouble(scale, scale, 1.0, 1.0),
          child: widget.child,
        ),
      ),
    );
  }
}

class PremiumSkeletonBox extends StatefulWidget {
  const PremiumSkeletonBox({
    super.key,
    this.height = 14,
    this.width,
    this.radius = 8,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<PremiumSkeletonBox> createState() => _PremiumSkeletonBoxState();
}

class _PremiumSkeletonBoxState extends State<PremiumSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);
  late final Animation<double> _alpha = Tween<double>(begin: 0.16, end: 0.28).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _alpha,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AurixTokens.text.withValues(alpha: _alpha.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

class PremiumPageContainer extends StatelessWidget {
  const PremiumPageContainer({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 28),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

class PremiumHeroBlock extends StatelessWidget {
  const PremiumHeroBlock({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.pills = const [],
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<Widget> pills;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      radius: AurixTokens.radiusHero,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AurixTokens.text,
                        fontSize: 34,
                        height: 1.06,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AurixTokens.textSecondary,
                        height: 1.55,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                trailing!,
              ],
            ],
          ),
          if (pills.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: pills),
          ],
        ],
      ),
    );
  }
}

class PremiumChip extends StatelessWidget {
  const PremiumChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AurixTokens.accent.withValues(alpha: 0.2)
            : AurixTokens.bg2.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
        border: Border.all(
          color: selected
              ? AurixTokens.accent.withValues(alpha: 0.42)
              : AurixTokens.stroke(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 13,
              color: selected ? AurixTokens.accentWarm : AurixTokens.muted,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected ? AurixTokens.text : AurixTokens.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumSegmentedControl<T> extends StatelessWidget {
  const PremiumSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T value, String label)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AurixTokens.bg2.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
        border: Border.all(color: AurixTokens.stroke(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((entry) {
          final active = entry.$1 == selected;
          return GestureDetector(
            onTap: () => onSelected(entry.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: active
                    ? AurixTokens.accent.withValues(alpha: 0.22)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AurixTokens.radiusChip - 3),
              ),
              child: Text(
                entry.$2,
                style: TextStyle(
                  color: active ? AurixTokens.text : AurixTokens.muted,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class PremiumCta extends StatelessWidget {
  const PremiumCta.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  }) : variant = _PremiumCtaVariant.primary;

  const PremiumCta.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  }) : variant = _PremiumCtaVariant.secondary;

  const PremiumCta.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  }) : variant = _PremiumCtaVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final _PremiumCtaVariant variant;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      _PremiumCtaVariant.primary => FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon ?? Icons.auto_awesome_rounded, size: 16),
          label: Text(label),
        ),
      _PremiumCtaVariant.secondary => OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon ?? Icons.tune_rounded, size: 16),
          label: Text(label),
        ),
      _PremiumCtaVariant.ghost => TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon ?? Icons.chevron_right_rounded, size: 16),
          label: Text(label),
        ),
    };
  }
}

enum _PremiumCtaVariant { primary, secondary, ghost }
