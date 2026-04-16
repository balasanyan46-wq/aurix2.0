import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

// ═══════════════════════════════════════════════════════
// JS BRIDGE — typed access to window.studioEngine
// ═══════════════════════════════════════════════════════

JSObject? get _eng {
  final e = globalContext['studioEngine'];
  return e is JSObject ? e : null;
}

JSAny? _j(String m) => _eng?.callMethod(m.toJS);
JSAny? _j1(String m, JSAny? a) => _eng?.callMethod(m.toJS, a);

void jsInit() => _j('init');
void jsPlay() => _j('play');
void jsPause() => _j('pause');
void jsStop() => _j('stop');
void jsSeek(double t) => _j1('seekTo', t.toJS);
double jsPlayhead() => (_j('getPlayhead') as JSNumber?)?.toDartDouble ?? 0;
bool jsIsPlaying() => (_j('isPlaying') as JSBoolean?)?.toDart ?? false;
bool jsIsRec() => (_j('isRecording') as JSBoolean?)?.toDart ?? false;
double jsBPM() => (_j('getBPM') as JSNumber?)?.toDartDouble ?? 120;
double jsTotalDur() => (_j('getTotalDuration') as JSNumber?)?.toDartDouble ?? 4;
String jsTracksJSON() => (_j('getTracksJSON') as JSString?)?.toDart ?? '[]';
String jsExport() => (_j('exportWAV') as JSString?)?.toDart ?? '';
void jsAddTrack(String id, String n, bool beat) =>
    _j1('addTrackJSON', '{"id":"$id","name":"$n","isBeat":$beat}'.toJS);
void jsRemoveTrack(String id) => _j1('removeTrack', id.toJS);
void jsSetVol(String id, double v) => _j1('setVolumeJSON', '{"id":"$id","vol":$v}'.toJS);
void jsSetPan(String id, double v) => _j1('setPanJSON', '{"id":"$id","pan":$v}'.toJS);
void jsMute(String id) => _j1('toggleMute', id.toJS);
void jsSolo(String id) => _j1('toggleSolo', id.toJS);
Future<void> jsLoad(String id, JSAny ab) async {
  // loadAudio needs 2 args — use eval approach
  final eng = _eng;
  if (eng == null) return;
  final fn = eng.getProperty('loadAudio'.toJS) as JSFunction;
  await (fn.callAsFunction(eng, id.toJS, ab) as JSPromise).toDart;
}
Future<JSAny?> jsStartRec(String id) async => await (_j1('startRecording', id.toJS) as JSPromise).toDart;
Future<JSAny?> jsStopRec() async => await (_j('stopRecording') as JSPromise).toDart;

String jsLastClipId(String trackId) =>
    (_j1('getLastClipId', trackId.toJS) as JSString?)?.toDart ?? '';

Uint8List jsClipWAV(String clipId) {
  final res = _j1('exportClipWAVBytes', clipId.toJS);
  if (res == null) return Uint8List(0);
  final arr = res as JSUint8Array;
  return arr.toDart;
}

// Always use ORIGINAL buffer for correction (prevent stacking)
Uint8List jsOriginalClipWAV(String clipId) {
  final res = _j1('exportOriginalClipWAVBytes', clipId.toJS);
  if (res == null) return Uint8List(0);
  final arr = res as JSUint8Array;
  return arr.toDart;
}

Future<bool> jsReplaceClip(String clipId, JSAny ab) async {
  final eng = _eng;
  if (eng == null) return false;
  final fn = eng.getProperty('replaceClipAudio'.toJS) as JSFunction;
  final res = await (fn.callAsFunction(eng, clipId.toJS, ab) as JSPromise).toDart;
  return res is JSBoolean ? res.toDart : false;
}

// Clip editing
void jsDeleteClip(String clipId) => _j1('deleteClip', clipId.toJS);
void jsDuplicateClip(String clipId) => _j1('duplicateClip', clipId.toJS);
String jsSplitClipAt(String clipId, double t) {
  final eng = _eng;
  if (eng == null) return '';
  final fn = eng.getProperty('splitClipAt'.toJS) as JSFunction;
  final res = fn.callAsFunction(eng, clipId.toJS, t.toJS);
  return (res as JSString?)?.toDart ?? '';
}
void jsSelectClip(String clipId) => _j1('selectClip', clipId.toJS);

// FX
void jsSetFX(String id, double reverb, double delay) =>
    _j1('setTrackFXJSON', '{"id":"$id","reverb":$reverb,"delay":$delay}'.toJS);

// Metronome
bool jsToggleMetronome() => (_j('toggleMetronome') as JSBoolean?)?.toDart ?? false;
bool jsMetOn() => (_j('isMetronomeOn') as JSBoolean?)?.toDart ?? false;

// Loop
void jsSetLoop(double start, double end, bool on) =>
    _j1('setLoopRegionJSON', '{"start":$start,"end":$end,"on":$on}'.toJS);
bool jsLoopOn() => (_j('isLoopOn') as JSBoolean?)?.toDart ?? false;
double jsLoopStart() => (_j('getLoopStart') as JSNumber?)?.toDartDouble ?? 0;
double jsLoopEnd() => (_j('getLoopEnd') as JSNumber?)?.toDartDouble ?? 4;

// Track reorder
void jsMoveTrack(String id, int index) =>
    _j1('moveTrackToJSON', '{"id":"$id","index":$index}'.toJS);

// Audio devices
Future<String> jsGetDevices() async {
  final eng = _eng;
  if (eng == null) return '{"inputs":[],"outputs":[]}';
  final fn = eng.getProperty('getAudioDevices'.toJS) as JSFunction;
  final res = await (fn.callAsFunction(eng) as JSPromise).toDart;
  return (res as JSString?)?.toDart ?? '{"inputs":[],"outputs":[]}';
}
void jsSetInput(String id) => _j1('setInputDevice', id.toJS);
void jsSetOutput(String id) => _j1('setOutputDevice', id.toJS);
void jsSetInputLatency(int ms) => _j1('setInputLatency', ms.toJS);
int jsGetInputLatency() => ((_j('getInputLatency') as JSNumber?)?.toDartDouble ?? 120).toInt();

/// Возвращает (rms, peak) текущего уровня микрофона как пара 0..1.
({double rms, double peak}) jsRecLevel() {
  final s = (_j('getRecordingLevel') as JSString?)?.toDart ?? '0,0';
  final parts = s.split(',');
  final rms = double.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
  final peak = double.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  return (rms: rms, peak: peak);
}

/// Огибающая последних N точек записи (для рисования live-волны).
List<double> jsRecSamples([int n = 500]) {
  final res = _j1('getRecordingSamples', n.toJS);
  if (res == null) return const [];
  try {
    final arr = res as JSFloat32Array;
    return arr.toDart.toList();
  } catch (_) {
    return const [];
  }
}

// Clip move (drag)
void jsMoveClip(String clipId, double newStart) {
  final eng = _eng;
  if (eng == null) return;
  final fn = eng.getProperty('moveClip'.toJS) as JSFunction;
  fn.callAsFunction(eng, clipId.toJS, newStart.toJS);
}

// ═══════════════════════════════════════════════════════
// DATA MODELS (from JSON)
// ═══════════════════════════════════════════════════════

class _Trk {
  final String id, name, color;
  double volume, pan, reverb, delay;
  bool mute, solo, isBeat;
  final List<_Clip> clips;
  _Trk(this.id, this.name, this.color, this.volume, this.pan, this.mute, this.solo, this.isBeat,
       this.reverb, this.delay, this.clips);
  factory _Trk.fromJson(Map<String, dynamic> j) => _Trk(
    j['id'], j['name'], j['color'],
    (j['volume'] as num).toDouble(), (j['pan'] as num).toDouble(),
    j['mute'] ?? false, j['solo'] ?? false, j['isBeat'] ?? false,
    ((j['reverb'] ?? 0) as num).toDouble(), ((j['delay'] ?? 0) as num).toDouble(),
    (j['clips'] as List).map((c) => _Clip.fromJson(c)).toList());
}

class _Clip {
  final String id;
  final double startTime, offset, duration;
  final List<double> peaks;
  _Clip(this.id, this.startTime, this.offset, this.duration, this.peaks);
  factory _Clip.fromJson(Map<String, dynamic> j) => _Clip(
    j['id'], (j['startTime'] as num).toDouble(), (j['offset'] as num).toDouble(),
    (j['duration'] as num).toDouble(),
    (j['peaks'] as List).map((p) => (p as num).toDouble()).toList());
}

// ═══════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════

class StudioModeScreen extends StatefulWidget {
  const StudioModeScreen({super.key});
  @override State<StudioModeScreen> createState() => _S();
}

class _S extends State<StudioModeScreen> with TickerProviderStateMixin {
  bool _ok = false;
  double _ph = 0, _zoom = 1.0;
  List<_Trk> _trks = [];
  Ticker? _tick;
  String? _actId;
  String? _selClipId;        // currently selected clip (for edit shortcuts)
  final _focus = FocusNode();
  bool _loading = false;

  // Correction state (persists between sheet opens)
  String _corrStyle = 'wide_star';
  bool _corrAuto = true;
  String _corrKey = 'C_major';
  double _corrStrength = 0.5;
  String _corrPreset = 'hit';
  bool _correcting = false;
  String _corrStage = '';

  // Metronome + loop
  bool _metOn = false;
  bool _loopOn = false;
  double _loopStart = 0, _loopEnd = 4;

  // Side panels
  bool _showLyrics = false;

  // Live recording meter
  Ticker? _recTick;
  double _recRms = 0, _recPeak = 0;
  List<double> _recLiveSamples = const [];

  // Help overlay
  bool _showHelp = false;

  // Full-screen processing overlay
  bool _processingOpen = false;
  String _processingTitle = '';
  String _processingDetail = '';

