import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// "+ Add Track" button with bounce animation.
class AddTrackButton extends StatefulWidget {
  final VoidCallback? onTap;
  final int currentCount;
  final int maxCount;

  const AddTrackButton({
    super.key,
    this.onTap,
    required this.currentCount,
    required this.maxCount,
  });

  @override
  State<AddTrackButton> createState() => _AddTrackButtonState();
}

class _AddTrackButtonState extends State<AddTrackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = widget.currentCount < widget.maxCount;

    return GestureDetector(
      onTapDown: canAdd ? (_) => _bounce.forward() : null,
      onTapUp: canAdd
          ? (_) {
              _bounce.reverse();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () => _bounce.reverse(),
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (_, child) =>
            Transform.scale(scale: 1.0 - _bounce.value * 0.03, child: child),
        child: AnimatedContainer(
          duration: AurixTokens.dMedium,
          height: 48,
          margin: const EdgeInsets.symmetric(
            horizontal: AurixTokens.s16,
            vertical: AurixTokens.s8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
            border: Border.all(
              color: canAdd
                  ? AurixTokens.accent.withValues(alpha: 0.2)
                  : AurixTokens.stroke(0.08),
              width: 1,
            ),
            color: canAdd
                ? AurixTokens.accent.withValues(alpha: 0.04)
                : AurixTokens.surface1.withValues(alpha: 0.15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 18,
                color: canAdd ? AurixTokens.accent : AurixTokens.micro,
              ),
              const SizedBox(width: 6),
              Text(
                canAdd
                    ? 'Добавить дорожку'
                    : 'Максимум ${widget.maxCount} дорожек',
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: canAdd
                      ? AurixTokens.accent
                      : AurixTokens.micro,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
