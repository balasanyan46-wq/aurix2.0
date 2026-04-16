import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../../domain/track_model.dart';

/// Effects strip panel — preset chips + intensity slider + AI action buttons.
/// Appears at the bottom when a track is selected.
class EffectsStrip extends StatelessWidget {
  final StudioTrack track;
  final ValueChanged<bool> onFxToggle;
  final ValueChanged<FxPresetId> onPresetChanged;
  final ValueChanged<double> onIntensityChanged;
  final VoidCallback onAiAlign;
  final VoidCallback onAiDouble;
  final VoidCallback onAiEnhance;
  final VoidCallback? onAiAutoMix;
  final VoidCallback? onAiProcess;
  final ValueChanged<bool>? onAutotuneToggle;
  final ValueChanged<double>? onAutotuneStrength;
  final ValueChanged<MusicalKey>? onAutotuneKey;

  const EffectsStrip({
    super.key,
    required this.track,
    required this.onFxToggle,
    required this.onPresetChanged,
    required this.onIntensityChanged,
    required this.onAiAlign,
    required this.onAiDouble,
    required this.onAiEnhance,
    this.onAiAutoMix,
    this.onAiProcess,
    this.onAutotuneToggle,
    this.onAutotuneStrength,
    this.onAutotuneKey,
  });

  @override
  Widget build(BuildContext context) {
    final fx = track.fx;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AurixTokens.radiusCard)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            AurixTokens.s16, AurixTokens.s12,
            AurixTokens.s16, AurixTokens.s12 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: AurixTokens.bg1.withValues(alpha: 0.65),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AurixTokens.radiusCard)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: track name + FX toggle
              Row(
                children: [
                  Text(
                    'FX: ${track.name}',
                    style: TextStyle(
                      fontFamily: AurixTokens.fontBody,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AurixTokens.text,
                    ),
                  ),
                  const SizedBox(width: AurixTokens.s8),
                  _FxToggle(on: fx.enabled, onChanged: onFxToggle),
                  const Spacer(),
                  // AI buttons
                  _AiChip(label: 'Выровнять', icon: Icons.straighten_rounded, onTap: onAiAlign),
                  const SizedBox(width: 6),
                  _AiChip(label: 'Дабл', icon: Icons.content_copy_rounded, onTap: onAiDouble),
                  const SizedBox(width: 6),
                  _AiChip(label: 'Улучшить', icon: Icons.auto_awesome_rounded, onTap: onAiEnhance, primary: true),
                  if (onAiAutoMix != null) ...[
                    const SizedBox(width: 6),
                    _AiChip(label: 'Автомикс', icon: Icons.tune_rounded, onTap: onAiAutoMix!),
                  ],
                  if (onAiProcess != null) ...[
                    const SizedBox(width: 6),
                    _AiChip(label: 'AI обработка', icon: Icons.science_rounded, onTap: onAiProcess!),
                  ],
                ],
              ),
              const SizedBox(height: AurixTokens.s12),

              // Preset chips
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kFxPresets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final p = kFxPresets[i];
                    final sel = p.id == fx.presetId && fx.enabled;
                    return _PresetChip(
                      label: p.label,
                      selected: sel,
                      onTap: () {
                        if (!fx.enabled) onFxToggle(true);
                        onPresetChanged(p.id);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AurixTokens.s10),

              // Intensity slider
              Row(
                children: [
                  Text(
                    'Intensity',
                    style: TextStyle(
                      fontFamily: AurixTokens.fontBody,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AurixTokens.muted,
                    ),
                  ),
                  const SizedBox(width: AurixTokens.s8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: fx.enabled
                            ? AurixTokens.aiAccent.withValues(alpha: 0.6)
                            : AurixTokens.muted.withValues(alpha: 0.3),
                        inactiveTrackColor: AurixTokens.surface2.withValues(alpha: 0.3),
                        thumbColor: fx.enabled ? AurixTokens.aiAccent : AurixTokens.muted,
                        overlayColor: Colors.transparent,
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: fx.intensity,
                        onChanged: fx.enabled ? onIntensityChanged : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${(fx.intensity * 100).round()}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontMono,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: fx.enabled ? AurixTokens.aiAccent : AurixTokens.micro,
                      ),
                    ),
                  ),
                ],
              ),

              // ─── Autotune row ───
              if (onAutotuneToggle != null) ...[
                const SizedBox(height: AurixTokens.s8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => onAutotuneToggle?.call(!fx.autotuneEnabled),
                      child: AnimatedContainer(
                        duration: AurixTokens.dFast,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: fx.autotuneEnabled
                              ? AurixTokens.accent.withValues(alpha: 0.15)
                              : AurixTokens.surface2.withValues(alpha: 0.3),
                          border: Border.all(color: fx.autotuneEnabled
                              ? AurixTokens.accent.withValues(alpha: 0.4)
                              : AurixTokens.stroke(0.1)),
                        ),
                        child: Text('AutoTune', style: TextStyle(
                          fontFamily: AurixTokens.fontMono, fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: fx.autotuneEnabled ? AurixTokens.accent : AurixTokens.micro)),
                      ),
                    ),
                    const SizedBox(width: AurixTokens.s8),
                    // Key selector
                    if (fx.autotuneEnabled && onAutotuneKey != null)
                      PopupMenuButton<MusicalKey>(
                        onSelected: onAutotuneKey,
                        offset: const Offset(0, -200),
                        color: AurixTokens.bg1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AurixTokens.stroke(0.15))),
                        itemBuilder: (_) => MusicalKey.values.map((k) => PopupMenuItem(
                          value: k, height: 32,
                          child: Text(kKeyLabels[k] ?? k.name, style: TextStyle(
                            fontFamily: AurixTokens.fontMono, fontSize: 11,
                            color: k == fx.autotuneKey ? AurixTokens.accent : AurixTokens.text,
                            fontWeight: k == fx.autotuneKey ? FontWeight.w700 : FontWeight.w400)),
                        )).toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AurixTokens.stroke(0.12))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(kKeyLabels[fx.autotuneKey] ?? 'C Major',
                              style: TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 10,
                                fontWeight: FontWeight.w600, color: AurixTokens.text)),
                            Icon(Icons.arrow_drop_down_rounded, size: 14, color: AurixTokens.muted),
                          ]),
                        ),
                      ),
                    if (fx.autotuneEnabled) ...[
                      const SizedBox(width: AurixTokens.s8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AurixTokens.accent.withValues(alpha: 0.5),
                            inactiveTrackColor: AurixTokens.surface2.withValues(alpha: 0.3),
                            thumbColor: AurixTokens.accent, overlayColor: Colors.transparent,
                            trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
                          child: Slider(
                            value: fx.autotuneStrength, min: 0, max: 1,
                            onChanged: onAutotuneStrength),
                        ),
                      ),
                      SizedBox(width: 28, child: Text(
                        '${(fx.autotuneStrength * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 10,
                          fontWeight: FontWeight.w600, color: AurixTokens.accent))),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FxToggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  const _FxToggle({required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: AurixTokens.dFast,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: on
              ? AurixTokens.aiAccent.withValues(alpha: 0.15)
              : AurixTokens.surface2.withValues(alpha: 0.4),
          border: Border.all(
            color: on ? AurixTokens.aiAccent.withValues(alpha: 0.4) : AurixTokens.stroke(0.12)),
        ),
        child: Text(
          on ? 'ON' : 'OFF',
          style: TextStyle(
            fontFamily: AurixTokens.fontMono,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: on ? AurixTokens.aiAccent : AurixTokens.micro,
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.selected, required this.onTap});
  @override
  State<_PresetChip> createState() => _PresetChipState();
}

