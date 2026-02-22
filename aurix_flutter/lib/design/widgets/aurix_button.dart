import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Premium orange gradient button with glow, hover scale, press micro-interaction.
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
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) => setState(() => _pressing = false),
        onTapCancel: () => setState(() => _pressing = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressing ? 0.98 : 1.0,
          duration: Duration(milliseconds: _pressing ? 80 : 200),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _hover
                    ? [AurixTokens.orange, AurixTokens.orange2]
                    : [AurixTokens.orange2, AurixTokens.orange],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                if (_hover)
                  BoxShadow(
                    color: AurixTokens.orange.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20, color: Colors.black),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    widget.text,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
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
