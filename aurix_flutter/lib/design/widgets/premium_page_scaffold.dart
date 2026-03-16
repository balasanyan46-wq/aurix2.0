import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';

/// Unified page scaffold for all internal screens.
/// Provides consistent max-width, padding, optional hero header,
/// and staggered entrance animation.
class PremiumPageScaffold extends StatelessWidget {
  const PremiumPageScaffold({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.trailing,
    this.maxWidth = 960,
    this.padding,
    this.animate = true,
    this.staggerMs = 50,
    this.heroChild,
  });

  final List<Widget> children;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final double maxWidth;
  final EdgeInsets? padding;
  final bool animate;
  final int staggerMs;
  final Widget? heroChild;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final effectivePadding =
        padding ?? EdgeInsets.fromLTRB(isDesktop ? 32 : 20, 24, isDesktop ? 32 : 20, 32);

    final header = title != null
        ? _PageHeader(
            title: title!,
            subtitle: subtitle,
            trailing: trailing,
            heroChild: heroChild,
          )
        : null;

    final allWidgets = <Widget>[
      if (header != null) header,
      ...children,
    ];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: effectivePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < allWidgets.length; i++)
                animate
                    ? FadeInSlide(
                        delayMs: i * staggerMs,
                        child: allWidgets[i],
                      )
                    : allWidgets[i],
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.heroChild,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? heroChild;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
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
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AurixTokens.muted,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                trailing!,
              ],
            ],
          ),
          if (heroChild != null) ...[
            const SizedBox(height: 16),
            heroChild!,
          ],
        ],
      ),
    );
  }
}

/// Premium error state card with retry action.
class PremiumErrorState extends StatelessWidget {
  const PremiumErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.warning_amber_rounded,
    this.title,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AurixTokens.danger.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AurixTokens.danger.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AurixTokens.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Повторить'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Premium loading state with centered skeleton or spinner.
class PremiumLoadingState extends StatelessWidget {
  const PremiumLoadingState({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AurixTokens.accent.withValues(alpha: 0.7),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Unified text input field with AURIX styling.
class PremiumTextField extends StatelessWidget {
  const PremiumTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.autofocus = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.enabled = true,
    this.obscureText = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool autofocus;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      autofocus: autofocus,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      obscureText: obscureText,
      style: const TextStyle(color: AurixTokens.text, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        // Theme-level InputDecorationTheme handles all the border styling
      ),
    );
  }
}

/// Section divider with subtle line.
class PremiumDivider extends StatelessWidget {
  const PremiumDivider({super.key, this.height = 24});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: height / 2),
      child: Divider(
        color: AurixTokens.stroke(0.12),
        height: 1,
      ),
    );
  }
}

/// Ambient glow effect — soft brand-colored blob background.
class PremiumAmbientGlow extends StatelessWidget {
  const PremiumAmbientGlow({
    super.key,
    required this.child,
    this.color,
    this.alignment = Alignment.topRight,
    this.radius = 300,
    this.opacity = 0.06,
  });

  final Widget child;
  final Color? color;
  final Alignment alignment;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: alignment,
              child: Container(
                width: radius,
                height: radius,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (color ?? AurixTokens.accent).withValues(alpha: opacity),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
