import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Range slider for selecting a start/end segment of a track.
class RangeSelector extends StatelessWidget {
  final double duration;
  final double startTime;
  final double endTime;
  final ValueChanged<RangeValues> onChanged;

  const RangeSelector({
    super.key,
    required this.duration,
    required this.startTime,
    required this.endTime,
    required this.onChanged,
  });

  String _fmt(double s) {
    if (s.isNaN || s.isInfinite || s <= 0) return '0:00';
    final m = s ~/ 60;
    final sec = (s % 60).toInt();
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final segmentLen = endTime - startTime;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.stroke(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Отрезок', style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AurixTokens.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${segmentLen.round()}с',
              style: TextStyle(color: AurixTokens.accent, fontSize: 13, fontWeight: FontWeight.w700,
                  fontFeatures: AurixTokens.tabularFigures),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_fmt(startTime), style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontFeatures: AurixTokens.tabularFigures)),
          Text(_fmt(endTime), style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontFeatures: AurixTokens.tabularFigures)),
        ]),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AurixTokens.accent,
            inactiveTrackColor: AurixTokens.glass(0.12),
            thumbColor: AurixTokens.accent,
            overlayColor: AurixTokens.accent.withValues(alpha: 0.12),
            rangeValueIndicatorShape: const PaddleRangeSliderValueIndicatorShape(),
            valueIndicatorColor: AurixTokens.accent,
            valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
            showValueIndicator: ShowValueIndicator.always,
          ),
          child: RangeSlider(
            values: RangeValues(startTime, endTime),
            min: 0,
            max: duration > 0 ? duration : 1,
            labels: RangeLabels(_fmt(startTime), _fmt(endTime)),
            onChanged: (v) {
              final clamped = RangeValues(
                v.start,
                // Enforce min 3s, max 60s segment
                (v.end - v.start < 3) ? v.start + 3 : (v.end - v.start > 60 ? v.start + 60 : v.end),
              );
              onChanged(clamped);
            },
          ),
        ),
        Text(
          'Мин. 3 сек · Макс. 60 сек',
          style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.5), fontSize: 11),
        ),
      ]),
    );
  }
}
