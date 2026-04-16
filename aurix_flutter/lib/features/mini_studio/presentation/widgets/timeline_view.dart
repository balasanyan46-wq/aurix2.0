import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../../domain/track_model.dart';

/// Musical timeline header — bar/beat grid, playhead, loop region.
class TimelineHeader extends StatefulWidget {
  final double totalDuration;
  final double pixelsPerSecond;
  final double scrollOffset;
  final double playheadTime;
  final double viewportWidth;
  final ProjectTiming timing;
  final LoopRegion loop;
  final ValueChanged<LoopRegion>? onLoopChanged;
  final ValueChanged<double>? onSeek;

  const TimelineHeader({
    super.key,
    required this.totalDuration,
    required this.pixelsPerSecond,
    required this.scrollOffset,
    required this.playheadTime,
    required this.viewportWidth,
    required this.timing,
    required this.loop,
    this.onLoopChanged,
    this.onSeek,
  });

  @override
  State<TimelineHeader> createState() => _TimelineHeaderState();
}

class _TimelineHeaderState extends State<TimelineHeader> {
  bool _draggingLoop = false;
  double? _dragStart;

  double _pxToSec(double px) =>
      (px + widget.scrollOffset) / widget.pixelsPerSecond;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: GestureDetector(
        // Drag on ruler to create loop region
        onHorizontalDragStart: (d) {
          _dragStart = _pxToSec(d.localPosition.dx);
          _draggingLoop = true;
        },
        onHorizontalDragUpdate: (d) {
          if (_dragStart == null) return;
          final cur = _pxToSec(d.localPosition.dx);
          final s = math.min(_dragStart!, cur);
          final e = math.max(_dragStart!, cur);
          final snappedS = widget.timing.snapToGrid(s);
          final snappedE = widget.timing.snapToGrid(e);
          if (snappedE - snappedS >= widget.timing.secondsPerBar * 0.5) {
            widget.onLoopChanged?.call(
              LoopRegion(startTime: snappedS, endTime: snappedE, isActive: true),
            );
          }
        },
        onHorizontalDragEnd: (_) {
          _draggingLoop = false;
          _dragStart = null;
        },
        // Tap to seek
        onTapUp: (d) {
          final sec = widget.timing.snapToGrid(_pxToSec(d.localPosition.dx));
          widget.onSeek?.call(sec);
        },
        // Double-tap to quick-create 1-bar loop
        onDoubleTapDown: (d) {
          final sec = _pxToSec(d.localPosition.dx);
          final barStart = (sec / widget.timing.secondsPerBar).floor() *
              widget.timing.secondsPerBar;
          widget.onLoopChanged?.call(LoopRegion(
            startTime: barStart,
            endTime: barStart + widget.timing.secondsPerBar,
            isActive: true,
          ));
        },
        child: CustomPaint(
          painter: _MusicalRulerPainter(
            totalDuration: widget.totalDuration,
            pps: widget.pixelsPerSecond,
            scrollOffset: widget.scrollOffset,
            playheadTime: widget.playheadTime,
            timing: widget.timing,
            loop: widget.loop,
          ),
          size: Size(widget.viewportWidth, 36),
        ),
      ),
    );
  }
}

class _MusicalRulerPainter extends CustomPainter {
  final double totalDuration;
  final double pps;
  final double scrollOffset;
  final double playheadTime;
  final ProjectTiming timing;
  final LoopRegion loop;