  // Undo stack — каждое действие сохраняет JSON состояния треков
  final List<String> _undoStack = [];
  static const _undoMax = 20;

  // Lyrics
  final _lyricsCtl = TextEditingController();
  bool _lyricsAiBusy = false;

  double get _pps => 60 * _zoom;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  int _retries = 0;
  bool _initialized = false;  // защита от повторного добавления beat/vocal1

  void _init() {
    if (_initialized) return; // уже отработали — ни в коем случае не добавляем заново
    if (_retries >= 5) {
      debugPrint('[S] Giving up after $_retries retries');
      if (mounted) setState(() => _ok = true);
      return;
    }

    if (_eng == null) {
      _retries++;
      debugPrint('[S] Engine not ready, retry $_retries');
      Future.delayed(const Duration(milliseconds: 500), _init);
      return;
    }

    try {
      jsInit();
      jsAddTrack('beat', 'Beat', true);
      jsAddTrack('vocal1', 'Vocal 1', false);
      _actId = 'vocal1';
      _sync();
      _initialized = true;
      debugPrint('[S] OK: ${_trks.length} tracks');
      if (mounted) setState(() => _ok = true);
      _focus.requestFocus();
    } catch (e) {
      debugPrint('[S] Init error: $e');
      _retries++;
      Future.delayed(const Duration(milliseconds: 1000), _init);
    }
  }

  @override void dispose() {
    _tick?.dispose();
    _recTick?.dispose();
    _focus.dispose();
    _lyricsCtl.dispose();
    jsStop();
    super.dispose();
  }

  void _sync() {
    _trks = (jsonDecode(jsTracksJSON()) as List).map((j) => _Trk.fromJson(j)).toList();
  }

  void _startTick() {
    _tick?.dispose();
    // На мобилке ticker triggerит лишь каждый ~3-й кадр — снижает нагрузку
    // на CPU/GPU при перерисовке всего таймлайна.
    final isMobile = MediaQuery.of(context).size.width < 700;
    int frame = 0;
    _tick = createTicker((_) {
      frame++;
      if (isMobile && frame % 3 != 0) return;
      if (!mounted) return;
      final p = jsPlayhead();
      if ((p - _ph).abs() > 0.015) setState(() => _ph = p);
    })..start();
  }
  void _stopTick() => _tick?.stop();

