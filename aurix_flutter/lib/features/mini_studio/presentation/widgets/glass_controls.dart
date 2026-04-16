import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Glassmorphism bottom control panel with volume sliders.
class GlassControlsPanel extends StatelessWidget {
  final double beatVolume;
  final double vocalVolume;
  final ValueChanged<double> onBeatVolumeChanged;
  final ValueChanged<double> onVocalVolumeChanged;
  final Widget? trailing;

  const GlassControlsPanel({
    super.key,
    required this.beatVolume,
    required this.vocalVolume,
    required this.onBeatVolumeChanged,
    required this.onVocalVolumeChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AurixTokens.radiusHero),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            AurixTokens.s24,
            AurixTokens.s20,
            AurixTokens.s24,
            AurixTokens.s20 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: AurixTokens.bg1.withValues(alpha: 0.55),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AurixTokens.radiusHero),
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AurixTokens.muted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AurixTokens.s16),

              _VolumeRow(
                icon: Icons.music_note_rounded,
                label: 'Бит',
                value: beatVolume,
                color: AurixTokens.accent,
                onChanged: onBeatVolumeChanged,
              ),
              const SizedBox(height: AurixTokens.s12),
              _VolumeRow(
                icon: Icons.mic_rounded,
                label: 'Вокал',
                value: vocalVolume,
                color: AurixTokens.positive,
                onChanged: onVocalVolumeChanged,
              ),

              if (trailing != null) ...[
                const SizedBox(height: AurixTokens.s16),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  const _VolumeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: AurixTokens.s8),
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AurixTokens.fontBody,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AurixTokens.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color.withValues(alpha: 0.6),
              inactiveTrackColor: AurixTokens.surface2.withValues(alpha: 0.5),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.08),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '${(value * 100).round()}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AurixTokens.fontMono,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AurixTokens.muted,
            ),
          ),
        ),
      ],
    );
  }
}
