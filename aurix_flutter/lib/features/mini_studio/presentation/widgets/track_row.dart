import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../../domain/track_model.dart';

/// Callback signatures for clip editing.
typedef ClipMoveCallback = void Function(String clipId, double newStartTime);
typedef ClipTrimCallback = void Function(String clipId, double deltaSec);
typedef ClipDeleteCallback = void Function(String clipId);
typedef ClipSplitCallback = void Function(String clipId, double timeOnTimeline);

/// A single track row with draggable/trimmable clip rectangles.
class TrackRow extends StatelessWidget {
  final StudioTrack track;
  final bool isActive;
  final bool isRecording;
  final double pixelsPerSecond;
  final double timelineOffset;
  final VoidCallback onTap;
  final VoidCallback onMute;
  final VoidCallback onSolo;
  final VoidCallback? onDelete;
  final ClipMoveCallback? onClipMove;
  final ClipTrimCallback? onClipTrimLeft;
  final ClipTrimCallback? onClipTrimRight;
  final ClipDeleteCallback? onClipDelete;
  final ClipSplitCallback? onClipSplit;
  final String? selectedClipId;
  final ValueChanged<String?>? onClipSelect;

  const TrackRow({
    super.key,
    required this.track,
    required this.isActive,
    this.isRecording = false,
    this.pixelsPerSecond = 60,
    this.timelineOffset = 0,
    required this.onTap,
    required this.onMute,
    required this.onSolo,
    this.onDelete,
    this.onClipMove,
    this.onClipTrimLeft,
    this.onClipTrimRight,
    this.onClipDelete,
    this.onClipSplit,
    this.selectedClipId,
    this.onClipSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = track;
    final active = isActive;
    final accentColor = t.isBeat ? AurixTokens.accent : AurixTokens.positive;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AurixTokens.dMedium,
        curve: AurixTokens.cEase,
        height: 72,
        decoration: BoxDecoration(
          color: active
              ? accentColor.withValues(alpha: 0.05)
              : AurixTokens.surface1.withValues(alpha: 0.2),
          border: Border(
            left: BorderSide(
              color: active ? accentColor : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: AurixTokens.stroke(0.06)),
          ),
        ),
        child: Row(
          children: [
            // ─── Left panel ───
            SizedBox(
              width: MediaQuery.sizeOf(context).width >= 700 ? 140 : 100,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AurixTokens.s10, vertical: AurixTokens.s6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AurixTokens.fontBody,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active ? accentColor : AurixTokens.text,
                            ),
                          ),
                        ),
                        if (!t.isBeat && onDelete != null)
                          GestureDetector(
                            onTap: onDelete,
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: AurixTokens.micro),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _MiniBtn(label: 'M', on: t.isMuted,
                            color: AurixTokens.warning, onTap: onMute),
                        const SizedBox(width: 4),
                        _MiniBtn(label: 'S', on: t.isSolo,
                            color: AurixTokens.accent, onTap: onSolo),
                        const Spacer(),
                        if (isRecording && active) _RecDot(),
                        Text(
                          '${t.clips.length}',
                          style: TextStyle(
                            fontFamily: AurixTokens.fontMono,
                            fontSize: 9,
                            color: AurixTokens.micro,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Divider
            Container(width: 1, height: double.infinity,
                color: AurixTokens.stroke(0.06)),

            // ─── Clip area ───
            Expanded(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        for (final clip in t.clips)
                          _ClipWidget(
                            key: ValueKey(clip.id),
                            clip: clip,
                            trackColor: accentColor,
                            isMuted: t.isMuted,
                            isSelected: clip.id == selectedClipId,
                            pps: pixelsPerSecond,
                            scrollOffset: timelineOffset,
                            areaWidth: constraints.maxWidth,
                            areaHeight: constraints.maxHeight,
                            onSelect: () => onClipSelect?.call(clip.id),
                            onMove: (delta) => onClipMove?.call(
                              clip.id,
                              clip.startTime + delta / pixelsPerSecond,
                            ),
                            onTrimLeft: (delta) => onClipTrimLeft?.call(
                              clip.id,
                              delta / pixelsPerSecond,
                            ),
                            onTrimRight: (delta) => onClipTrimRight?.call(
                              clip.id,
                              delta / pixelsPerSecond,
                            ),
                            onDelete: () => onClipDelete?.call(clip.id),
                            onSplit: (time) => onClipSplit?.call(clip.id, time),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual clip rectangle — draggable body + trim handles.
class _ClipWidget extends StatefulWidget {
  final AudioClip clip;
  final Color trackColor;
  final bool isMuted;
  final bool isSelected;
  final double pps;
  final double scrollOffset;
  final double areaWidth;
  final double areaHeight;
  final VoidCallback onSelect;
  final ValueChanged<double> onMove;
  final ValueChanged<double> onTrimLeft;
  final ValueChanged<double> onTrimRight;
  final VoidCallback onDelete;
  final ValueChanged<double> onSplit;

  const _ClipWidget({
    super.key,
    required this.clip,
    required this.trackColor,
    required this.isMuted,
    required this.isSelected,
    required this.pps,
    required this.scrollOffset,
    required this.areaWidth,
    required this.areaHeight,
    required this.onSelect,
    required this.onMove,
    required this.onTrimLeft,
    required this.onTrimRight,
    required this.onDelete,
    required this.onSplit,
  });

  @override
  State<_ClipWidget> createState() => _ClipWidgetState();
}

class _ClipWidgetState extends State<_ClipWidget> {
  bool _dragging = false;
  bool _hovering = false;

  double get _left => widget.clip.startTime * widget.pps - widget.scrollOffset;
  double get _width => math.max(widget.clip.clipDuration * widget.pps, 8);

  @override
  Widget build(BuildContext context) {
    final c = widget.clip;
    final color = widget.isMuted
        ? AurixTokens.micro.withValues(alpha: 0.15)
        : widget.trackColor;
    final sel = widget.isSelected;

    // Skip if entirely off-screen
    if (_left + _width < -20 || _left > widget.areaWidth + 20) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: _left,
      top: 4,
      bottom: 4,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onSelect,
          onDoubleTapDown: (d) {
            // Split at double-tap position
            final tapTime = widget.clip.startTime +
                (d.localPosition.dx / _width) * widget.clip.clipDuration;
            widget.onSplit(tapTime);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: _width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: color.withValues(alpha: _dragging ? 0.22 : (sel ? 0.18 : 0.1)),
              border: Border.all(
                color: sel
                    ? color.withValues(alpha: 0.6)
                    : color.withValues(alpha: _hovering ? 0.35 : 0.18),
                width: sel ? 1.5 : 1,
              ),
              boxShadow: sel
                  ? [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 8)]
                  : null,
            ),
            child: Stack(
              children: [
                // Waveform
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: CustomPaint(
                      painter: _ClipWaveformPainter(
                        data: c.waveformCache,
                        color: color.withValues(alpha: sel ? 0.5 : 0.3),
                        offset: c.offset,
                        clipDuration: c.clipDuration,
                        bufferDuration: c.bufferDuration,
                      ),
                    ),
                  ),
                ),

                // Drag body (center region, excludes handles)
                Positioned(
                  left: 10,
                  right: 10,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) =>
                        setState(() => _dragging = true),
                    onHorizontalDragUpdate: (d) =>
                        widget.onMove(d.delta.dx),
                    onHorizontalDragEnd: (_) =>
                        setState(() => _dragging = false),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),

                // Left trim handle
                if (sel || _hovering)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (d) =>
                          widget.onTrimLeft(d.delta.dx),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: Container(
                          width: 10,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(6)),
                            color: color.withValues(alpha: 0.25),
                          ),
                          child: Center(
                            child: Container(
                              width: 2,
                              height: 16,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1),
                                color: color.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Right trim handle
                if (sel || _hovering)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (d) =>
                          widget.onTrimRight(d.delta.dx),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: Container(
                          width: 10,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(6)),
                            color: color.withValues(alpha: 0.25),
                          ),
                          child: Center(
                            child: Container(
                              width: 2,
                              height: 16,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1),
                                color: color.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
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

/// Sequencer-style filled waveform — mirrored, filled path with gradient.
class _ClipWaveformPainter extends CustomPainter {
  final Float32List? data;
  final Color color;
  final double offset;
  final double clipDuration;
  final double bufferDuration;

  _ClipWaveformPainter({
    this.data,
    required this.color,
    required this.offset,
    required this.clipDuration,
    required this.bufferDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data == null || data!.isEmpty || bufferDuration == 0 || clipDuration == 0) return;

    final totalBars = data!.length;
    final startBar = (offset / bufferDuration * totalBars).round().clamp(0, totalBars - 1);
    final endBar = ((offset + clipDuration) / bufferDuration * totalBars).round().clamp(0, totalBars);
    final visibleBars = endBar - startBar;
    if (visibleBars <= 0) return;

    final midY = size.height / 2;
    final step = size.width / visibleBars;

    // Build filled waveform path (top half)
    final topPath = Path();
    final bottomPath = Path();
    topPath.moveTo(0, midY);
    bottomPath.moveTo(0, midY);

    for (int i = 0; i < visibleBars; i++) {
      final idx = startBar + i;
      if (idx >= totalBars) break;
      final x = i * step;
      final amp = data![idx] * size.height * 0.42;
      topPath.lineTo(x, midY - amp);
      bottomPath.lineTo(x, midY + amp);
    }

    // Close paths
    topPath.lineTo(visibleBars * step, midY);
    topPath.close();
    bottomPath.lineTo(visibleBars * step, midY);
    bottomPath.close();

    // Fill with gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [color.withValues(alpha: 0.6), color.withValues(alpha: 0.15)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final bottomFillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.6)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(topPath, fillPaint);
    canvas.drawPath(bottomPath, bottomFillPaint);

    // Draw outline
    final outlinePath = Path();
    outlinePath.moveTo(0, midY);
    for (int i = 0; i < visibleBars; i++) {
      final idx = startBar + i;
      if (idx >= totalBars) break;
      outlinePath.lineTo(i * step, midY - data![idx] * size.height * 0.42);
    }
    // Reverse for bottom
    for (int i = visibleBars - 1; i >= 0; i--) {
      final idx = startBar + i;
      if (idx >= totalBars) continue;
      outlinePath.lineTo(i * step, midY + data![idx] * size.height * 0.42);
    }
    outlinePath.close();

    canvas.drawPath(outlinePath, Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    // Center line
    canvas.drawLine(
      Offset(0, midY), Offset(size.width, midY),
      Paint()..color = color.withValues(alpha: 0.15)..strokeWidth = 0.5);
  }

  @override
  bool shouldRepaint(_ClipWaveformPainter old) =>
      old.data != data || old.offset != offset || old.clipDuration != clipDuration;
}

// ─── Shared small widgets ───

class _MiniBtn extends StatelessWidget {
  final String label;
  final bool on;
  final Color color;
  final VoidCallback onTap;

  const _MiniBtn({required this.label, required this.on,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AurixTokens.dFast,
        width: 22, height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: on ? color.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: on ? color.withValues(alpha: 0.5) : AurixTokens.stroke(0.15)),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: AurixTokens.fontMono, fontSize: 9,
          fontWeight: FontWeight.w700,
          color: on ? color : AurixTokens.micro)),
      ),
    );
  }
}

class _RecDot extends StatefulWidget {
  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late AnimationController _p;
  @override
  void initState() { super.initState();
    _p = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  }
  @override
  void dispose() { _p.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _p,
      builder: (_, __) => Container(
        width: 8, height: 8,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AurixTokens.danger.withValues(alpha: 0.5 + _p.value * 0.5),
          boxShadow: [BoxShadow(
            color: AurixTokens.danger.withValues(alpha: 0.3 + _p.value * 0.2),
            blurRadius: 6)],
        ),
      ),
    );
  }
}