  // ── Actions ──
  Future<void> _loadBeat() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (r == null || r.files.isEmpty || r.files.first.bytes == null) return;
    setState(() => _loading = true);
    try {
      final ab = r.files.first.bytes!.toJS.getProperty('buffer'.toJS)!;
      await jsLoad('beat', ab);
      _sync();
    } catch (e) { debugPrint('[S] beat err: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  void _play() {
    if (jsIsPlaying()) { jsPause(); _stopTick(); } else { jsPlay(); _startTick(); }
    setState(() {});
  }

  Future<void> _rec() async {
    if (jsIsRec()) {
      await jsStopRec();
      _stopTick();
      _stopRecTick();
      _sync();
      setState(() {});
    } else if (_actId != null) {
      _pushUndo();
      final ok = await jsStartRec(_actId!);
      if (ok is JSBoolean && ok.toDart) {
        _startTick();
        _startRecTick();
      }
      setState(() {});
    }
  }

  // Live meter ticker — на десктопе ~30fps, на мобильнике ~15fps.
  void _startRecTick() {
    _recTick?.dispose();
    final isMobile = MediaQuery.of(context).size.width < 700;
    int frame = 0;
    _recTick = createTicker((_) {
      frame++;
      if (isMobile && frame % 4 != 0) return;
      if (!isMobile && frame % 2 != 0) return;
      if (!mounted || !jsIsRec()) return;
      final lvl = jsRecLevel();
      // Меньше точек на мобилке — рисуется быстрее
      final samples = jsRecSamples(isMobile ? 180 : 400);
      if ((lvl.peak - _recPeak).abs() > 0.01 ||
          samples.length != _recLiveSamples.length) {
        setState(() {
          _recRms = lvl.rms;
          _recPeak = lvl.peak;
          _recLiveSamples = samples;
        });
      }
    })..start();
  }

  void _stopRecTick() {
    _recTick?.dispose();
    _recTick = null;
    _recRms = 0;
    _recPeak = 0;
    _recLiveSamples = const [];
  }

  // Заглушка для будущего undo — пока просто фиксируем точку истории.
  void _pushUndo() {
    _undoStack.add(jsTracksJSON());
    if (_undoStack.length > _undoMax) _undoStack.removeAt(0);
  }

  void _addTrack() {
    final id = 'v${_trks.length}_${DateTime.now().millisecondsSinceEpoch}';
    jsAddTrack(id, 'Vocal ${_trks.where((t) => !t.isBeat).length + 1}', false);
    _actId = id; _sync(); setState(() {});
  }

  // ── Correction (send clip to server, receive processed WAV, replace) ──
  _Trk? get _activeVocal {
    if (_actId == null) return null;
    for (final t in _trks) {
      if (t.id == _actId && !t.isBeat && t.clips.isNotEmpty) return t;
    }
    return null;
  }

  Future<void> _applyCorrection() async {
    final t = _activeVocal;
    if (t == null) return;
    final clipId = jsLastClipId(t.id);
    if (clipId.isEmpty) return;

    // Закрываем sheet сразу — дальше показываем полноэкранный оверлей
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();

    setState(() {
      _processingOpen = true;
      _processingTitle = 'Коррекция голоса';
      _processingDetail = 'Подготовка клипа...';
      _correcting = true;
    });

    try {
      // 1. Грабим ОРИГИНАЛЬНЫЙ WAV (чтобы коррекция не накладывалась повторно)
      final wav = jsOriginalClipWAV(clipId);
      if (wav.isEmpty) throw Exception('Пустой клип');

      if (mounted) setState(() => _processingDetail = 'Загрузка на сервер...');

      // 2. POST to /api/ai/process-vocal
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(wav, filename: 'vocal.wav'),
      });

      final res = await ApiClient.dio.post(
        '/api/ai/process-vocal',
        data: form,
        queryParameters: {
          'preset': _corrPreset,
          'autotune': _corrAuto ? 'on' : 'off',
          'strength': _corrStrength.toString(),
          'key': _corrKey,
          'style': _corrStyle,
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 60),
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _processingDetail = 'Загрузка ${(sent * 100 / total).round()}%');
          }
        },
        onReceiveProgress: (got, total) {
          if (mounted) {
            setState(() => _processingDetail = total > 0
              ? 'Получаем результат ${(got * 100 / total).round()}%'
              : 'Получаем результат...');
          }
        },
      );

      if (mounted) setState(() => _processingDetail = 'Применяем к треку...');

      // 3. Replace clip buffer with processed WAV
      final bytes = Uint8List.fromList(res.data as List<int>);
      final ab = bytes.toJS.getProperty('buffer'.toJS)!;
      final ok = await jsReplaceClip(clipId, ab);
      if (!ok) throw Exception('Не удалось применить');

      _sync();
      if (!mounted) return;
      setState(() {
        _correcting = false;
        _processingOpen = false;
        _processingDetail = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Коррекция применена ✓'),
        backgroundColor: Color(0xFF1E1E24),
        duration: Duration(seconds: 2)));
    } catch (e) {
      debugPrint('[S] correction err: $e');
      if (!mounted) return;
      setState(() {
        _correcting = false;
        _processingOpen = false;
        _processingDetail = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ошибка коррекции: ${e.toString().replaceAll('Exception: ', '')}'),
        backgroundColor: const Color(0xFFFF4444)));
    }
  }

  void _openCorrection() {
    final t = _activeVocal;
    if (t == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Выбери вокальный трек с записью'),
        backgroundColor: Color(0xFF1E1E24)));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CorrectionSheet(
        trackName: t.name,
        style: _corrStyle,
        auto: _corrAuto,
        scaleKey: _corrKey,
        strength: _corrStrength,
        preset: _corrPreset,
        busy: _correcting,
        stage: _corrStage,
        onChange: (s, a, k, st, p) => setState(() {
          _corrStyle = s; _corrAuto = a; _corrKey = k; _corrStrength = st; _corrPreset = p;
        }),
        onApply: _applyCorrection,
      ),
    );
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space)  { _play(); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.keyR)   { _rec();  return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.keyM)   { _toggleMetronome(); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.keyL)   { _toggleLoop(); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.keyS)   { _splitAtPlayhead(); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.keyD)   { _duplicateSelected(); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) {
      _deleteSelected(); return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.equal) { setState(() => _zoom = (_zoom * 1.2).clamp(0.3, 5)); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.minus) { setState(() => _zoom = (_zoom / 1.2).clamp(0.3, 5)); return KeyEventResult.handled; }
    return KeyEventResult.ignored;
  }

  // ── Clip editing actions ──
  void _splitAtPlayhead() {
    // Split selected clip at current playhead; if none selected, split any clip
    // the playhead is currently over on the active track.
    String? target = _selClipId;
    if (target == null && _actId != null) {
      for (final t in _trks) {
        if (t.id != _actId) continue;
        for (final c in t.clips) {
          if (_ph > c.startTime && _ph < c.startTime + c.duration) { target = c.id; break; }
        }
      }
    }
    if (target == null) return;
    final newId = jsSplitClipAt(target, _ph);
    if (newId.isNotEmpty) { _sync(); setState(() => _selClipId = newId); }
  }

  void _deleteSelected() {
    if (_selClipId == null) return;
    jsDeleteClip(_selClipId!);
    _sync();
    setState(() => _selClipId = null);
  }

  void _duplicateSelected() {
    if (_selClipId == null) return;
    jsDuplicateClip(_selClipId!);
    _sync();
    setState(() {});
  }

  // ── Metronome / Loop ──
  void _toggleMetronome() {
    jsToggleMetronome();
    setState(() => _metOn = jsMetOn());
  }

  void _toggleLoop() {
    _loopOn = !_loopOn;
    jsSetLoop(_loopStart, _loopEnd, _loopOn);
    setState(() {});
  }

  void _setLoopRegion(double start, double end) {
    _loopStart = math.max(0, start);
    _loopEnd = math.max(_loopStart + 0.2, end);
    _loopOn = true;
    jsSetLoop(_loopStart, _loopEnd, true);
    setState(() {});
  }

  // ── Per-track FX ──
  void _setTrackFX(String id, double reverb, double delay) {
    jsSetFX(id, reverb, delay);
    for (final t in _trks) {
      if (t.id == id) { t.reverb = reverb; t.delay = delay; break; }
    }
    setState(() {});
  }

  // ═══════════════════════════════════════════════════════
  // BUILD — Pro DAW layout
  // ═══════════════════════════════════════════════════════

  @override Widget build(BuildContext context) {
    if (!_ok) return const Scaffold(backgroundColor: Color(0xFF111115),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFFF6A1A))));

    final playing = jsIsPlaying();
    final rec = jsIsRec();
    final hasBeat = _trks.any((t) => t.isBeat && t.clips.isNotEmpty);
    final dur = jsTotalDur();
    final bpm = jsBPM();
    final W = MediaQuery.sizeOf(context).width;
    final isMobile = W < 700;
    // На мобиле прячем FX-strip и уменьшаем боковые панели — иначе на 590px
    // не остаётся места для таймлайна и всё дублируется/слипается.
    final leftW = isMobile ? 96.0 : 180.0;
    final fxW = isMobile ? 0.0 : 140.0;
    final toolW = isMobile ? 38.0 : 46.0;
    final timeW = math.max(dur * _pps, W - leftW - fxW - toolW);

    final lyricsW = W >= 900 ? 340.0 : math.min(W * 0.85, 320.0);
    return Focus(focusNode: _focus, onKeyEvent: _onKey, autofocus: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF111115),
        body: Stack(children: [
          SafeArea(child: Column(children: [
            // ── MAIN AREA: sidebar + tracks + timeline ──
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // LEFT: track headers
              Container(
                width: leftW,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E16),
                  border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
                child: Column(children: [
                  SizedBox(height: 28, child: Center(child: Text('TRACKS', style: TextStyle(
                    fontFamily: AurixTokens.fontMono, fontSize: 9, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.2), letterSpacing: 2)))),
                  Expanded(child: ListView(physics: const BouncingScrollPhysics(), children: [
                    for (final t in _trks) _trackHeader(t, leftW, playing),
                    _addBtn(leftW),
                  ])),
                ]),
              ),
              // FX STRIP column — только на десктопе. На мобильнике FX открывается
              // тапом по треку (см. _trackHeader → tap to open FX bottom-sheet).
              if (!isMobile) Container(
                width: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0B12),
                  border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
                child: Column(children: [
                  SizedBox(height: 28, child: Center(child: Text('ОБРАБОТКА', style: TextStyle(
                    fontFamily: AurixTokens.fontMono, fontSize: 8, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.25), letterSpacing: 1.5)))),
                  Expanded(child: ListView(physics: const BouncingScrollPhysics(), children: [
                    for (final t in _trks) _fxStrip(t),
                    const SizedBox(height: 44),
                  ])),
                ]),
              ),
              // CENTER: timeline + waveforms
              Expanded(child: Column(children: [
                // Ruler
                SizedBox(height: 28, child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) {
                      final t = d.localPosition.dx / _pps;
                      jsSeek(t); setState(() => _ph = t);
                    },
                    onHorizontalDragStart: (d) {
                      final t = d.localPosition.dx / _pps;
                      _setLoopRegion(t, t + 0.2);
                    },
                    onHorizontalDragUpdate: (d) {
                      final t = d.localPosition.dx / _pps;
                      _setLoopRegion(_loopStart, t);
                    },
                    child: CustomPaint(size: Size(timeW, 28),
                      painter: _Ruler(
                        pps: _pps, ph: _ph, dur: dur, bpm: bpm,
                        loopOn: _loopOn, loopStart: _loopStart, loopEnd: _loopEnd)),
                  ))),
                // Waveforms
                Expanded(child: Stack(children: [
                  // Тяжёлые волны клипов — выносим в RepaintBoundary, чтобы
                  // обновление playhead не вызывало их перерисовку.
                  RepaintBoundary(
                    child: ListView(physics: const BouncingScrollPhysics(), children: [
                      for (final t in _trks) _trackWave(t, timeW, bpm),
                      const SizedBox(height: 80),
                    ]),
                  ),
                  // Playhead в собственном RepaintBoundary
                  Positioned(left: _ph * _pps, top: 0, bottom: 0, width: 2,
                    child: IgnorePointer(child: RepaintBoundary(
                      child: Container(color: const Color(0xFFFF6A1A))))),
                ])),
              ])),
              // RIGHT: tools sidebar
              _toolsSidebar(hasBeat),
            ])),

            // ── TRANSPORT BAR (bottom) ──
            _transportBar(playing, rec, hasBeat, bpm),
          ])),

          // Lyrics side drawer (slides in from the right)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            top: 0, bottom: 0,
            right: _showLyrics ? 0 : -lyricsW - 20,
            width: lyricsW,
            child: _lyricsDrawer(lyricsW),
          ),

          // Loading overlay
          if (_loading) Positioned.fill(child: Container(color: Colors.black54,
            child: const Center(child: CircularProgressIndicator(color: Color(0xFFFF6A1A))))),

          // Live recording HUD — пик-метр в правом нижнем углу
          if (jsIsRec()) Positioned(
            right: 60, bottom: 24,
            child: _RecHud(rms: _recRms, peak: _recPeak),
          ),

          // Help floating button — над transport bar чтоб не перекрывал плеер
          Positioned(
            right: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 80,
            child: FloatingActionButton.small(
              heroTag: 'studio_help',
              backgroundColor: const Color(0xFF7B5CFF),
              foregroundColor: Colors.white,
              tooltip: 'Помощь по студии',
              onPressed: () => setState(() => _showHelp = true),
              child: const Icon(Icons.help_outline_rounded, size: 16),
            ),
          ),

          // Help overlay
          if (_showHelp) _StudioHelpOverlay(onClose: () => setState(() => _showHelp = false)),

          // Full-screen processing overlay (correction)
          if (_processingOpen) _ProcessingOverlay(
            title: _processingTitle,
            detail: _processingDetail,
            preset: _corrPreset,
            style: _corrStyle,
            autotune: _corrAuto,
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // LYRICS DRAWER — notes + AI helper
  // ═══════════════════════════════════════════════════════
  Widget _lyricsDrawer(double w) {
    return Material(
      color: const Color(0xFF0D0D12),
      elevation: 12,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(
            color: const Color(0xFF7B5CFF).withValues(alpha: 0.3), width: 2))),
        child: SafeArea(child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B5CFF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF7B5CFF).withValues(alpha: 0.3))),
                child: const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF7B5CFF)),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Текст + AI',
                style: TextStyle(
                  fontFamily: AurixTokens.fontHeading, fontSize: 15,
                  fontWeight: FontWeight.w700, color: Colors.white))),
              IconButton(
                onPressed: () => setState(() => _showLyrics = false),
                icon: Icon(Icons.close_rounded, size: 18,
                  color: Colors.white.withValues(alpha: 0.4))),
            ]),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          // Text area
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _lyricsCtl,
              maxLines: null, expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: AurixTokens.fontBody, fontSize: 13,
                color: Colors.white, height: 1.5),
              decoration: InputDecoration(
                hintText: 'Пиши текст песни сюда...\n\nAI поможет с:\n• куплетами\n• рифмами\n• хуком\n• идеями',
                hintStyle: TextStyle(
                  fontFamily: AurixTokens.fontBody, fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.2), height: 1.5),
                border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.zero),
            ),
          )),
          // AI buttons
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              _aiChip('💡 Идеи',      'Дай 5 идей для куплета в стиле этой темы:'),
              _aiChip('🎤 Куплет',    'Напиши цепкий куплет (4 строки) на эту тему:'),
              _aiChip('🎯 Хук',       'Придумай цепкий хук (2-4 строки) на эту тему:'),
              _aiChip('🔁 Рифмы',     'Дай 8 свежих рифм к последнему слову:'),
              _aiChip('✨ Докрути',   'Докрути и усиль этот текст, сохраняя смысл:'),
            ]),
          ),
          // Apply AI button
          Container(
            padding: EdgeInsets.fromLTRB(12, 4, 12,
              12 + MediaQuery.paddingOf(context).bottom),
            child: SizedBox(
              width: double.infinity, height: 44,
              child: ElevatedButton.icon(
                onPressed: _lyricsAiBusy ? null : () => _callAiLyrics(
                  'Улучши этот текст песни (сделай его сильнее, сохрани размер и рифму):'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B5CFF),
                  disabledBackgroundColor: const Color(0xFF7B5CFF).withValues(alpha: 0.2),
                  foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: _lyricsAiBusy
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(_lyricsAiBusy ? 'AI думает...' : 'Улучшить с AI',
                  style: const TextStyle(
                    fontFamily: AurixTokens.fontHeading, fontSize: 13,
                    fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ])),
      ),
    );
  }

  Widget _aiChip(String label, String promptPrefix) => GestureDetector(
    onTap: _lyricsAiBusy ? null : () => _callAiLyrics(promptPrefix),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: const Color(0xFF7B5CFF).withValues(alpha: 0.25))),
      child: Text(label, style: const TextStyle(
        fontFamily: AurixTokens.fontMono, fontSize: 10, fontWeight: FontWeight.w600,
        color: Colors.white)),
    ),
  );

  Future<void> _callAiLyrics(String promptPrefix) async {
    final current = _lyricsCtl.text.trim();
    if (_lyricsAiBusy) return;
    setState(() => _lyricsAiBusy = true);
    try {
      final body = current.isEmpty
        ? promptPrefix
        : '$promptPrefix\n\n---\n$current';
      final res = await ApiClient.dio.post(
        '/api/ai/chat',
        data: {'message': body, 'mode': 'lyrics'},
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
      final reply = ((res.data as Map)['reply'] ?? '').toString().trim();
      if (reply.isNotEmpty) {
        setState(() {
          // Append the AI response below current text (don't destroy user's work)
          if (current.isEmpty) {
            _lyricsCtl.text = reply;
          } else {
            _lyricsCtl.text = '$current\n\n— AI —\n$reply';
          }
          _lyricsCtl.selection = TextSelection.fromPosition(
            TextPosition(offset: _lyricsCtl.text.length));
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('AI недоступен: ${e.toString().replaceAll('Exception: ', '')}'),
        backgroundColor: const Color(0xFFFF4444)));
    }
    if (mounted) setState(() => _lyricsAiBusy = false);
  }

  // ── Track drag reorder ──
  void _moveTrack(String id, int dir) {
    final idx = _trks.indexWhere((t) => t.id == id);
    final ni = idx + dir;
    if (idx < 0 || ni < 0 || ni >= _trks.length) return;
    jsMoveTrack(id, ni);
    _sync();
    setState(() {});
  }

  // ── Device selector popup ──
  Future<void> _showDeviceSelector() async {
    final json = await jsGetDevices();
    final data = jsonDecode(json) as Map<String, dynamic>;
    final inputs = (data['inputs'] as List).cast<Map<String, dynamic>>();
    final outputs = (data['outputs'] as List).cast<Map<String, dynamic>>();
    if (!mounted) return;

    int latency = jsGetInputLatency();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('МИКРОФОН', style: TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 10,
              fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.5)),
            const SizedBox(height: 8),
            if (inputs.isEmpty) Text('Нет устройств', style: TextStyle(
              fontFamily: AurixTokens.fontBody, fontSize: 12, color: Colors.white.withValues(alpha: 0.3)))
            else ...inputs.map((d) => ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.mic_rounded, size: 16, color: Color(0xFFFF6A1A)),
              title: Text(d['label'] ?? '', style: const TextStyle(
                fontFamily: AurixTokens.fontBody, fontSize: 12, color: Colors.white)),
              onTap: () { jsSetInput(d['id'] ?? ''); Navigator.pop(ctx); },
            )),
            const SizedBox(height: 16),
            Text('ВЫХОД', style: TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 10,
              fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.5)),
            const SizedBox(height: 8),
            if (outputs.isEmpty) Text('Нет устройств', style: TextStyle(
              fontFamily: AurixTokens.fontBody, fontSize: 12, color: Colors.white.withValues(alpha: 0.3)))
            else ...outputs.map((d) => ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.headphones_rounded, size: 16, color: Color(0xFF5CA8FF)),
              title: Text(d['label'] ?? '', style: const TextStyle(
                fontFamily: AurixTokens.fontBody, fontSize: 12, color: Colors.white)),
              onTap: () { jsSetOutput(d['id'] ?? ''); Navigator.pop(ctx); },
            )),

            const SizedBox(height: 20),
            Row(children: [
              Text('КАЛИБРОВКА ЗАДЕРЖКИ ВХОДА', style: TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 10,
                fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.5)),
              const Spacer(),
              Text('$latency мс', style: const TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 12,
                fontWeight: FontWeight.w700, color: Color(0xFFFF6A1A))),
            ]),
            const SizedBox(height: 4),
            Text('Если вокал отстаёт — увеличь. Если опережает — уменьши.',
              style: TextStyle(fontFamily: AurixTokens.fontBody, fontSize: 10,
                color: Colors.white.withValues(alpha: 0.35))),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(ctx).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: const Color(0xFFFF6A1A),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                thumbColor: const Color(0xFFFF6A1A),
              ),
              child: Slider(
                min: 0, max: 400, divisions: 80,
                value: latency.toDouble(),
                onChanged: (v) {
                  setSt(() => latency = v.round());
                  jsSetInputLatency(latency);
                },
              ),
            ),

            SizedBox(height: MediaQuery.paddingOf(ctx).bottom + 8),
          ]),
        );
      }),
    );
  }

  // ─── Track header (left panel) — name, volume, M/S, pan, reorder ───
  Widget _trackHeader(_Trk t, double w, bool playing) {
    final active = t.id == _actId;
    final c = _hex(t.color);
    final tIdx = _trks.indexOf(t);
    return GestureDetector(
      onTap: () => setState(() => _actId = t.id),
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.06) : Colors.transparent,
          border: Border(
            left: BorderSide(color: active ? c : Colors.transparent, width: 3),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Name + reorder arrows + close
          Row(children: [
            GestureDetector(
              onTap: tIdx > 0 ? () => _moveTrack(t.id, -1) : null,
              child: Icon(Icons.arrow_drop_up_rounded, size: 18,
                color: tIdx > 0 ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06))),
            GestureDetector(
              onTap: tIdx < _trks.length - 1 ? () => _moveTrack(t.id, 1) : null,
              child: Icon(Icons.arrow_drop_down_rounded, size: 18,
                color: tIdx < _trks.length - 1 ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06))),
            Container(width: 8, height: 8, decoration: BoxDecoration(
              shape: BoxShape.circle, color: c)),
            const SizedBox(width: 5),
            Expanded(child: Text(t.name, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: AurixTokens.fontBody, fontSize: 11,
                fontWeight: FontWeight.w700, color: Colors.white))),
            if (!t.isBeat) GestureDetector(
              onTap: () { jsRemoveTrack(t.id); _sync(); setState(() {}); },
              child: Icon(Icons.close, size: 12, color: Colors.white.withValues(alpha: 0.12))),
          ]),
          const SizedBox(height: 4),
          // Volume slider — big
          Row(children: [
            Icon(Icons.volume_up_rounded, size: 14, color: Colors.white.withValues(alpha: 0.3)),
            Expanded(child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: c.withValues(alpha: 0.5),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
                thumbColor: c, overlayColor: Colors.transparent,
                trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
              child: Slider(value: t.volume, min: 0, max: 1.5,
                onChanged: (v) { jsSetVol(t.id, v); t.volume = v; setState(() {}); }))),
          ]),
          // M / S / Pan
          Row(children: [
            _msBtn('M', t.mute, const Color(0xFFD2A45A), () { jsMute(t.id); _sync(); setState(() {}); }),
            const SizedBox(width: 4),
            _msBtn('S', t.solo, c, () { jsSolo(t.id); _sync(); setState(() {}); }),
            const Spacer(),
            SizedBox(width: 50, child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.white.withValues(alpha: 0.15),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
                thumbColor: Colors.white.withValues(alpha: 0.4), overlayColor: Colors.transparent,
                trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3)),
              child: Slider(value: t.pan, min: -1, max: 1,
                onChanged: (v) { jsSetPan(t.id, v); t.pan = v; setState(() {}); }))),
            Text(t.pan == 0 ? 'C' : (t.pan < 0 ? 'L' : 'R'),
              style: TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 8,
                color: Colors.white.withValues(alpha: 0.2))),
          ]),
        ]),
      ),
    );
  }

  // ─── FX strip (per-track: Громкость, Ревер, Дилей) ───
  Widget _fxStrip(_Trk t) {
    final c = _hex(t.color);
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.015),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _fxRow('Громкость', t.volume / 1.5, c,
          (v) { jsSetVol(t.id, v * 1.5); t.volume = v * 1.5; setState(() {}); }),
        _fxRow('Ревер', t.reverb, const Color(0xFF5CA8FF),
          (v) => _setTrackFX(t.id, v, t.delay)),
        _fxRow('Дилей', t.delay, const Color(0xFF7B5CFF),
          (v) => _setTrackFX(t.id, t.reverb, v)),
      ]),
    );
  }

  Widget _fxRow(String label, double value, Color color, ValueChanged<double> onChanged) {
    return SizedBox(height: 28, child: Row(children: [
      SizedBox(width: 52, child: Text(label, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 9,
          fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8)))),
      Expanded(child: SliderTheme(
        data: SliderThemeData(
          activeTrackColor: color.withValues(alpha: 0.6),
          inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
          thumbColor: color, overlayColor: Colors.transparent,
          trackHeight: 5, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
        child: Slider(value: value.clamp(0.0, 1.0), min: 0, max: 1, onChanged: onChanged))),
      SizedBox(width: 24, child: Text('${(value * 100).round()}',
        textAlign: TextAlign.right,
        style: TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 10,
          fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.5)))),
    ]));
  }

  Widget _msBtn(String label, bool on, Color c, VoidCallback tap) => GestureDetector(
    onTap: tap,
    child: Container(
      constraints: const BoxConstraints(minWidth: 22, maxWidth: 28),
      height: 18, alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
        color: on ? c.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: on ? c.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08))),
      child: Text(label, style: TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 9,
        fontWeight: FontWeight.w700, color: on ? c : Colors.white.withValues(alpha: 0.2)))));

  Widget _addBtn(double w) => GestureDetector(
    onTap: _addTrack,
    child: Container(height: 44,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
      child: Center(child: Text('+ New Track', style: TextStyle(
        fontFamily: AurixTokens.fontMono, fontSize: 11, fontWeight: FontWeight.w500,
        color: Colors.white.withValues(alpha: 0.2))))));

  // ─── Track waveform (right panel) ───
  // Один гестур-хендлер: тап = выбрать, зажать-и-тащить = двигать клип.
  // На onPanStart авто-выбираем клип под пальцем, затем сразу можно тащить.
  String? _dragClipId;

  Widget _trackWave(_Trk t, double timeW, double bpm) {
    final c = _hex(t.color);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        final tap = d.localPosition.dx / _pps;
        String? hit;
        for (final cp in t.clips) {
          if (tap >= cp.startTime && tap <= cp.startTime + cp.duration) {
            hit = cp.id; break;
          }
        }
        setState(() { _actId = t.id; _selClipId = hit; });
        if (hit != null) jsSelectClip(hit);
      },
      onDoubleTapDown: (d) {
        // Двойной тап на клипе — разрезать в этой точке
        final tap = d.localPosition.dx / _pps;
        for (final cp in t.clips) {
          if (tap >= cp.startTime && tap <= cp.startTime + cp.duration) {
            jsSplitClipAt(cp.id, tap);
            _sync();
            setState(() {});
            return;
          }
        }
      },
      onDoubleTap: () {}, // нужен для активации onDoubleTapDown
      onPanStart: (d) {
        // Находим клип под точкой нажатия и сразу его подхватываем
        final tap = d.localPosition.dx / _pps;
        String? hit;
        for (final cp in t.clips) {
          if (tap >= cp.startTime && tap <= cp.startTime + cp.duration) {
            hit = cp.id; break;
          }
        }
        if (hit != null) {
          _dragClipId = hit;
          setState(() { _actId = t.id; _selClipId = hit; });
          jsSelectClip(hit);
        }
      },
      onPanUpdate: (d) {
        if (_dragClipId == null) return;
        final delta = d.delta.dx / _pps;
        for (final trk in _trks) {
          for (final cp in trk.clips) {
            if (cp.id == _dragClipId) {
              final ns = math.max(0.0, cp.startTime + delta);
              jsMoveClip(cp.id, ns);
              _sync();
              setState(() {});
              return;
            }
          }
        }
      },
      onPanEnd: (_) { _dragClipId = null; },
      onPanCancel: () { _dragClipId = null; },
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: t.id == _actId
              ? const Color(0xFF0E0E16) // slightly lighter bg for active track
              : const Color(0xFF0A0A10), // dark grid bg
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
          child: Stack(children: [
            // Базовая волна клипов
            t.clips.isEmpty
              ? (t.isBeat ? _beatPrompt(c) : const SizedBox.shrink())
              : CustomPaint(size: Size(timeW, 100),
                  painter: _Wave(clips: t.clips, color: c, pps: _pps, bpm: bpm, selectedId: _selClipId)),
            // Live-волна записи поверх (только на активном треке во время записи)
            if (jsIsRec() && t.id == _actId)
              Positioned.fill(
                child: CustomPaint(
                  painter: _LiveRecWave(samples: _recLiveSamples, peak: _recPeak, color: const Color(0xFFFF4444)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  // ─── Right tools sidebar ───
  Widget _toolsSidebar(bool hasBeat) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final w = isMobile ? 38.0 : 46.0;
    return Container(
      width: w,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A10),
        border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
      child: Column(children: [
        const Spacer(),
        // Main tools — centered/lower on screen
        _sideBtn(Icons.music_note_rounded, 'Загрузить бит', _loadBeat, const Color(0xFFFF6A1A)),
        const SizedBox(height: 2),
        _sideBtn(Icons.content_cut_rounded, 'Разрезать (S)',
          _selClipId != null ? _splitAtPlayhead : null, Colors.white),
        _sideBtn(Icons.content_copy_rounded, 'Дублировать (D)',
          _selClipId != null ? _duplicateSelected : null, Colors.white),
        _sideBtn(Icons.delete_outline_rounded, 'Удалить (Del)',
          _selClipId != null ? _deleteSelected : null, const Color(0xFFFF4444)),
        Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          color: Colors.white.withValues(alpha: 0.06)),
        _sideBtn(Icons.auto_fix_high_rounded, 'Коррекция голоса',
          _activeVocal != null ? _openCorrection : null, const Color(0xFF7B5CFF)),
        // На мобиле FX-кнопка открывает per-track FX bottom-sheet (вместо колонки)
        if (isMobile)
          _sideBtn(Icons.tune_rounded, 'Эффекты трека',
            _actId != null ? _openFxSheet : null, const Color(0xFF5CA8FF)),
        _sideBtn(Icons.edit_note_rounded, 'Текст + AI',
          () => setState(() => _showLyrics = !_showLyrics),
          _showLyrics ? const Color(0xFF7B5CFF) : Colors.white),
        _sideBtn(Icons.mic_rounded, 'Микрофон / Выход', _showDeviceSelector, Colors.white),
        Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          color: Colors.white.withValues(alpha: 0.06)),
        if (hasBeat) _sideBtn(Icons.download_rounded, 'Экспорт WAV', () {
          final url = jsExport(); debugPrint('Export: $url');
        }, const Color(0xFF4DB88C)),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _sideBtn(IconData icon, String tip, VoidCallback? tap, Color color) {
    final enabled = tap != null;
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final size = isMobile ? 30.0 : 36.0;
    final iconSize = isMobile ? 14.0 : 16.0;
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: tap,
        child: Container(
          width: size, height: size,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: enabled ? color.withValues(alpha: 0.08) : Colors.transparent,
          ),
          child: Icon(icon, size: iconSize,
            color: enabled ? color.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }

  // ── Mobile FX sheet ──
  void _openFxSheet() {
    final t = _trks.firstWhere((x) => x.id == _actId, orElse: () => _trks.first);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2))),
            Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(
                shape: BoxShape.circle, color: _hex(t.color))),
              const SizedBox(width: 8),
              Text(t.name, style: const TextStyle(fontFamily: AurixTokens.fontHeading,
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
            const SizedBox(height: 16),
            _fxStrip(t),
          ]),
        ),
      ),
    );
  }

  Widget _beatPrompt(Color c) => GestureDetector(
    onTap: _loadBeat,
    child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_rounded, size: 16, color: c.withValues(alpha: 0.4)),
        const SizedBox(width: 6),
        Text('Drop beat here', style: TextStyle(fontFamily: AurixTokens.fontMono,
          fontSize: 12, fontWeight: FontWeight.w500, color: c.withValues(alpha: 0.4))),
      ]))));

  // ─── Transport bar (single row, clean) ───
  Widget _transportBar(bool playing, bool rec, bool hasBeat, double bpm) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF08080E),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.04)))),
      child: Row(children: [
        const SizedBox(width: 10),
        GestureDetector(onTap: () => Navigator.of(context).maybePop(),
          child: Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white.withValues(alpha: 0.3))),
        const SizedBox(width: 12),
        _tBtn(Icons.skip_previous_rounded, () { jsStop(); _stopTick(); setState(() => _ph = 0); }, size: 28),
        const SizedBox(width: 5),
        _tBtn(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, hasBeat ? _play : null,
          size: 36, filled: true),
        const SizedBox(width: 5),
        _tBtn(Icons.fiber_manual_record_rounded,
          hasBeat && _actId != null ? _rec : null,
          color: rec ? const Color(0xFFFF4444) : const Color(0xFFFF4444).withValues(alpha: 0.4),
          filled: rec, size: 28),
        const SizedBox(width: 10),
        _tBtn(Icons.watch_later_outlined, _toggleMetronome,
          color: _metOn ? const Color(0xFF5CA8FF) : Colors.white,
          filled: _metOn, size: 26),
        const SizedBox(width: 5),
        _tBtn(Icons.loop_rounded, _toggleLoop,
          color: _loopOn ? const Color(0xFF5CA8FF) : Colors.white,
          filled: _loopOn, size: 26),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
            color: Colors.white.withValues(alpha: 0.04)),
          child: Text('${bpm.round()} BPM', style: TextStyle(
            fontFamily: AurixTokens.fontMono, fontSize: 10, fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.4)))),
        const Spacer(),
        Text(_fmtFull(_ph), style: const TextStyle(
          fontFamily: AurixTokens.fontMono, fontSize: 18, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: 1)),
        const Spacer(),
        Icon(Icons.remove_rounded, size: 12, color: Colors.white.withValues(alpha: 0.2)),
        SizedBox(width: 60, child: SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.white.withValues(alpha: 0.15),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.05),
            thumbColor: Colors.white.withValues(alpha: 0.3), overlayColor: Colors.transparent,
            trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3)),
          child: Slider(value: _zoom, min: 0.3, max: 5, onChanged: (v) => setState(() => _zoom = v)))),
        Icon(Icons.add_rounded, size: 12, color: Colors.white.withValues(alpha: 0.2)),
        const SizedBox(width: 10),
      ]),
    );
  }

  Widget _tBtn(IconData icon, VoidCallback? tap, {Color? color, bool filled = false, double size = 32}) {
    final c = color ?? Colors.white;
    return GestureDetector(onTap: tap, child: Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: filled ? c.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(color: c.withValues(alpha: tap != null ? 0.3 : 0.1), width: 1.5)),
      child: Icon(icon, size: size * 0.5, color: c.withValues(alpha: tap != null ? 0.8 : 0.2))));
  }

  String _fmtFull(double s) {
    if (s.isNaN || s.isInfinite) return '00:00.000';
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s.toInt() % 60).toString().padLeft(2, '0');
    final ms = ((s % 1) * 1000).toInt().toString().padLeft(3, '0');
    return '$m:$sec.$ms';
  }

  Color _hex(String h) => Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));
}