class _PresetChipState extends State<_PresetChip> with SingleTickerProviderStateMixin {
  late AnimationController _b;
  @override
  void initState() { super.initState();
    _b = AnimationController(vsync: this, duration: const Duration(milliseconds: 100)); }
  @override
  void dispose() { _b.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.selected;
    return GestureDetector(
      onTapDown: (_) => _b.forward(),
      onTapUp: (_) { _b.reverse(); widget.onTap(); },
      onTapCancel: () => _b.reverse(),
      child: AnimatedBuilder(
        animation: _b,
        builder: (_, c) => Transform.scale(scale: 1 - _b.value * 0.05, child: c),
        child: AnimatedContainer(
          duration: AurixTokens.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
            color: s ? AurixTokens.aiAccent.withValues(alpha: 0.15) : AurixTokens.surface1.withValues(alpha: 0.4),
            border: Border.all(
              color: s ? AurixTokens.aiAccent.withValues(alpha: 0.45) : AurixTokens.stroke(0.12),
              width: s ? 1.5 : 1),
            boxShadow: s ? [BoxShadow(color: AurixTokens.aiAccent.withValues(alpha: 0.1), blurRadius: 8)] : null,
          ),
          child: Text(widget.label, style: TextStyle(
            fontFamily: AurixTokens.fontBody, fontSize: 12,
            fontWeight: s ? FontWeight.w700 : FontWeight.w500,
            color: s ? AurixTokens.aiAccent : AurixTokens.textSecondary)),
        ),
      ),
    );
  }
}

class _AiChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  const _AiChip({required this.label, required this.icon, required this.onTap, this.primary = false});
  @override
  State<_AiChip> createState() => _AiChipState();
}

class _AiChipState extends State<_AiChip> with SingleTickerProviderStateMixin {
  late AnimationController _b;
  @override
  void initState() { super.initState();
    _b = AnimationController(vsync: this, duration: const Duration(milliseconds: 100)); }
  @override
  void dispose() { _b.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.primary ? AurixTokens.aiAccent : AurixTokens.muted;
    return GestureDetector(
      onTapDown: (_) => _b.forward(),
      onTapUp: (_) { _b.reverse(); widget.onTap(); },
      onTapCancel: () => _b.reverse(),
      child: AnimatedBuilder(
        animation: _b,
        builder: (_, ch) => Transform.scale(scale: 1 - _b.value * 0.05, child: ch),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: widget.primary ? c.withValues(alpha: 0.12) : Colors.transparent,
            border: Border.all(color: c.withValues(alpha: widget.primary ? 0.35 : 0.18)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 12, color: c),
            const SizedBox(width: 4),
            Text(widget.label, style: TextStyle(
              fontFamily: AurixTokens.fontBody, fontSize: 10,
              fontWeight: FontWeight.w600, color: c)),
          ]),
        ),
      ),
    );
  }
}
