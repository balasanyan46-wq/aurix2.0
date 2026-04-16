import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

// ─── Musical timing ───

enum GridDivision {
  quarter,  // 1/4 note
  eighth,   // 1/8 note
  sixteenth // 1/16 note
}

class ProjectTiming {
  double bpm;
  int beatsPerBar;
  int beatUnit;
  GridDivision gridDivision;

  ProjectTiming({
    this.bpm = 120,
    this.beatsPerBar = 4,
    this.beatUnit = 4,
    this.gridDivision = GridDivision.eighth,
  });

  /// Seconds per beat.
  double get secondsPerBeat => 60.0 / bpm;

  /// Seconds per bar.
  double get secondsPerBar => secondsPerBeat * beatsPerBar;

  /// Grid step in beats.
  double get gridStepBeats => switch (gridDivision) {
    GridDivision.quarter  => 1.0,
    GridDivision.eighth   => 0.5,
    GridDivision.sixteenth => 0.25,
  };

  /// Grid step in seconds.
  double get gridStepSeconds => gridStepBeats * secondsPerBeat;

  /// Convert seconds to beats.
  double secondsToBeats(double s) => s * (bpm / 60.0);

  /// Convert beats to seconds.
  double beatsToSeconds(double b) => b * (60.0 / bpm);

  /// Snap time (seconds) to nearest grid point.
  double snapToGrid(double seconds) {
    final beats = secondsToBeats(seconds);
    final step = gridStepBeats;
    final snapped = (beats / step).round() * step;
    return beatsToSeconds(snapped).clamp(0, double.infinity);
  }

  /// Format time as bar.beat.sub (e.g. "3.2.1").
  String formatBarBeatSub(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds < 0) return '1.1.1';
    final totalBeats = secondsToBeats(seconds);
    final bar = (totalBeats / beatsPerBar).floor() + 1;
    final beatInBar = (totalBeats % beatsPerBar).floor() + 1;
    final subBeat = ((totalBeats % 1) * 4).floor() + 1;
    return '$bar.$beatInBar.$subBeat';
  }
}

// ─── Loop region ───

class LoopRegion {
  double startTime;
  double endTime;
  bool isActive;

  LoopRegion({this.startTime = 0, this.endTime = 0, this.isActive = false});

  double get duration => endTime - startTime;
  bool get isValid => endTime > startTime && duration > 0;
}

// ─── FX system ───

enum FxPresetId { clean, rap, pop, wideStar }

class FxPreset {
  final FxPresetId id;
  final String label;
  final String icon; // emoji-free label hint
  final double compThreshold;
  final double compRatio;
  final double compAttack;
  final double compRelease;
  final double eqLowGain;
  final double eqMidGain;
  final double eqHighGain;
  final double reverbMix;
  final double pitchShift; // semitones for autotune nudge

  const FxPreset({
    required this.id,
    required this.label,
    this.icon = '',
    this.compThreshold = -24,
    this.compRatio = 4,
    this.compAttack = 0.003,
    this.compRelease = 0.25,
    this.eqLowGain = 0,
    this.eqMidGain = 0,
    this.eqHighGain = 0,
    this.reverbMix = 0,
    this.pitchShift = 0,
  });
}

const kFxPresets = <FxPreset>[
  FxPreset(
    id: FxPresetId.clean, label: 'Clean',
    compThreshold: -20, compRatio: 2, compAttack: 0.01, compRelease: 0.3,
    eqLowGain: 0, eqMidGain: 0, eqHighGain: 1,
    reverbMix: 0.05,
  ),
  FxPreset(
    id: FxPresetId.rap, label: 'Rap',
    compThreshold: -16, compRatio: 6, compAttack: 0.002, compRelease: 0.15,
    eqLowGain: 3, eqMidGain: 2, eqHighGain: 4,
    reverbMix: 0.08,
  ),
  FxPreset(
    id: FxPresetId.pop, label: 'Pop',
    compThreshold: -22, compRatio: 3, compAttack: 0.005, compRelease: 0.25,
    eqLowGain: -1, eqMidGain: 3, eqHighGain: 2,
    reverbMix: 0.3,
  ),
  FxPreset(
    id: FxPresetId.wideStar, label: 'Wide Star',
    compThreshold: -20, compRatio: 3.5, compAttack: 0.004, compRelease: 0.2,
    eqLowGain: 1, eqMidGain: 1.5, eqHighGain: 3,
    reverbMix: 0.22, pitchShift: 0.15,
  ),
];