// ═══════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════

class _Ruler extends CustomPainter {
  final double pps, ph, dur, bpm;
  final bool loopOn;
  final double loopStart, loopEnd;
  _Ruler({
    required this.pps, required this.ph, required this.dur, required this.bpm,
    required this.loopOn, required this.loopStart, required this.loopEnd,
  });

  @override void paint(Canvas canvas, Size size) {
    final spb = 60 / bpm;
    final spBar = spb * 4;
    final barP = Paint()..color = Colors.white.withValues(alpha: 0.12)..strokeWidth = 1;
    final beatP = Paint()..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 0.5;

    for (int bar = 0; bar * spBar <= dur + spBar; bar++) {
      final x = bar * spBar * pps;
      if (x > size.width + 20) break;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), barP);
      TextPainter(text: TextSpan(text: '${bar + 1}', style: TextStyle(
        fontFamily: AurixTokens.fontMono, fontSize: 10, fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.25))), textDirection: TextDirection.ltr)
        ..layout()..paint(canvas, Offset(x + 4, 6));
      for (int b = 1; b < 4; b++) {
        canvas.drawLine(Offset(x + b * spb * pps, size.height - 8), Offset(x + b * spb * pps, size.height), beatP);
      }
    }

    // Loop brace
    if (loopOn) {
      final lx0 = loopStart * pps;
      final lx1 = loopEnd * pps;
      const loopColor = Color(0xFF5CA8FF);
      canvas.drawRect(Rect.fromLTRB(lx0, 0, lx1, size.height),
        Paint()..color = loopColor.withValues(alpha: 0.18));
      canvas.drawRect(Rect.fromLTRB(lx0, 0, lx1, 4),
        Paint()..color = loopColor);
      canvas.drawLine(Offset(lx0, 0), Offset(lx0, size.height),
        Paint()..color = loopColor..strokeWidth = 1.5);
      canvas.drawLine(Offset(lx1, 0), Offset(lx1, size.height),
        Paint()..color = loopColor..strokeWidth = 1.5);
    }

    // Playhead
    final px = ph * pps;
    canvas.drawLine(Offset(px, 0), Offset(px, size.height), Paint()..color = const Color(0xFFFF6A1A)..strokeWidth = 2);
    canvas.drawPath(Path()..moveTo(px - 5, 0)..lineTo(px + 5, 0)..lineTo(px, 7)..close(),
      Paint()..color = const Color(0xFFFF6A1A));
    // Bottom line
    canvas.drawLine(Offset(0, size.height - 0.5), Offset(size.width, size.height - 0.5),
      Paint()..color = Colors.white.withValues(alpha: 0.06));
  }

  @override bool shouldRepaint(_Ruler o) =>
      o.ph != ph || o.pps != pps || o.bpm != bpm ||
      o.loopOn != loopOn || o.loopStart != loopStart || o.loopEnd != loopEnd;
}