  _MusicalRulerPainter({
    required this.totalDuration,
    required this.pps,
    required this.scrollOffset,
    required this.playheadTime,
    required this.timing,
    required this.loop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final spb = timing.secondsPerBeat;
    final bpb = timing.beatsPerBar;
    final spBar = timing.secondsPerBar;

    // ─── Loop region background ───
    if (loop.isActive && loop.isValid) {
      final lx1 = loop.startTime * pps - scrollOffset;
      final lx2 = loop.endTime * pps - scrollOffset;
      canvas.drawRect(
        Rect.fromLTRB(
          lx1.clamp(0, size.width),
          0,
          lx2.clamp(0, size.width),
          size.height,
        ),
        Paint()..color = AurixTokens.warning.withValues(alpha: 0.08),
      );
      // Loop bar top
      canvas.drawRect(
        Rect.fromLTRB(
          lx1.clamp(0, size.width),
          0,
          lx2.clamp(0, size.width),
          4,
        ),
        Paint()..color = AurixTokens.warning.withValues(alpha: 0.5),
      );
      // Left handle
      if (lx1 >= -4 && lx1 <= size.width + 4) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(lx1 - 3, 0, 6, size.height),
            const Radius.circular(2),
          ),
          Paint()..color = AurixTokens.warning.withValues(alpha: 0.3),
        );
      }
      // Right handle
      if (lx2 >= -4 && lx2 <= size.width + 4) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(lx2 - 3, 0, 6, size.height),
            const Radius.circular(2),
          ),
          Paint()..color = AurixTokens.warning.withValues(alpha: 0.3),
        );
      }
    }

    // ─── Grid lines ───
    final startSec = scrollOffset / pps;
    final endSec = (scrollOffset + size.width) / pps;
    final startBar = (startSec / spBar).floor();
    final endBar = (endSec / spBar).ceil() + 1;

    final barPaint = Paint()..color = AurixTokens.stroke(0.3)..strokeWidth = 1;
    final beatPaint = Paint()..color = AurixTokens.stroke(0.12)..strokeWidth = 0.5;
    final subPaint = Paint()..color = AurixTokens.stroke(0.06)..strokeWidth = 0.5;

    for (int bar = startBar; bar <= endBar; bar++) {
      if (bar < 0) continue;
      final barSec = bar * spBar;
      final barX = barSec * pps - scrollOffset;

      if (barX >= -20 && barX <= size.width + 20) {
        canvas.drawLine(Offset(barX, 6), Offset(barX, size.height), barPaint);
        final tp = TextPainter(
          text: TextSpan(
            text: '${bar + 1}',
            style: TextStyle(
              fontFamily: AurixTokens.fontMono, fontSize: 10,
              fontWeight: FontWeight.w700, color: AurixTokens.muted),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(barX + 4, 8));
      }

      for (int beat = 1; beat < bpb; beat++) {
        final beatX = (barSec + beat * spb) * pps - scrollOffset;
        if (beatX < -5 || beatX > size.width + 5) continue;
        canvas.drawLine(Offset(beatX, size.height - 14), Offset(beatX, size.height), beatPaint);
        final btp = TextPainter(
          text: TextSpan(text: '${beat + 1}',
            style: TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 8, color: AurixTokens.micro)),
          textDirection: TextDirection.ltr,
        )..layout();
        btp.paint(canvas, Offset(beatX + 2, 12));
      }

      final gs = timing.gridStepSeconds;
      if (gs < spb) {
        for (double t = barSec; t < barSec + spBar; t += gs) {
          final bn = (t - barSec) / spb;
          if ((bn - bn.roundToDouble()).abs() < 0.001) continue;
          final sx = t * pps - scrollOffset;
          if (sx < 0 || sx > size.width) continue;
          canvas.drawLine(Offset(sx, size.height - 6), Offset(sx, size.height), subPaint);
        }
      }
    }

    // ─── Playhead ───
    final phX = playheadTime * pps - scrollOffset;
    if (phX >= -2 && phX <= size.width + 2) {
      canvas.drawLine(Offset(phX, 0), Offset(phX, size.height),
        Paint()..color = AurixTokens.accent..strokeWidth = 2);
      canvas.drawPath(
        Path()..moveTo(phX - 5, 4)..lineTo(phX + 5, 4)..lineTo(phX, 10)..close(),
        Paint()..color = AurixTokens.accent);
    }

    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5),
      Paint()..color = AurixTokens.stroke(0.1));
  }

  @override
  bool shouldRepaint(_MusicalRulerPainter old) =>
      old.playheadTime != playheadTime || old.scrollOffset != scrollOffset ||
      old.totalDuration != totalDuration || old.timing.bpm != timing.bpm ||
      old.timing.gridDivision != timing.gridDivision ||
      old.loop.isActive != loop.isActive ||
      old.loop.startTime != loop.startTime || old.loop.endTime != loop.endTime;
}

/// Playhead overlay line spanning the track area.
class PlayheadLine extends StatelessWidget {
  final double playheadTime;
  final double pixelsPerSecond;
  final double scrollOffset;

  const PlayheadLine({
    super.key,
    required this.playheadTime,
    required this.pixelsPerSecond,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    final lp = MediaQuery.sizeOf(context).width >= 700 ? 140.0 : 100.0;
    final x = playheadTime * pixelsPerSecond - scrollOffset + lp;
    return Positioned(
      left: x, top: 0, bottom: 0,
      child: IgnorePointer(child: Container(
        width: 2,
        decoration: BoxDecoration(
          color: AurixTokens.accent.withValues(alpha: 0.6),
          boxShadow: [BoxShadow(
            color: AurixTokens.accent.withValues(alpha: 0.15),
            blurRadius: 8, spreadRadius: 2)]),
      )),
    );
  }
}

/// Loop region overlay spanning the track area (yellow highlight).
class LoopRegionOverlay extends StatelessWidget {
  final LoopRegion loop;
  final double pixelsPerSecond;
  final double scrollOffset;

  const LoopRegionOverlay({
    super.key,
    required this.loop,
    required this.pixelsPerSecond,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    if (!loop.isActive || !loop.isValid) return const SizedBox.shrink();
    final lp = MediaQuery.sizeOf(context).width >= 700 ? 140.0 : 100.0;
    final left = loop.startTime * pixelsPerSecond - scrollOffset + lp;
    final width = loop.duration * pixelsPerSecond;
    return Positioned(
      left: left, top: 0, bottom: 0, width: width,
      child: IgnorePointer(child: Container(
        decoration: BoxDecoration(
          color: AurixTokens.warning.withValues(alpha: 0.04),
          border: Border.symmetric(vertical: BorderSide(
            color: AurixTokens.warning.withValues(alpha: 0.15)))),
      )),
    );
  }
}