/// Musical keys for autotune.
enum MusicalKey { cMajor, cMinor, dMajor, dMinor, eMajor, eMinor, fMajor, gMajor, aMinor, bMinor }

const kKeyLabels = <MusicalKey, String>{
  MusicalKey.cMajor: 'C Major',
  MusicalKey.cMinor: 'C Minor',
  MusicalKey.dMajor: 'D Major',
  MusicalKey.dMinor: 'D Minor',
  MusicalKey.eMajor: 'E Major',
  MusicalKey.eMinor: 'E Minor',
  MusicalKey.fMajor: 'F Major',
  MusicalKey.gMajor: 'G Major',
  MusicalKey.aMinor: 'A Minor',
  MusicalKey.bMinor: 'B Minor',
};

/// Per-track FX state.
class TrackFx {
  bool enabled;
  FxPresetId presetId;
  double intensity; // 0..1, scales all FX parameters

  // Autotune
  bool autotuneEnabled;
  double autotuneStrength; // 0..1 (0=off, 1=full snap)
  MusicalKey autotuneKey;

  TrackFx({
    this.enabled = false,
    this.presetId = FxPresetId.clean,
    this.intensity = 0.7,
    this.autotuneEnabled = false,
    this.autotuneStrength = 0.5,
    this.autotuneKey = MusicalKey.cMajor,
  });

  FxPreset get preset => kFxPresets.firstWhere((p) => p.id == presetId);
}

// ─── Audio clip ───

class AudioClip {
  final String id;
  JSObject? buffer;
  double startTime;
  double offset;
  double clipDuration;
  Float32List? waveformCache;

  AudioClip({
    required this.id,
    this.buffer,
    this.startTime = 0,
    this.offset = 0,
    this.clipDuration = 0,
    this.waveformCache,
  });

  double get bufferDuration {
    if (buffer == null) return 0;
    return (buffer!['duration'] as JSNumber).toDartDouble;
  }

  double get endTime => startTime + clipDuration;
  double get maxDuration => bufferDuration - offset;
  bool get hasAudio => buffer != null && clipDuration > 0;

  static const double minDuration = 0.1;
}

// ─── Track ───

class StudioTrack {
  final String id;
  String name;
  final List<AudioClip> clips;
  double volume;
  bool isMuted;
  bool isSolo;
  final bool isBeat;
  final TrackFx fx;

  static const int maxClipsPerTrack = 10;

  StudioTrack({
    required this.id,
    required this.name,
    List<AudioClip>? clips,
    this.volume = 1.0,
    this.isMuted = false,
    this.isSolo = false,
    this.isBeat = false,
    TrackFx? fx,
  }) : clips = clips ?? [],
       fx = fx ?? TrackFx();

  double get duration {
    if (clips.isEmpty) return 0;
    double d = 0;
    for (final c in clips) {
      if (c.endTime > d) d = c.endTime;
    }
    return d;
  }

  bool get hasAudio => clips.any((c) => c.hasAudio);
  bool get canAddClip => clips.length < maxClipsPerTrack;

  AudioClip? addClip(JSObject buffer, double startTime, {Float32List? waveform}) {
    if (!canAddClip) return null;
    final bufDur = (buffer['duration'] as JSNumber).toDartDouble;
    final clip = AudioClip(
      id: '${id}_clip_${clips.length}_${DateTime.now().millisecondsSinceEpoch}',
      buffer: buffer,
      startTime: startTime,
      offset: 0,
      clipDuration: bufDur,
      waveformCache: waveform,
    );
    clips.add(clip);
    return clip;
  }

  void removeClip(String clipId) => clips.removeWhere((c) => c.id == clipId);
}