class _Wave extends CustomPainter {
  final List<_Clip> clips;
  final Color color;
  final double pps, bpm;
  final String? selectedId;
  _Wave({required this.clips, required this.color, required this.pps,
         required this.bpm, this.selectedId});

  @override void paint(Canvas canvas, Size size) {
    final spb = 60 / bpm;
    final spBar = spb * 4;

    // Draw beat grid lines across the full timeline (Cubase-style)
    for (int bar = 0; bar * spBar <= size.width / pps + spBar; bar++) {
      final bx = bar * spBar * pps;
      if (bx > size.width + 10) break;
      // Bar line (stronger)
      canvas.drawLine(Offset(bx, 0), Offset(bx, size.height),
        Paint()..color = Colors.white.withValues(alpha: 0.06)..strokeWidth = 1);
      // Beat subdivisions (fainter)
      for (int b = 1; b < 4; b++) {
        final sx = bx + b * spb * pps;
        canvas.drawLine(Offset(sx, 0), Offset(sx, size.height),
          Paint()..color = Colors.white.withValues(alpha: 0.025)..strokeWidth = 0.5);
      }
    }

    // Center line
    final mid = size.height / 2;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid),
      Paint()..color = Colors.white.withValues(alpha: 0.03));

    for (final c in clips) {
      if (c.peaks.isEmpty) continue;
      final x0 = c.startTime * pps;
      final w = c.duration * pps;
      final n = c.peaks.length;
      final step = w / n;
      final isSel = c.id == selectedId;

      // Clip background — lighter than track bg (Cubase style)
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x0, 2, w, size.height - 4), const Radius.circular(3)),
        Paint()..color = color.withValues(alpha: isSel ? 0.14 : 0.06));
      // Clip header bar (thin color strip at top)
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x0, 2, w, 3),
          topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        Paint()..color = color.withValues(alpha: isSel ? 0.8 : 0.4));

      // Selection border
      if (isSel) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x0, 2, w, size.height - 4), const Radius.circular(3)),
          Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5
            ..color = Colors.white.withValues(alpha: 0.7));
      }

      // Filled waveform — darker tones (Cubase style)
      final top = Path()..moveTo(x0, mid);
      final bot = Path()..moveTo(x0, mid);
      for (int i = 0; i < n; i++) {
        final x = x0 + i * step;
        final a = c.peaks[i] * size.height * 0.38;
        top.lineTo(x, mid - a);
        bot.lineTo(x, mid + a);
      }
      top.lineTo(x0 + w, mid); top.close();
      bot.lineTo(x0 + w, mid); bot.close();

      canvas.drawPath(top, Paint()..color = color.withValues(alpha: 0.3));
      canvas.drawPath(bot, Paint()..color = color.withValues(alpha: 0.2));

      // Waveform outline (crisp)
      final outline = Path()..moveTo(x0, mid);
      for (int i = 0; i < n; i++) {
        outline.lineTo(x0 + i * step, mid - c.peaks[i] * size.height * 0.38);
      }
      for (int i = n - 1; i >= 0; i--) {
        outline.lineTo(x0 + i * step, mid + c.peaks[i] * size.height * 0.38);
      }
      outline.close();
      canvas.drawPath(outline, Paint()..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke..strokeWidth = 0.7);

      // Clip name
      TextPainter(text: TextSpan(text: c.id.split('_').first.toUpperCase(),
        style: TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 8,
          color: color.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr)
        ..layout()..paint(canvas, Offset(x0 + 5, 7));
    }
  }

  @override bool shouldRepaint(_Wave o) =>
      o.selectedId != selectedId || o.pps != pps || o.bpm != bpm;
}

