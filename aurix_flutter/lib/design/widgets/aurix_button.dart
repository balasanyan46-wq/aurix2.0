import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:flutter/material.dart';

/// Premium CTA with restrained gradient and subtle interactions.
class AurixButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  const AurixButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
  });

  @override
  State<AurixButton> createState() => _AurixButtonState();
}

class _AurixButtonState extends State<AurixButton> with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) => setState(() => _pressing = false),
        onTapCancel: () => setState(() => _pressing = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressing ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _hover
                    ? [
                        AurixTokens.accentWarm.withValues(alpha: enabled ? 0.95 : 0.45),
                        AurixTokens.accent.withValues(alpha: enabled ? 0.95 : 0.45),
                      ]
                    : [
                        AurixTokens.accent.withValues(alpha: enabled ? 0.9 : 0.35),
                        AurixTokens.accentMuted.withValues(alpha: enabled ? 0.9 : 0.35),
                      ],
              ),
              borderRadius: BorderRadius.circular(AurixTokens.radiusButton),
              border: Border.all(
                color: Colors.white.withValues(alpha: enabled ? 0.12 : 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: AurixTokens.accentGlow.withValues(
                    alpha: enabled ? (_hover ? 0.25 : 0.16) : 0.0,
                  ),
                  blurRadius: _hover ? 22 : 14,
                  spreadRadius: -6,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 20,
                    color: Colors.white.withValues(alpha: enabled ? 0.95 : 0.5),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: enabled ? 0.95 : 0.5),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
