import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:flutter/material.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Назад',
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AurixTokens.bg1.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AurixTokens.stroke(0.24)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text, size: 20),
          ),
        ),
      ),
    );
  }
}