// ═══════════════════════════════════════════════════════
// LIVE REC WAVE — оверлей с накопленной огибающей записи
// ═══════════════════════════════════════════════════════

class _LiveRecWave extends CustomPainter {
  final List<double> samples;
  final double peak;
  final Color color;
  _LiveRecWave({required this.samples, required this.peak, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final mid = size.height / 2;
    final step = size.width / samples.length;

    // Заполняем фоном с лёгкой подсветкой
    final bgPaint = Paint()..color = color.withValues(alpha: 0.04);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Огибающая
    final fillPath = Path()..moveTo(0, mid);
    for (var i = 0; i < samples.length; i++) {
      final amp = samples[i].clamp(0.0, 1.0) * size.height * 0.42;
      fillPath.lineTo(i * step, mid - amp);
    }
    for (var i = samples.length - 1; i >= 0; i--) {
      final amp = samples[i].clamp(0.0, 1.0) * size.height * 0.42;
      fillPath.lineTo(i * step, mid + amp);
    }
    fillPath.close();
    canvas.drawPath(fillPath,
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.25), color.withValues(alpha: 0.55)],
      ).createShader(Offset.zero & size));

    // Текущий пик-индикатор справа (вертикальная полоска)
    final p = peak.clamp(0.0, 1.0);
    final h = size.height * 0.78 * p;
    final barRect = Rect.fromLTWH(size.width - 4, mid - h / 2, 3, h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
      Paint()..color = p > 0.95 ? const Color(0xFFFF0040) : color);

    // Центральная пунктирная линия
    final dashPaint = Paint()..color = color.withValues(alpha: 0.25)..strokeWidth = 0.7;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, mid), Offset(x + 3, mid), dashPaint);
    }
  }

  @override
  bool shouldRepaint(_LiveRecWave o) =>
    o.samples.length != samples.length || (o.peak - peak).abs() > 0.005;
}

// ═══════════════════════════════════════════════════════
// CORRECTION SHEET — unified voice processing
// ═══════════════════════════════════════════════════════

class _CorrectionSheet extends StatefulWidget {
  final String trackName;
  final String style;
  final bool auto;
  final String scaleKey;
  final double strength;
  final String preset;
  final bool busy;
  final String stage;
  final void Function(String style, bool auto, String key, double strength, String preset) onChange;
  final Future<void> Function() onApply;

  const _CorrectionSheet({
    required this.trackName,
    required this.style,
    required this.auto,
    required this.scaleKey,
    required this.strength,
    required this.preset,
    required this.busy,
    required this.stage,
    required this.onChange,
    required this.onApply,
  });

