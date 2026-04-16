import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import '../domain/track_model.dart';
import 'suggestion_model.dart';

/// Analyzes the multitrack project and produces AI suggestions.
///
/// Rules-based MVP — runs client-side with no network calls.
class AiAnalyzer {
  int _idCounter = 0;
  String _nextId() => 'sug_${_idCounter++}';

  /// Analyze all tracks and return up to [maxSuggestions] suggestions.
  List<AiSuggestion> analyze(
    List<StudioTrack> tracks,
    ProjectTiming timing, {
    int maxSuggestions = 4,
  }) {
    final suggestions = <AiSuggestion>[];
    final vocalTracks = tracks.where((t) => !t.isBeat).toList();
    final allVocalClips = vocalTracks.expand((t) => t.clips).toList();

    if (allVocalClips.isEmpty) return suggestions;

    // ─── 1. Off-grid clips → "Выровняй вокал" ───
    _checkGridAlignment(allVocalClips, timing, vocalTracks, suggestions);

    // ─── 2. Single vocal track → "Сделай дабл" ───
    _checkNeedDouble(vocalTracks, allVocalClips, suggestions);

    // ─── 3. Long gaps → "Добавь адлиб" ───
    _checkGaps(allVocalClips, tracks, timing, suggestions);

    // ─── 4. Low energy clips → "Усиль вокал" ───
    _checkLowEnergy(allVocalClips, vocalTracks, suggestions);

    // ─── 5. No FX enabled → "Улучши звук" ───
    _checkNoFx(vocalTracks, suggestions);

    // ─── 6. No reverb → "Добавь пространство" ───
    _checkNoReverb(vocalTracks, suggestions);

    // Limit and return
    suggestions.sort((a, b) => a.position.compareTo(b.position));
    return suggestions.take(maxSuggestions).toList();
  }

  void _checkGridAlignment(
    List<AudioClip> clips,
    ProjectTiming timing,
    List<StudioTrack> tracks,
    List<AiSuggestion> out,
  ) {
    int offGrid = 0;
    double firstOffPos = 0;
    String? firstTrackId;

    for (final t in tracks) {
      for (final c in t.clips) {
        final snapped = timing.snapToGrid(c.startTime);
        if ((c.startTime - snapped).abs() > timing.gridStepSeconds * 0.15) {
          offGrid++;
          if (offGrid == 1) {
            firstOffPos = c.startTime;
            firstTrackId = t.id;
          }
        }
      }
    }

    if (offGrid > 0) {
      out.add(AiSuggestion(
        id: _nextId(),
        text: 'Выровнять вокал по сетке ($offGrid клип${_plural(offGrid)})',
        type: SuggestionType.timing,
        position: firstOffPos,
        action: SuggestionAction.fixTiming,
        targetTrackId: firstTrackId,
      ));
    }
  }

  void _checkNeedDouble(
    List<StudioTrack> vocalTracks,
    List<AudioClip> allClips,
    List<AiSuggestion> out,
  ) {
    // If only one vocal track with clips, and no duplicates close in time
    final tracksWithClips = vocalTracks.where((t) => t.hasAudio).toList();
    if (tracksWithClips.length == 1 && allClips.isNotEmpty) {
      final clip = allClips.first;
      out.add(AiSuggestion(
        id: _nextId(),
        text: 'Сделай дабл для плотности',
        type: SuggestionType.vocal,
        position: clip.startTime,
        action: SuggestionAction.addDouble,
        targetTrackId: tracksWithClips.first.id,
        targetClipId: clip.id,
      ));
    }
  }

  void _checkGaps(
    List<AudioClip> clips,
    List<StudioTrack> allTracks,
    ProjectTiming timing,
    List<AiSuggestion> out,
  ) {
    if (clips.length < 2) return;

    final sorted = List<AudioClip>.from(clips)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final minGap = timing.secondsPerBar * 2; // 2 bars gap = suggest adlib

    for (int i = 0; i < sorted.length - 1; i++) {
      final gap = sorted[i + 1].startTime - sorted[i].endTime;
      if (gap >= minGap) {
        final gapMid = sorted[i].endTime + gap / 2;
        out.add(AiSuggestion(
          id: _nextId(),
          text: 'Пауза ${(gap).toStringAsFixed(1)}с — добавь адлиб',
          type: SuggestionType.structure,
          position: gapMid,
          action: SuggestionAction.addAdlib,
        ));
        break; // max one gap suggestion
      }
    }
  }

  void _checkLowEnergy(
    List<AudioClip> clips,
    List<StudioTrack> tracks,
    List<AiSuggestion> out,
  ) {
    for (final t in tracks) {
      for (final c in t.clips) {
        if (c.waveformCache == null || c.waveformCache!.isEmpty) continue;
        // Calculate average RMS from waveform peaks
        double sum = 0;
        for (final v in c.waveformCache!) sum += v;
        final avg = sum / c.waveformCache!.length;

        if (avg < 0.08) {
          out.add(AiSuggestion(
            id: _nextId(),
            text: 'Тихий вокал — усиль звук',
            type: SuggestionType.mix,
            position: c.startTime,
            action: SuggestionAction.boostVocal,
            targetTrackId: t.id,
          ));
          return; // one is enough
        }
      }
    }
  }

  void _checkNoFx(List<StudioTrack> tracks, List<AiSuggestion> out) {
    for (final t in tracks) {
      if (t.hasAudio && !t.fx.enabled) {
        out.add(AiSuggestion(
          id: _nextId(),
          text: 'Включи обработку на ${t.name}',
          type: SuggestionType.mix,
          position: t.clips.isNotEmpty ? t.clips.first.startTime : 0,
          action: SuggestionAction.enhance,
          targetTrackId: t.id,
        ));
        return;
      }
    }
  }

  void _checkNoReverb(List<StudioTrack> tracks, List<AiSuggestion> out) {
    for (final t in tracks) {
      if (t.hasAudio && t.fx.enabled && t.fx.preset.reverbMix < 0.1) {
        out.add(AiSuggestion(
          id: _nextId(),
          text: 'Добавь пространство (reverb)',
          type: SuggestionType.mix,
          position: t.clips.isNotEmpty ? t.clips.first.startTime : 0,
          action: SuggestionAction.addReverb,
          targetTrackId: t.id,
        ));
        return;
      }
    }
  }

  String _plural(int n) {
    if (n == 1) return '';
    if (n < 5) return 'а';
    return 'ов';
  }
}
