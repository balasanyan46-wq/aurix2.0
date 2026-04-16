import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../models/audio_analysis_result.dart';

/// Animated frequency band spectrum visualization.
class FreqSpectrum extends StatefulWidget {
  final FreqBands bands;
  final String? verdict;

  const FreqSpectrum({super.key, required this.bands, this.verdict});

  @override
  State<FreqSpectrum> createState() => _FreqSpectrumState();
}

class _FreqSpectrumState extends State<FreqSpectrum>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static const _barColors = [
    Color(0xFFEF4444), // Sub-bass — red
    Color(0xFFF97316), // Bass — orange
    Color(0xFFEAB308), // Low-mid — yellow
    Color(0xFF22C55E), // Mid — green
    Color(0xFF06B6D4), // Upper-mid — cyan
    Color(0xFF8B5CF6), // High — purple
    Color(0xFFEC4899), // Air — pink
  ];

  @override
  Widget build(BuildContext context) {
    final entries = widget.bands.entries;
    final maxVal = entries.map((e) => e.value).fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.stroke(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.equalizer_rounded,
              size: 16, color: AurixTokens.accent.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text('Частотный баланс',
              style: TextStyle(
                  color: AurixTokens.text.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),

        // Bars
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final progress = CurvedAnimation(
              parent: _ctrl,
              curve: Curves.easeOutCubic,
            ).value;

            return SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(entries.length, (i) {
                  final e = entries[i];
                  final normalizedH = maxVal > 0 ? (e.value / maxVal) : 0.0;
                  final barH = normalizedH * 100 * progress;
                  final color = _barColors[i % _barColors.length];

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Percentage
                          Text(
                            '${(e.value * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: color.withValues(alpha: 0.7 * progress),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Bar with glow
                          Container(
                            height: barH.clamp(4, 100),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [color, color.withValues(alpha: 0.4)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: normalizedH > 0.6
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        spreadRadius: -2,
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Label
                          Text(
                            e.key,
                            style: TextStyle(
                              color: AurixTokens.muted.withValues(alpha: 0.5),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),

        // Verdict
        if (widget.verdict != null && widget.verdict!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AurixTokens.text.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              widget.verdict!,
              style: TextStyle(
                color: AurixTokens.text.withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