  @override State<_CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<_CorrectionSheet> {
  late String _style = widget.style;
  late bool _auto = widget.auto;
  late String _key = widget.scaleKey;
  late double _strength = widget.strength;
  late String _preset = widget.preset;

  static const _accent = Color(0xFF7B5CFF);

  // Voice styles (match Python voice_style.py)
  static const _styles = <Map<String, String>>[
    {'id': 'wide_star', 'title': 'Wide Star',  'desc': 'Широкий поп-вокал с блеском'},
    {'id': 'pop',       'title': 'Pop',        'desc': 'Чистый поп, лёгкая ревер'},
    {'id': 'trap',      'title': 'Trap',       'desc': 'Трап вокал, насыщение'},
    {'id': 'rnb',       'title': 'R&B',        'desc': 'Тёплый и плотный'},
    {'id': 'drill',     'title': 'Drill',      'desc': 'Агрессивный, близкий'},
    {'id': 'phonk',     'title': 'Phonk',      'desc': 'Лоу-фай, сатурация'},
    {'id': 'dark',      'title': 'Dark',       'desc': 'Тёмный атмосферный'},
    {'id': 'lofi',      'title': 'Lo-Fi',      'desc': 'Ламповый, мягкий'},
    {'id': 'none',      'title': 'Clean',      'desc': 'Без стилизации'},
  ];

  // Autotune keys — all 24 major/minor
  static const _keys = <Map<String, String>>[
    {'id': 'C_major',  'label': 'C maj'},
    {'id': 'C_minor',  'label': 'C min'},
    {'id': 'Db_major', 'label': 'Db maj'},
    {'id': 'Cs_minor', 'label': 'C# min'},
    {'id': 'D_major',  'label': 'D maj'},
    {'id': 'D_minor',  'label': 'D min'},
    {'id': 'Eb_major', 'label': 'Eb maj'},
    {'id': 'Eb_minor', 'label': 'Eb min'},
    {'id': 'E_major',  'label': 'E maj'},
    {'id': 'E_minor',  'label': 'E min'},
    {'id': 'F_major',  'label': 'F maj'},
    {'id': 'F_minor',  'label': 'F min'},
    {'id': 'Fs_major', 'label': 'F# maj'},
    {'id': 'Fs_minor', 'label': 'F# min'},
    {'id': 'G_major',  'label': 'G maj'},
    {'id': 'G_minor',  'label': 'G min'},
    {'id': 'Ab_major', 'label': 'Ab maj'},
    {'id': 'Ab_minor', 'label': 'Ab min'},
    {'id': 'A_major',  'label': 'A maj'},
    {'id': 'A_minor',  'label': 'A min'},
    {'id': 'Bb_major', 'label': 'Bb maj'},
    {'id': 'Bb_minor', 'label': 'Bb min'},
    {'id': 'B_major',  'label': 'B maj'},
    {'id': 'B_minor',  'label': 'B min'},
  ];

  // Processing intensity presets
  static const _presets = <Map<String, String>>[
    {'id': 'soft', 'label': 'Мягко',  'desc': 'Лёгкая обработка'},
    {'id': 'hit',  'label': 'Hit',    'desc': 'Готово к релизу'},
    {'id': 'loud', 'label': 'Громко', 'desc': 'Максимум громкости'},
  ];

  void _push() => widget.onChange(_style, _auto, _key, _strength, _preset);

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Container(
      constraints: BoxConstraints(maxHeight: h * 0.88),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: Color(0xFF7B5CFF), width: 2),
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2)),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _accent.withValues(alpha: 0.15),
                border: Border.all(color: _accent.withValues(alpha: 0.3))),
              child: const Icon(Icons.auto_fix_high_rounded, size: 18, color: _accent),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Коррекция голоса', style: TextStyle(
                  fontFamily: AurixTokens.fontHeading, fontSize: 17,
                  fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(widget.trackName, style: TextStyle(
                  fontFamily: AurixTokens.fontMono, fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.35))),
              ])),
            IconButton(
              onPressed: widget.busy ? null : () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.close_rounded, size: 20,
                color: Colors.white.withValues(alpha: 0.4))),
          ]),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),

        // Scrollable sections
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Voice Style ──
              _section('Стиль голоса', Icons.graphic_eq_rounded),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in _styles)
                  _styleChip(s['id']!, s['title']!, s['desc']!),
              ]),
              const SizedBox(height: 24),

              // ── Autotune ──
              _section('AutoTune', Icons.tune_rounded),
              const SizedBox(height: 10),
              _autoToggle(),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _auto ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: Column(children: [
                  const SizedBox(height: 12),
                  _keyPicker(),
                  const SizedBox(height: 14),
                  _strengthSlider(),
                ]),
                secondChild: const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 24),

              // ── Processing preset ──
              _section('Обработка', Icons.auto_graph_rounded),
              const SizedBox(height: 10),
              Row(children: [
                for (final p in _presets) ...[
                  Expanded(child: _presetBtn(p['id']!, p['label']!, p['desc']!)),
                  if (p != _presets.last) const SizedBox(width: 8),
                ],
              ]),
              const SizedBox(height: 20),

              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 14,
                    color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Коррекция применится к последней записи на выбранном треке. Занимает 5–15 сек.',
                    style: TextStyle(
                      fontFamily: AurixTokens.fontBody, fontSize: 11,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.4)))),
                ]),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),

        // ── Apply button ──
        Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.paddingOf(context).bottom),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0E),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: widget.busy ? null : () => widget.onApply(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: _accent.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: widget.busy
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
                    const SizedBox(width: 12),
                    Text(widget.stage.isEmpty ? 'Обработка...' : widget.stage,
                      style: const TextStyle(
                        fontFamily: AurixTokens.fontMono, fontSize: 12,
                        fontWeight: FontWeight.w600)),
                  ])
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_fix_high_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Применить коррекцию', style: TextStyle(
                      fontFamily: AurixTokens.fontHeading, fontSize: 14,
                      fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _section(String title, IconData icon) => Row(children: [
    Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.4)),
    const SizedBox(width: 8),
    Text(title.toUpperCase(), style: TextStyle(
      fontFamily: AurixTokens.fontMono, fontSize: 10,
      fontWeight: FontWeight.w700, letterSpacing: 1.5,
      color: Colors.white.withValues(alpha: 0.5))),
  ]);

  Widget _styleChip(String id, String title, String desc) {
    final on = _style == id;
    return GestureDetector(
      onTap: widget.busy ? null : () { setState(() => _style = id); _push(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: on ? _accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: on ? _accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
            width: on ? 1.5 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: TextStyle(
            fontFamily: AurixTokens.fontHeading, fontSize: 12, fontWeight: FontWeight.w700,
            color: on ? Colors.white : Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 2),
          Text(desc, style: TextStyle(
            fontFamily: AurixTokens.fontBody, fontSize: 9,
            color: Colors.white.withValues(alpha: on ? 0.5 : 0.3))),
        ]),
      ),
    );
  }

  Widget _autoToggle() => GestureDetector(
    onTap: widget.busy ? null : () { setState(() => _auto = !_auto); _push(); },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: _auto ? _accent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
        border: Border.all(
          color: _auto ? _accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08))),
      child: Row(children: [
        Icon(_auto ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 18, color: _auto ? _accent : Colors.white.withValues(alpha: 0.2)),
        const SizedBox(width: 10),
        const Expanded(child: Text('AutoTune', style: TextStyle(
          fontFamily: AurixTokens.fontHeading, fontSize: 13,
          fontWeight: FontWeight.w700, color: Colors.white))),
        Text(_auto ? 'ВКЛ' : 'ВЫКЛ', style: TextStyle(
          fontFamily: AurixTokens.fontMono, fontSize: 10, fontWeight: FontWeight.w700,
          color: _auto ? _accent : Colors.white.withValues(alpha: 0.3))),
      ]),
    ),
  );

  Widget _keyPicker() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('ТОНАЛЬНОСТЬ', style: TextStyle(
      fontFamily: AurixTokens.fontMono, fontSize: 9, letterSpacing: 1,
      color: Colors.white.withValues(alpha: 0.35))),
    const SizedBox(height: 6),
    Wrap(spacing: 6, runSpacing: 6, children: [
      for (final k in _keys) GestureDetector(
        onTap: widget.busy ? null : () { setState(() => _key = k['id']!); _push(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: _key == k['id'] ? _accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: _key == k['id'] ? _accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08))),
          child: Text(k['label']!, style: TextStyle(
            fontFamily: AurixTokens.fontMono, fontSize: 10, fontWeight: FontWeight.w600,
            color: _key == k['id'] ? Colors.white : Colors.white.withValues(alpha: 0.5))),
        ),
      ),
    ]),
  ]);

  Widget _strengthSlider() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text('СИЛА', style: TextStyle(
        fontFamily: AurixTokens.fontMono, fontSize: 9, letterSpacing: 1,
        color: Colors.white.withValues(alpha: 0.35))),
      const Spacer(),
      Text('${(_strength * 100).round()}%', style: const TextStyle(
        fontFamily: AurixTokens.fontMono, fontSize: 11, fontWeight: FontWeight.w700,
        color: _accent)),
    ]),
    SliderTheme(
      data: SliderThemeData(
        activeTrackColor: _accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
        thumbColor: _accent,
        overlayColor: _accent.withValues(alpha: 0.15),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
      child: Slider(
        value: _strength, min: 0, max: 1,
        onChanged: widget.busy ? null : (v) { setState(() => _strength = v); _push(); }),
    ),
  ]);

  Widget _presetBtn(String id, String label, String desc) {
    final on = _preset == id;
    return GestureDetector(
      onTap: widget.busy ? null : () { setState(() => _preset = id); _push(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: on ? _accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: on ? _accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
            width: on ? 1.5 : 1)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
            fontFamily: AurixTokens.fontHeading, fontSize: 13, fontWeight: FontWeight.w700,
            color: on ? Colors.white : Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 2),
          Text(desc, style: TextStyle(
            fontFamily: AurixTokens.fontBody, fontSize: 9,
            color: Colors.white.withValues(alpha: on ? 0.5 : 0.3))),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// REC HUD — компактный пик-метр в углу
// ═══════════════════════════════════════════════════════

class _RecHud extends StatelessWidget {
  final double rms, peak;
  const _RecHud({required this.rms, required this.peak});

  @override
  Widget build(BuildContext context) {
    final clip = peak > 0.95;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D12).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: clip ? const Color(0xFFFF0040) : Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        // Пульсирующий REC dot
        Container(width: 8, height: 8, decoration: BoxDecoration(
          shape: BoxShape.circle, color: clip ? const Color(0xFFFF0040) : const Color(0xFFFF4444),
          boxShadow: [BoxShadow(color: const Color(0xFFFF4444).withValues(alpha: 0.6), blurRadius: 10)])),
        const SizedBox(width: 8),
        const Text('REC', style: TextStyle(fontFamily: AurixTokens.fontMono, fontSize: 10,
          fontWeight: FontWeight.w700, color: Color(0xFFFF4444), letterSpacing: 1.2)),
        const SizedBox(width: 12),
        // Двойной столбик: RMS (тонкий) + Peak (толстый)
        SizedBox(width: 110, height: 16, child: CustomPaint(painter: _MeterBars(rms: rms, peak: peak))),
        const SizedBox(width: 8),
        // dB вычислим грубо: 20*log10(peak)
        Text(_db(peak), style: TextStyle(
          fontFamily: AurixTokens.fontMono, fontSize: 10,
          color: clip ? const Color(0xFFFF0040) : Colors.white.withValues(alpha: 0.7),
          fontFeatures: AurixTokens.tabularFigures)),
      ]),
    );
  }

  String _db(double v) {
    if (v <= 0.001) return '−∞';
    final db = 20 * (math.log(v) / math.ln10);
    return '${db.toStringAsFixed(1)} dB';
  }
}

