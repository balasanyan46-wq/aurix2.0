import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:flutter/material.dart';

class PremiumSectionCard extends StatelessWidget {
  const PremiumSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
    this.glowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: AurixTokens.cardGradient,
        border: Border.all(color: AurixTokens.stroke(0.22)),
        boxShadow: [
          ...AurixTokens.subtleShadow,
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.12),
              blurRadius: 40,
              spreadRadius: -16,
              offset: const Offset(0, 8),
            ),
        ],
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
                style: TextStyle(
                  fontFamily: AurixTokens.fontHeading,
                  color: AurixTokens.text,
                  fontSize: 16,
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
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.38)),
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
    this.icon,
    this.trend,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool compact;
  final IconData? icon;
  final double? trend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: AurixTokens.surface1.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        border: Border.all(color: AurixTokens.stroke(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: AurixTokens.muted),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AurixTokens.fontBody,
                    color: AurixTokens.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (trend != null)
                _TrendIndicator(value: trend!),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AurixTokens.fontMono,
              color: valueColor ?? AurixTokens.text,
              fontSize: compact ? 15 : 20,
              fontWeight: FontWeight.w700,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendIndicator extends StatelessWidget {
  const _TrendIndicator({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final color = isPositive ? AurixTokens.positive : AurixTokens.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${isPositive ? '+' : ''}${value.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AurixTokens.surface1.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        border: Border.all(color: AurixTokens.stroke(0.12)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AurixTokens.muted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: AurixTokens.muted),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontFamily: AurixTokens.fontHeading,
              color: AurixTokens.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 12, height: 1.4),
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
        : (_hovered ? -2.0 : 0.0);
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
          duration: AurixTokens.dFast,
          curve: AurixTokens.cEase,
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
  late final Animation<double> _alpha = Tween<double>(begin: 0.08, end: 0.2).animate(
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
      padding: const EdgeInsets.all(28),
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
                      style: TextStyle(
                        fontFamily: AurixTokens.fontHeading,
                        color: AurixTokens.text,
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AurixTokens.textSecondary,
                        height: 1.55,
                        fontSize: 14,
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
            const SizedBox(height: 16),
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
            ? AurixTokens.accent.withValues(alpha: 0.18)
            : AurixTokens.surface1.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
        border: Border.all(
          color: selected
              ? AurixTokens.accent.withValues(alpha: 0.36)
              : AurixTokens.stroke(0.18),
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
              fontFamily: AurixTokens.fontBody,
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
        color: AurixTokens.surface1.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
        border: Border.all(color: AurixTokens.stroke(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((entry) {
          final active = entry.$1 == selected;
          return GestureDetector(
            onTap: () => onSelected(entry.$1),
            child: AnimatedContainer(
              duration: AurixTokens.dMedium,
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
                  fontFamily: AurixTokens.fontBody,
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
