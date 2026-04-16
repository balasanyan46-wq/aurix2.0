import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../../domain/track_model.dart';

/// Transport bar with BPM, grid, metronome, play/stop/record, musical timecode.
class TransportControls extends StatelessWidget {
  final bool isPlaying;
  final bool isRecording;
  final bool isCountingIn;
  final double currentTime;
  final double totalDuration;
  final bool studioMode;
  final bool canRecord;
  final ProjectTiming timing;
  final bool metronomeOn;
  final bool loopActive;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final VoidCallback onRecord;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<double> onBpmChanged;
  final ValueChanged<GridDivision> onGridChanged;
  final ValueChanged<bool> onMetronomeChanged;
  final ValueChanged<bool> onLoopToggle;

  const TransportControls({
    super.key,
    required this.isPlaying,
    required this.isRecording,
    this.isCountingIn = false,
    required this.currentTime,
    required this.totalDuration,
    required this.studioMode,
    required this.canRecord,
    required this.timing,
    required this.metronomeOn,
    this.loopActive = false,
    required this.onPlay,
    required this.onStop,
    required this.onRecord,
    required this.onModeChanged,
    required this.onBpmChanged,
    required this.onGridChanged,
    required this.onMetronomeChanged,
    required this.onLoopToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AurixTokens.s10, vertical: 6),
      decoration: BoxDecoration(
        color: AurixTokens.surface1.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: AurixTokens.stroke(0.1))),
      ),
      child: isWide ? _wideLayout() : _mobileLayout(),
    );
  }

  Widget _wideLayout() {
    return Row(children: [
      _TBtn(icon: Icons.stop_rounded, onTap: onStop, color: AurixTokens.muted, size: 30),
      const SizedBox(width: 6),
      _TBtn(icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onTap: onPlay, color: AurixTokens.accent, filled: true, size: 38),
      const SizedBox(width: 6),
      _TBtn(icon: Icons.fiber_manual_record_rounded,
          onTap: canRecord ? onRecord : null,
          color: isRecording ? AurixTokens.danger : AurixTokens.danger.withValues(alpha: 0.4),
          filled: isRecording, size: 30, pulse: isRecording),
      const SizedBox(width: AurixTokens.s12),
      _timecodeWidget(),
      _divider(),
      _BpmInput(bpm: timing.bpm, onChanged: onBpmChanged),
      const SizedBox(width: AurixTokens.s8),
      _GridSelector(current: timing.gridDivision, onChanged: onGridChanged),
      const SizedBox(width: AurixTokens.s8),
      _MetronomeToggle(on: metronomeOn, onChanged: onMetronomeChanged),
      const SizedBox(width: AurixTokens.s4),
      _LoopToggle(on: loopActive, onChanged: onLoopToggle),
      const Spacer(),
      if (isRecording) _recIndicator(),
    ]);
  }

  Widget _mobileLayout() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Row 1: mode + transport + timecode
      Row(children: [
        _TBtn(icon: Icons.stop_rounded, onTap: onStop, color: AurixTokens.muted, size: 28),
        const SizedBox(width: 4),
        _TBtn(icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            onTap: onPlay, color: AurixTokens.accent, filled: true, size: 34),
        const SizedBox(width: 4),
        _TBtn(icon: Icons.fiber_manual_record_rounded,
            onTap: canRecord ? onRecord : null,
            color: isRecording ? AurixTokens.danger : AurixTokens.danger.withValues(alpha: 0.4),
            filled: isRecording, size: 28, pulse: isRecording),
        const SizedBox(width: 8),
        _timecodeWidget(small: true),
        const Spacer(),
        if (isRecording) _recIndicator(),
      ]),
      const SizedBox(height: 4),
      // Row 2: BPM + grid + metronome + loop
      Row(children: [
        _BpmInput(bpm: timing.bpm, onChanged: onBpmChanged),
        const SizedBox(width: 6),
        _GridSelector(current: timing.gridDivision, onChanged: onGridChanged),
        const SizedBox(width: 6),
        _MetronomeToggle(on: metronomeOn, onChanged: onMetronomeChanged),
        const SizedBox(width: 4),
        _LoopToggle(on: loopActive, onChanged: onLoopToggle),
      ]),
    ]);
  }

  Widget _timecodeWidget({bool small = false}) {
    if (isCountingIn) {
      return Text('COUNT IN', style: TextStyle(
        fontFamily: AurixTokens.fontMono, fontSize: small ? 12 : 14,
        fontWeight: FontWeight.w700, color: AurixTokens.warning));
    }
    return Text(
      timing.formatBarBeatSub(currentTime),
      style: TextStyle(
        fontFamily: AurixTokens.fontMono, fontSize: small ? 14 : 18,
        fontWeight: FontWeight.w700, color: AurixTokens.text,
        fontFeatures: AurixTokens.tabularFigures));
  }

  Widget _recIndicator() => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(
      shape: BoxShape.circle, color: AurixTokens.danger,
      boxShadow: [BoxShadow(color: AurixTokens.danger.withValues(alpha: 0.5), blurRadius: 6)])),
    const SizedBox(width: 6),
    Text('REC', style: TextStyle(fontFamily: AurixTokens.fontMono,
      fontSize: 11, fontWeight: FontWeight.w700,
      color: AurixTokens.danger, letterSpacing: 1)),
  ]);

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AurixTokens.s8),
    child: Container(width: 1, height: 28, color: AurixTokens.stroke(0.1)),
  );
}

// ─── BPM Input ───

class _BpmInput extends StatefulWidget {
  final double bpm;
  final ValueChanged<double> onChanged;
  const _BpmInput({required this.bpm, required this.onChanged});
  @override
  State<_BpmInput> createState() => _BpmInputState();
}

