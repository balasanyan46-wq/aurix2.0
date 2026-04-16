import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/mini_studio/data/web_audio_engine.dart';

/// Horizontal scrollable preset chips with smooth selection animation.
class EffectsPanel extends StatelessWidget {
  final String selectedId;
  final ValueChanged<EffectPreset> onSelect;

  const EffectsPanel({
    super.key,
    required this.selectedId,
    required this.onSelect,
  });

  static const _icons = <String, IconData>{
    'clean': Icons.graphic_eq_rounded,
    'rap': Icons.surround_sound_rounded,
    'pop': Icons.music_note_rounded,
    'autotune': Icons.auto_fix_high_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AurixTokens.s16),
        itemCount: kPresets.length,
        separatorBuilder: (_, __) => const SizedBox(width: AurixTokens.s8),
        itemBuilder: (context, i) {
          final preset = kPresets[i];
          final selected = preset.id == selectedId;
          return _PresetChip(
            label: preset.label,
            icon: _icons[preset.id] ?? Icons.tune_rounded,
            selected: selected,
            onTap: () => onSelect(preset),
          );
        },
      ),
    );
  }
}

class _PresetChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_PresetChip> createState() => _PresetChipState();
}

class _PresetChipState extends State<_PresetChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;

    return GestureDetector(
      onTapDown: (_) => _bounce.forward(),
      onTapUp: (_) {
        _bounce.reverse();
        widget.onTap();
      },
      onTapCancel: () => _bounce.reverse(),
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (context, child) {
          final scale = 1.0 - _bounce.value * 0.06;
          return Transform.scale(scale: scale, child: child);
        },
        child: AnimatedContainer(
          duration: AurixTokens.dMedium,
          curve: AurixTokens.cEase,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
            color: sel
                ? AurixTokens.accent.withValues(alpha: 0.15)
                : AurixTokens.surface1.withValues(alpha: 0.6),
            border: Border.all(
              color: sel
                  ? AurixTokens.accent.withValues(alpha: 0.5)
                  : AurixTokens.stroke(0.18),
              width: sel ? 1.5 : 1,
            ),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: AurixTokens.accent.withValues(alpha: 0.12),
                      blurRadius: 12,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: AurixTokens.dFast,
                child: Icon(
                  widget.icon,
                  key: ValueKey(sel),
                  size: 16,
                  color: sel ? AurixTokens.accent : AurixTokens.muted,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                  color: sel ? AurixTokens.text : AurixTokens.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