class _MeterBars extends CustomPainter {
  final double rms, peak;
  _MeterBars({required this.rms, required this.peak});

  @override
  void paint(Canvas canvas, Size size) {
    // Шкала с цветовыми зонами
    final mid = size.height / 2;
    // Background
    canvas.drawRRect(RRect.fromRectAndRadius(
      Offset.zero & size, const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: 0.06));

    // Зоны: 0-60% зелёный, 60-85% жёлтый, 85-100% красный
    void drawZone(double from, double to, Color c) {
      final r = Rect.fromLTWH(from * size.width, 0,
          (to - from) * size.width, size.height);
      canvas.drawRect(r, Paint()..color = c.withValues(alpha: 0.08));
    }
    drawZone(0, 0.6, const Color(0xFF4DB88C));
    drawZone(0.6, 0.85, const Color(0xFFE5B040));
    drawZone(0.85, 1.0, const Color(0xFFFF4444));

    // RMS bar (тонкий, зелёный)
    final rmsW = rms.clamp(0.0, 1.0) * size.width;
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, mid - 2, rmsW, 4), const Radius.circular(2)),
      Paint()..color = _colorFor(rms));

    // Peak bar (точечный)
    final peakX = peak.clamp(0.0, 1.0) * size.width;
    canvas.drawRect(Rect.fromLTWH(peakX - 1.5, 1, 2, size.height - 2),
      Paint()..color = _colorFor(peak));
  }

  Color _colorFor(double v) {
    if (v > 0.85) return const Color(0xFFFF4444);
    if (v > 0.6) return const Color(0xFFE5B040);
    return const Color(0xFF4DB88C);
  }

  @override
  bool shouldRepaint(_MeterBars o) =>
    (o.rms - rms).abs() > 0.005 || (o.peak - peak).abs() > 0.005;
}

// ═══════════════════════════════════════════════════════
// STUDIO HELP OVERLAY — gestures, shortcuts, FX explanation
// ═══════════════════════════════════════════════════════

class _StudioHelpOverlay extends StatelessWidget {
  final VoidCallback onClose;
  const _StudioHelpOverlay({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // блокирует прокидывание тапа
              child: Container(
                width: math.min(MediaQuery.sizeOf(context).width - 40, 720),
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF7B5CFF).withValues(alpha: 0.4), width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 10))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                    child: Row(children: [
                      const Icon(Icons.help_outline_rounded, size: 22, color: Color(0xFF7B5CFF)),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Помощь по студии',
                        style: TextStyle(fontFamily: AurixTokens.fontHeading,
                          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                      IconButton(
                        onPressed: onClose,
                        icon: Icon(Icons.close_rounded, size: 20, color: Colors.white.withValues(alpha: 0.4))),
                    ]),
                  ),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                  Flexible(child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                      _HelpSection(
                        icon: Icons.touch_app_rounded,
                        title: 'ЖЕСТЫ НА КЛИПАХ',
                        items: [
                          _HelpItem('Тап',                  'Выбрать клип'),
                          _HelpItem('Зажать и тащить',      'Двигать клип по таймлайну'),
                          _HelpItem('Двойной тап на клипе', 'Разрезать клип ровно в этой точке'),
                        ],
                      ),
                      _HelpSection(
                        icon: Icons.keyboard_rounded,
                        title: 'ГОРЯЧИЕ КЛАВИШИ',
                        items: [
                          _HelpItem('Space',          'Play / Pause'),
                          _HelpItem('R',              'Запись на активный трек'),
                          _HelpItem('S',              'Разрезать выделенный клип на playhead'),
                          _HelpItem('D',              'Дублировать выделенный клип'),
                          _HelpItem('Delete / ⌫',    'Удалить выделенный клип'),
                          _HelpItem('M',              'Метроном on/off'),
                          _HelpItem('L',              'Loop on/off'),
                          _HelpItem('= / −',         'Зум таймлайна'),
                        ],
                      ),
                      _HelpSection(
                        icon: Icons.tune_rounded,
                        title: 'ЭФФЕКТЫ ТРЕКА',
                        items: [
                          _HelpItem('Volume',    'Громкость дорожки 0–150%'),
                          _HelpItem('Reverb',    'Пространство и хвост: 0% сухо, 100% — концертный зал'),
                          _HelpItem('Delay',     'Эхо с обратной связью (~280мс)'),
                          _HelpItem('M / S',     'Mute / Solo'),
                        ],
                      ),
                      _HelpSection(
                        icon: Icons.auto_fix_high_rounded,
                        title: 'КОРРЕКЦИЯ ГОЛОСА',
                        items: [
                          _HelpItem('Стиль',     'Wide Star/Pop/Trap/R&B/Drill/Phonk/Dark/Lo-Fi/Clean'),
                          _HelpItem('AutoTune',  'Включи и выбери тональность — ноты лягут в гамму'),
                          _HelpItem('Strength',  '0% — лёгкая правка, 100% — чистая «трапная» обработка'),
                          _HelpItem('Preset',    'Soft = деликатно, Hit = release-ready, Loud = максимум'),
                          _HelpItem('Действие',  'Применяется к ОРИГИНАЛЬНОЙ записи (не накапливается)'),
                        ],
                      ),
                      _HelpSection(
                        icon: Icons.mic_rounded,
                        title: 'ЗАПИСЬ',
                        items: [
                          _HelpItem('Микрофон',    'Записывается строго моно (центр), бит — стерео'),
                          _HelpItem('Live-волна',  'Красная волна = твой голос в реальном времени'),
                          _HelpItem('REC HUD',     'Пик-метр в углу. Не уводи в красную зону >85%'),
                          _HelpItem('Калибровка',  'Меню микрофона — слайдер задержки если вокал «отстаёт»'),
                        ],
                      ),
                    ]),
                  )),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_HelpItem> items;
  const _HelpSection({required this.icon, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: const Color(0xFF7B5CFF)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontFamily: AurixTokens.fontMono,
            fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7B5CFF), letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 10),
        for (final it in items) Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
              child: Text(it.label, style: const TextStyle(
                fontFamily: AurixTokens.fontMono, fontSize: 10,
                fontWeight: FontWeight.w700, color: Colors.white))),
            const SizedBox(width: 12),
            Expanded(child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(it.desc, style: TextStyle(
                fontFamily: AurixTokens.fontBody, fontSize: 12, height: 1.4,
                color: Colors.white.withValues(alpha: 0.65))))),
          ]),
        ),
      ]),
    );
  }
}

class _HelpItem {
  final String label, desc;
  const _HelpItem(this.label, this.desc);
}

// ═══════════════════════════════════════════════════════
// PROCESSING OVERLAY — full-screen loading for AI correction
// ═══════════════════════════════════════════════════════

class _ProcessingOverlay extends StatefulWidget {
  final String title;
  final String detail;
  final String preset;
  final String style;
  final bool autotune;
  const _ProcessingOverlay({required this.title, required this.detail,
    required this.preset, required this.style, required this.autotune});

  @override
  State<_ProcessingOverlay> createState() => _ProcessingOverlayState();
}

class _ProcessingOverlayState extends State<_ProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
    AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(child: Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7B5CFF).withValues(alpha: 0.4), width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 10))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Animated waveform
            SizedBox(
              width: 120, height: 56,
              child: AnimatedBuilder(
                animation: _ctl,
                builder: (_, __) => CustomPaint(painter: _ProcessingWavePainter(_ctl.value)),
              ),
            ),
            const SizedBox(height: 18),
            Text(widget.title, style: const TextStyle(
              fontFamily: AurixTokens.fontHeading, fontSize: 18,
              fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            Text(widget.detail.isEmpty ? 'Применение...' : widget.detail,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AurixTokens.fontBody, fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6), height: 1.5)),
            const SizedBox(height: 18),
            // Settings recap
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _row('Стиль',     widget.style),
                _row('Preset',    widget.preset),
                _row('AutoTune',  widget.autotune ? 'ON' : 'OFF',
                  hl: widget.autotune ? const Color(0xFF7B5CFF) : null),
              ]),
            ),
          ]),
        ),
      ),
    ));
  }

  Widget _row(String l, String v, {Color? hl}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 80, child: Text(l, style: TextStyle(
        fontFamily: AurixTokens.fontMono, fontSize: 10,
        color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.2))),
      Text(v, style: TextStyle(
        fontFamily: AurixTokens.fontMono, fontSize: 11, fontWeight: FontWeight.w700,
        color: hl ?? Colors.white)),
    ]),
  );
}

class _ProcessingWavePainter extends CustomPainter {
  final double t;
  _ProcessingWavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    const bars = 16;
    final barW = size.width / bars * 0.6;
    final gap = size.width / bars;

    for (var i = 0; i < bars; i++) {
      final phase = (t * 2 * math.pi) + i * 0.42;
      final amp = (math.sin(phase) * 0.5 + 0.5) * size.height * 0.4 + 4;
      final c = i / bars;
      final color = Color.lerp(const Color(0xFFFF6A1A), const Color(0xFF7B5CFF), c)!;
      final r = Rect.fromCenter(center: Offset(i * gap + gap / 2, mid),
        width: barW, height: amp);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)),
        Paint()..color = color.withValues(alpha: 0.85));
    }
  }

  @override bool shouldRepaint(_ProcessingWavePainter o) => o.t != t;
}