class _BpmInputState extends State<_BpmInput> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.bpm.round().toString());
  }

  @override
  void didUpdateWidget(_BpmInput old) {
    super.didUpdateWidget(old);
    if (!_editing && old.bpm != widget.bpm) {
      _ctrl.text = widget.bpm.round().toString();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _submit() {
    _editing = false;
    final v = double.tryParse(_ctrl.text);
    if (v != null) widget.onChanged(v.clamp(40, 300));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: AurixTokens.bg2.withValues(alpha: 0.5),
        border: Border.all(color: AurixTokens.stroke(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              onTap: () => _editing = true,
              onSubmitted: (_) => _submit(),
              onTapOutside: (_) => _submit(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontFamily: AurixTokens.fontMono, fontSize: 13,
                fontWeight: FontWeight.w700, color: AurixTokens.text),
              decoration: const InputDecoration(
                border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.zero),
              textAlign: TextAlign.center,
            ),
          ),
          Text('bpm', style: TextStyle(
            fontFamily: AurixTokens.fontMono, fontSize: 8,
            color: AurixTokens.micro, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Grid Selector ───

class _GridSelector extends StatelessWidget {
  final GridDivision current;
  final ValueChanged<GridDivision> onChanged;
  const _GridSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: AurixTokens.bg2.withValues(alpha: 0.5),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GridTab('1/4', GridDivision.quarter, current == GridDivision.quarter,
              () => onChanged(GridDivision.quarter)),
          _GridTab('1/8', GridDivision.eighth, current == GridDivision.eighth,
              () => onChanged(GridDivision.eighth)),
          _GridTab('1/16', GridDivision.sixteenth, current == GridDivision.sixteenth,
              () => onChanged(GridDivision.sixteenth)),
        ],
      ),
    );
  }

  Widget _GridTab(String label, GridDivision div, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AurixTokens.dFast,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: active ? AurixTokens.accent.withValues(alpha: 0.15) : Colors.transparent,
        ),
        child: Text(label, style: TextStyle(
          fontFamily: AurixTokens.fontMono, fontSize: 10,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? AurixTokens.accent : AurixTokens.micro)),
      ),
    );
  }
}

// ─── Metronome Toggle ───

class _MetronomeToggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  const _MetronomeToggle({required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: AurixTokens.dFast,
        width: 30, height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: on ? AurixTokens.accent.withValues(alpha: 0.15) : AurixTokens.bg2.withValues(alpha: 0.5),
          border: Border.all(
            color: on ? AurixTokens.accent.withValues(alpha: 0.4) : AurixTokens.stroke(0.1)),
        ),
        child: Icon(
          Icons.timer_rounded, size: 16,
          color: on ? AurixTokens.accent : AurixTokens.micro,
        ),
      ),
    );
  }
}

class _LoopToggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  const _LoopToggle({required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: AnimatedContainer(
        duration: AurixTokens.dFast,
        width: 30, height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: on ? AurixTokens.warning.withValues(alpha: 0.15) : AurixTokens.bg2.withValues(alpha: 0.5),
          border: Border.all(
            color: on ? AurixTokens.warning.withValues(alpha: 0.4) : AurixTokens.stroke(0.1)),
        ),
        child: Icon(
          Icons.loop_rounded, size: 16,
          color: on ? AurixTokens.warning : AurixTokens.micro,
        ),
      ),
    );
  }
}

// ─── Shared ───

class _ModeSwitcher extends StatelessWidget {
  final bool studioMode;
  final ValueChanged<bool> onChanged;
  const _ModeSwitcher({required this.studioMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
        color: AurixTokens.bg2.withValues(alpha: 0.5),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _MTab('Quick', !studioMode, () => onChanged(false)),
        _MTab('Studio', studioMode, () => onChanged(true)),
      ]),
    );
  }

  Widget _MTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AurixTokens.dMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AurixTokens.radiusChip - 2),
          color: active ? AurixTokens.accent.withValues(alpha: 0.15) : Colors.transparent,
        ),
        child: Text(label, style: TextStyle(
          fontFamily: AurixTokens.fontBody, fontSize: 11,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? AurixTokens.accent : AurixTokens.muted)),
      ),
    );
  }
}

class _TBtn extends StatefulWidget {
  final IconData icon; final VoidCallback? onTap; final Color color;
  final bool filled; final double size; final bool pulse;
  const _TBtn({required this.icon, this.onTap, required this.color,
    this.filled = false, this.size = 36, this.pulse = false});
  @override State<_TBtn> createState() => _TBtnS();
}
class _TBtnS extends State<_TBtn> with SingleTickerProviderStateMixin {
  late AnimationController _a;
  @override void initState() { super.initState();
    _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 120)); }
  @override void dispose() { _a.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final en = widget.onTap != null;
    return GestureDetector(
      onTapDown: en ? (_) => _a.forward() : null,
      onTapUp: en ? (_) { _a.reverse(); widget.onTap?.call(); } : null,
      onTapCancel: () => _a.reverse(),
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, c) => Transform.scale(scale: 1.0 - _a.value * 0.08, child: c),
        child: AnimatedContainer(
          duration: AurixTokens.dMedium,
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.filled ? widget.color.withValues(alpha: 0.2) : Colors.transparent,
            border: Border.all(color: widget.color.withValues(alpha: en ? 0.4 : 0.15), width: 1.5),
            boxShadow: widget.pulse ? [BoxShadow(color: widget.color.withValues(alpha: 0.25), blurRadius: 12)] : null,
          ),
          child: Icon(widget.icon, size: widget.size * 0.5,
            color: widget.color.withValues(alpha: en ? 1 : 0.3)),
        ),
      ),
    );
  }
}
