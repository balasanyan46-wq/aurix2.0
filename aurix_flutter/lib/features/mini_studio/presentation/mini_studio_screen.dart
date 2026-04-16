import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/features/mini_studio/data/web_audio_engine.dart';
import 'package:aurix_flutter/features/mini_studio/presentation/track_result_screen.dart';
import 'widgets/record_button.dart';
import 'widgets/waveform_painter.dart';
import 'widgets/effects_panel.dart';
import 'widgets/glass_controls.dart';

/// Mini Studio — premium demo recording interface.
///
/// Flow: load beat → record vocal → preview → export.
class MiniStudioScreen extends StatefulWidget {
  const MiniStudioScreen({super.key});

  @override
  State<MiniStudioScreen> createState() => _MiniStudioScreenState();
}

enum _StudioPhase { empty, ready, recording, recorded }

class _MiniStudioScreenState extends State<MiniStudioScreen>
    with TickerProviderStateMixin {
  final _engine = WebAudioEngine();
  _StudioPhase _phase = _StudioPhase.empty;

  String? _beatName;
  Float32List? _beatWaveform;
  Float32List? _liveWaveform;

  double _beatVolume = 0.8;
  double _vocalVolume = 1.0;
  String _presetId = 'clean';

  bool _exporting = false;
  Timer? _visualTimer;
  double _progress = 0;

  Offset _parallax = Offset.zero;

  late AnimationController _exportPulse;

  @override
  void initState() {
    super.initState();
    _engine.init();
    _exportPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _visualTimer?.cancel();
    _engine.dispose();
    _exportPulse.dispose();
    super.dispose();
  }

  void _startVisualization() {
    _visualTimer?.cancel();
    _visualTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _liveWaveform = _engine.isRecording
            ? _engine.getVocalWaveform()
            : _engine.getBeatWaveform();

        if (_engine.isPlaying && _engine.beatDuration > 0) {
          _progress =
              (_engine.currentTime / _engine.beatDuration).clamp(0.0, 1.0);
        }
      });
    });
  }

  void _stopVisualization() {
    _visualTimer?.cancel();
    _liveWaveform = null;
  }

  Future<void> _pickBeat() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _beatName = file.name);
    try {
      await _engine.loadBeatFromBytes(file.bytes!);
      final waveform = _engine.getBeatStaticWaveform(samples: 200);
      if (mounted) {
        setState(() {
          _beatWaveform = waveform;
          _phase = _StudioPhase.ready;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить: $e'),
            backgroundColor: AurixTokens.danger,
          ),
        );
      }
    }
  }

  Future<void> _toggleRecord() async {
    if (_engine.isRecording) {
      await _engine.stopRecording();
      _stopVisualization();
      setState(() => _phase = _StudioPhase.recorded);
    } else {
      await _engine.startRecording();
      _startVisualization();
      setState(() {
        _phase = _StudioPhase.recording;
        _progress = 0;
      });
    }
  }

  void _playPreview() {
    _engine.playMixed();
    _startVisualization();
  }

  void _stopPreview() {
    _engine.resetBeat();
    _stopVisualization();
    setState(() => _progress = 0);
  }

  void _reRecord() {
    _engine.resetBeat();
    _stopVisualization();
    setState(() {
      _phase = _StudioPhase.ready;
      _progress = 0;
      _liveWaveform = null;
    });
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    _exportPulse.repeat(reverse: true);

    try {
      final blobUrl = await _engine.exportBlobUrl();
      final name = _beatName?.replaceAll(RegExp(r'\.[^.]+$'), '') ?? 'demo';

      _exportPulse.stop();
      _exportPulse.reset();
      if (mounted) {
        setState(() => _exporting = false);
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => TrackResultScreen(
              blobUrl: blobUrl,
              waveformData: _beatWaveform,
              trackName: name,
            ),
            transitionsBuilder: (_, anim, __, child) {
              return FadeTransition(
                opacity:
                    CurvedAnimation(parent: anim, curve: Curves.easeOut),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } catch (e) {
      _exportPulse.stop();
      _exportPulse.reset();
      if (mounted) {
        setState(() => _exporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта: $e'),
            backgroundColor: AurixTokens.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isWide = mq.size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: MouseRegion(
        onHover: (e) {
          setState(() {
            _parallax = Offset(
              (e.position.dx / mq.size.width - 0.5) * 12,
              (e.position.dy / mq.size.height - 0.5) * 8,
            );
          });
        },
        child: Stack(
          children: [
            _Background(parallax: _parallax, phase: _phase),
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(context),
                  Expanded(child: _buildBody(context, isWide)),
                  _buildBottomPanel(context),
                ],
              ),
            ),
            if (_phase == _StudioPhase.recorded)
              Positioned(
                right: AurixTokens.s24,
                bottom: mq.padding.bottom + 180,
                child: FadeInSlide(
                  delayMs: 200,
                  child: _ExportButton(
                    exporting: _exporting,
                    pulseAnimation: _exportPulse,
                    onTap: _exporting ? null : _export,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AurixTokens.s16,
        vertical: AurixTokens.s8,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AurixTokens.surface1.withValues(alpha: 0.5),
                border: Border.all(color: AurixTokens.stroke(0.15)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: AurixTokens.textSecondary),
            ),
          ),
          const SizedBox(width: AurixTokens.s12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'МИНИ СТУДИЯ',
                style: TextStyle(
                  fontFamily: AurixTokens.fontDisplay,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AurixTokens.text,
                  letterSpacing: 1.5,
                ),
              ),
              if (_beatName != null)
                Text(
                  _beatName!,
                  style: TextStyle(
                    fontFamily: AurixTokens.fontBody,
                    fontSize: 11,
                    color: AurixTokens.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AurixTokens.s12),
          _QuickStudioSwitch(
            studioMode: false,
            onChanged: (v) {
              if (v) context.go('/studio/daw');
            },
          ),
          const Spacer(),
          _PhaseIndicator(phase: _phase),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isWide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_phase != _StudioPhase.empty) ...[
                  FadeInSlide(
                    delayMs: 100,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AurixTokens.s16),
                      child: WaveformView(
                        beatStaticWaveform: _beatWaveform,
                        liveWaveform: _liveWaveform,
                        progress: _progress,
                        height: 100,
                      ),
                    ),
                  ),
                  const SizedBox(height: AurixTokens.s8),
                  _TimeDisplay(
                    current: _engine.currentTime,
                    total: _engine.beatDuration,
                    progress: _progress,
                  ),
                  const SizedBox(height: AurixTokens.s32),
                ],
                if (_phase == _StudioPhase.empty)
                  _UploadPrompt(onTap: _pickBeat)
                else ...[
                  RecordButton(
                    isRecording: _phase == _StudioPhase.recording,
                    enabled: _phase == _StudioPhase.ready ||
                        _phase == _StudioPhase.recording,
                    onTap: (_phase == _StudioPhase.ready ||
                            _phase == _StudioPhase.recording)
                        ? _toggleRecord
                        : null,
                  ),
                  const SizedBox(height: AurixTokens.s16),
                  AnimatedSwitcher(
                    duration: AurixTokens.dMedium,
                    child: Text(
                      _phaseLabel,
                      key: ValueKey(_phase),
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        fontSize: 13,
                        color: AurixTokens.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_phase == _StudioPhase.recorded) ...[
                    const SizedBox(height: AurixTokens.s24),
                    FadeInSlide(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ActionChip(
                            icon: Icons.play_arrow_rounded,
                            label: 'Прослушать',
                            onTap: _playPreview,
                          ),
                          const SizedBox(width: AurixTokens.s12),
                          _ActionChip(
                            icon: Icons.stop_rounded,
                            label: 'Стоп',
                            onTap: _stopPreview,
                            muted: true,
                          ),
                          const SizedBox(width: AurixTokens.s12),
                          _ActionChip(
                            icon: Icons.refresh_rounded,
                            label: 'Заново',
                            onTap: _reRecord,
                            muted: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: AurixTokens.s32),
                if (_phase != _StudioPhase.empty)
                  FadeInSlide(
                    delayMs: 300,
                    child: EffectsPanel(
                      selectedId: _presetId,
                      onSelect: (preset) {
                        _engine.applyPreset(preset);
                        setState(() => _presetId = preset.id);
                      },
                    ),
                  ),
                const SizedBox(height: AurixTokens.s24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    if (_phase == _StudioPhase.empty) return const SizedBox.shrink();
    return GlassControlsPanel(
      beatVolume: _beatVolume,
      vocalVolume: _vocalVolume,
      onBeatVolumeChanged: (v) {
        _engine.setBeatVolume(v);
        setState(() => _beatVolume = v);
      },
      onVocalVolumeChanged: (v) {
        _engine.setVocalVolume(v);
        setState(() => _vocalVolume = v);
      },
      trailing: GestureDetector(
        onTap: _pickBeat,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz_rounded, size: 16, color: AurixTokens.muted),
            const SizedBox(width: 6),
            Text(
              'Сменить бит',
              style: TextStyle(
                fontFamily: AurixTokens.fontBody,
                fontSize: 12,
                color: AurixTokens.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _phaseLabel {
    switch (_phase) {
      case _StudioPhase.empty:
        return '';
      case _StudioPhase.ready:
        return 'Нажми для записи';
      case _StudioPhase.recording:
        return 'Запись...';
      case _StudioPhase.recorded:
        return 'Запись готова';
    }
  }
}

// ─── Internal widgets ───

class _Background extends StatelessWidget {
  final Offset parallax;
  final _StudioPhase phase;
  const _Background({required this.parallax, required this.phase});

  @override
  Widget build(BuildContext context) {
    final isRecording = phase == _StudioPhase.recording;
    return Stack(
      children: [
        Container(color: const Color(0xFF050505)),
        Positioned(
          left: MediaQuery.sizeOf(context).width / 2 - 200 + parallax.dx,
          top: MediaQuery.sizeOf(context).height / 3 - 200 + parallax.dy,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  (isRecording ? AurixTokens.danger : AurixTokens.accent)
                      .withValues(alpha: isRecording ? 0.06 : 0.03),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: -80 + parallax.dx * 0.6,
          bottom: 100 + parallax.dy * 0.4,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AurixTokens.aiAccent.withValues(alpha: 0.025),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF050505).withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UploadPrompt extends StatefulWidget {
  final VoidCallback onTap;
  const _UploadPrompt({required this.onTap});
  @override
  State<_UploadPrompt> createState() => _UploadPromptState();
}

class _UploadPromptState extends State<_UploadPrompt>
    with SingleTickerProviderStateMixin {
  late AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeInSlide(
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, child) {
          final opacity = 0.08 + _glow.value * 0.08;
          return GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AurixTokens.accent
                      .withValues(alpha: 0.2 + _glow.value * 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AurixTokens.accent.withValues(alpha: opacity),
                    blurRadius: 48,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded,
                      size: 48,
                      color: AurixTokens.accent.withValues(alpha: 0.7)),
                  const SizedBox(height: AurixTokens.s8),
                  Text('Загрузить бит',
                      style: TextStyle(
                          fontFamily: AurixTokens.fontBody,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AurixTokens.textSecondary)),
                  const SizedBox(height: 4),
                  Text('MP3, WAV, OGG',
                      style: TextStyle(
                          fontFamily: AurixTokens.fontMono,
                          fontSize: 11,
                          color: AurixTokens.muted)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhaseIndicator extends StatelessWidget {
  final _StudioPhase phase;
  const _PhaseIndicator({required this.phase});

  @override
  Widget build(BuildContext context) {
    final color = switch (phase) {
      _StudioPhase.empty => AurixTokens.muted,
      _StudioPhase.ready => AurixTokens.accent,
      _StudioPhase.recording => AurixTokens.danger,
      _StudioPhase.recorded => AurixTokens.positive,
    };
    final label = switch (phase) {
      _StudioPhase.empty => 'ПУСТО',
      _StudioPhase.ready => 'ГОТОВ',
      _StudioPhase.recording => 'REC',
      _StudioPhase.recorded => 'ГОТОВО',
    };
    return AnimatedContainer(
      duration: AurixTokens.dMedium,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  final double current;
  final double total;
  final double progress;
  const _TimeDisplay(
      {required this.current, required this.total, required this.progress});

  String _fmt(double s) {
    final min = s ~/ 60;
    final sec = (s % 60).toInt();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_fmt(current),
          style: TextStyle(
              fontFamily: AurixTokens.fontMono,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AurixTokens.textSecondary,
              fontFeatures: AurixTokens.tabularFigures)),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('/',
              style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  fontSize: 13,
                  color: AurixTokens.micro))),
      Text(_fmt(total),
          style: TextStyle(
              fontFamily: AurixTokens.fontMono,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AurixTokens.muted,
              fontFeatures: AurixTokens.tabularFigures)),
    ]);
  }
}

class _ActionChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool muted;
  const _ActionChip(
      {required this.icon, required this.label, this.onTap, this.muted = false});
  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounce;
  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.muted ? AurixTokens.muted : AurixTokens.accent;
    return GestureDetector(
      onTapDown: (_) => _bounce.forward(),
      onTapUp: (_) {
        _bounce.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _bounce.reverse(),
      child: AnimatedBuilder(
        animation: _bounce,
        builder: (context, child) =>
            Transform.scale(scale: 1.0 - _bounce.value * 0.05, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(widget.label,
                style: TextStyle(
                    fontFamily: AurixTokens.fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ]),
        ),
      ),
    );
  }
}

class _QuickStudioSwitch extends StatelessWidget {
  final bool studioMode;
  final ValueChanged<bool> onChanged;
  const _QuickStudioSwitch({required this.studioMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
        color: AurixTokens.bg2.withValues(alpha: 0.5),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SwitchTab(label: 'Quick', active: !studioMode, onTap: () => onChanged(false)),
          _SwitchTab(label: 'Studio', active: studioMode, onTap: () => onChanged(true)),
        ],
      ),
    );
  }
}

class _SwitchTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SwitchTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AurixTokens.dMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AurixTokens.radiusChip - 2),
          color: active ? AurixTokens.accent.withValues(alpha: 0.15) : Colors.transparent,
        ),
        child: Text(label, style: TextStyle(
          fontFamily: AurixTokens.fontBody,
          fontSize: 11,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? AurixTokens.accent : AurixTokens.muted,
        )),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final bool exporting;
  final AnimationController pulseAnimation;
  final VoidCallback? onTap;
  const _ExportButton(
      {required this.exporting, required this.pulseAnimation, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        final glow = exporting ? 0.2 + pulseAnimation.value * 0.2 : 0.15;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AurixTokens.accent, AurixTokens.accentMuted],
              ),
              boxShadow: [
                BoxShadow(
                    color: AurixTokens.accent.withValues(alpha: glow),
                    blurRadius: 24,
                    spreadRadius: 2),
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: exporting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_rounded,
                      color: Colors.white, size: 24),
            ),
          ),
        );
      },
    );
  }
}
