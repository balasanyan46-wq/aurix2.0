import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../domain/track_model.dart';

// ─── Minimal JS interop ───

@JS('AudioContext')
extension type _Ctx._(JSObject _) implements JSObject {
  external factory _Ctx();
  external JSObject get destination;
  external JSString get state;
  external JSNumber get sampleRate;
  external JSNumber get currentTime;
  external JSPromise resume();
  external JSPromise close();
  external JSObject createGain();
  external JSObject createBufferSource();
  external JSObject createBuffer(int ch, int len, num sr);
  external JSPromise decodeAudioData(JSArrayBuffer data);
  external JSObject createMediaStreamSource(web.MediaStream s);
}

@JS('MediaRecorder')
extension type _Rec._(JSObject _) implements web.EventTarget {
  external factory _Rec(web.MediaStream s, [JSObject? opts]);
  external void start([int? ms]);
  external void stop();
  @JS('isTypeSupported')
  external static bool isSupported(String t);
}

// ─── Engine ───

class MultitrackEngine {
  _Ctx? _ctx;
  JSObject? _masterGain;
  final ProjectTiming timing = ProjectTiming();
  final LoopRegion loop = LoopRegion();

  final List<StudioTrack> _tracks = [];
  final Map<String, JSObject> _gainNodes = {};
  final List<JSObject> _sources = [];

  // Recording
  web.MediaStream? _mic;
  _Rec? _recorder;
  final List<web.Blob> _chunks = [];
  double _recStart = 0;

  // Playback
  bool _playing = false;
  bool _recording = false;
  bool _countingIn = false;
  double _ctxStartTime = 0;
  double _offset = 0;
  String? _activeTrackId;
  String? selectedInputDeviceId;
  bool metronomeEnabled = false;
  Timer? _metTimer;
  Timer? _loopTimer;

  static const int maxTracks = 5;

  List<StudioTrack> get tracks => List.unmodifiable(_tracks);
  bool get isPlaying => _playing;
  bool get isRecording => _recording;
  bool get isCountingIn => _countingIn;
  String? get activeTrackId => _activeTrackId;

  double get totalDuration {
    double d = 0;
    for (final t in _tracks) { if (t.duration > d) d = t.duration; }
    return math.max(d, timing.secondsPerBar);
  }

  double get playhead {
    if (!_playing) return _offset;
    return _ctx!.currentTime.toDartDouble - _ctxStartTime + _offset;
  }

  double snap(double s) => timing.snapToGrid(s);

  // ─── Init ───

  Future<void> init() async {
    _ctx = _Ctx();
    _masterGain = _ctx!.createGain();
    _setParam(_masterGain!, 'gain', 1.0);
    _connect(_masterGain!, _ctx!.destination);
    debugPrint('[Engine] AudioContext created, sr=${_ctx!.sampleRate.toDartDouble}');
  }

  // ─── JS helpers ───

  void _setParam(JSObject node, String name, num val) {
    final p = node.getProperty(name.toJS) as JSObject;
    p['value'] = val.toJS;
  }

  double _getParam(JSObject node, String name) {
    final p = node.getProperty(name.toJS) as JSObject;
    return (p['value'] as JSNumber).toDartDouble;
  }

  void _connect(JSObject from, JSObject to) {
    from.callMethod('connect'.toJS, to);
  }

  void _disconnect(JSObject node) {
    try { node.callMethod('disconnect'.toJS); } catch (_) {}
  }

  Future<void> _ensureRunning() async {
    if (_ctx!.state.toDart == 'suspended') {
      await _ctx!.resume().toDart;
      debugPrint('[Engine] AudioContext resumed');
    }
  }

  // ─── Track management ───

  StudioTrack addBeatTrack() {
    final t = StudioTrack(id: 'beat', name: 'Beat', isBeat: true, volume: 0.8);
    _tracks.insert(0, t);
    _makeGain(t);
    return t;
  }

  StudioTrack? addVocalTrack([String? name]) {
    if (_tracks.length >= maxTracks) return null;
    final idx = _tracks.where((t) => !t.isBeat).length + 1;
    final t = StudioTrack(
      id: 'vocal_${idx}_${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? 'Vocal $idx',
    );
    _tracks.add(t);
    _makeGain(t);
    return t;
  }

  void removeTrack(String id) {
    _tracks.removeWhere((t) => t.id == id && !t.isBeat);
    final g = _gainNodes.remove(id);
    if (g != null) _disconnect(g);
  }

  void _makeGain(StudioTrack t) {
    final g = _ctx!.createGain();
    _setParam(g, 'gain', t.volume);
    _connect(g, _masterGain!);
    _gainNodes[t.id] = g;
  }

  void setActiveTrack(String id) => _activeTrackId = id;

  void setTrackVolume(String id, double v) {
    final t = _tracks.firstWhere((t) => t.id == id);
    t.volume = v.clamp(0.0, 1.5);
    _applyGains();
  }

  void toggleMute(String id) {
    final t = _tracks.firstWhere((t) => t.id == id);
    t.isMuted = !t.isMuted; _applyGains();
  }

  void toggleSolo(String id) {
    final t = _tracks.firstWhere((t) => t.id == id);
    t.isSolo = !t.isSolo; _applyGains();
  }

  void _applyGains() {
    final solo = _tracks.any((t) => t.isSolo);
    for (final t in _tracks) {
      final g = _gainNodes[t.id]; if (g == null) continue;
      double v = t.volume;
      if (t.isMuted) v = 0;
      if (solo && !t.isSolo) v = 0;
      _setParam(g, 'gain', v);
    }
  }

  // ─── Load beat ───

  Future<void> loadBeatFromFile(web.File file) async {
    await _ensureRunning();
    final ab = (await file.arrayBuffer().toDart) as JSArrayBuffer;
    await _decodeBeat(ab);
  }

  Future<void> loadBeatFromBytes(Uint8List bytes) async {
    await _ensureRunning();
    debugPrint('[Engine] loadBeatFromBytes: ${bytes.length} bytes');

    // Uint8List → JSArrayBuffer: use toJS then get .buffer property
    final jsArr = bytes.toJS; // JSUint8Array
    final jsAB = jsArr.getProperty('buffer'.toJS) as JSArrayBuffer;

    debugPrint('[Engine] ArrayBuffer ready: ${jsAB.toDart.lengthInBytes} bytes');
    await _decodeBeat(jsAB);
  }

  Future<void> _decodeBeat(JSArrayBuffer ab) async {
    final beat = _tracks.firstWhere((t) => t.isBeat);
    final buf = (await _ctx!.decodeAudioData(ab).toDart)! as JSObject;
    final dur = (buf.getProperty('duration'.toJS) as JSNumber).toDartDouble;
    final ch = (buf.getProperty('numberOfChannels'.toJS) as JSNumber).toDartInt;
    debugPrint('[Engine] Beat decoded: ${dur.toStringAsFixed(1)}s, ${ch}ch');

    beat.clips.clear();
    beat.addClip(buf, 0, waveform: _waveform(buf, 300));

    // Auto BPM
    final bpm = _detectBpm(buf);
    if (bpm > 0) { timing.bpm = bpm; debugPrint('[Engine] BPM: $bpm'); }
  }

  Float32List _waveform(JSObject buf, int n) {
    final d = (buf.callMethod('getChannelData'.toJS, 0.toJS) as JSFloat32Array).toDart;
    final step = d.length ~/ n;
    if (step == 0) return Float32List(0);
    final r = Float32List(n);
    for (int i = 0; i < n; i++) {
      double pk = 0;
      final s = i * step;
      final e = math.min(s + step, d.length);
      for (int j = s; j < e; j++) { final v = d[j].abs(); if (v > pk) pk = v; }
      r[i] = pk;
    }
    return r;
  }

  double _detectBpm(JSObject buf) {
    try {
      final sr = (buf.getProperty('sampleRate'.toJS) as JSNumber).toDartDouble;
      final d = (buf.callMethod('getChannelData'.toJS, 0.toJS) as JSFloat32Array).toDart;
      if (d.length < sr * 2) return 0;
      final ws = (sr * 0.02).toInt();
      final hop = ws ~/ 2;
      final nw = (d.length - ws) ~/ hop;
      final energy = Float32List(nw);
      for (int i = 0; i < nw; i++) {
        double s = 0; final st = i * hop;
        for (int j = 0; j < ws; j++) { final v = d[st + j]; s += v * v; }
        energy[i] = s / ws;
      }
      final onset = Float32List(nw);
      for (int i = 1; i < nw; i++) {
        final df = energy[i] - energy[i - 1];
        onset[i] = df > 0 ? df : 0;
      }
      final minL = (60.0 / 200 * sr / hop).round();
      final maxL = (60.0 / 60 * sr / hop).round();
      double best = 0; int bestL = 0;
      for (int l = minL; l < math.min(maxL, nw ~/ 2); l++) {
        double c = 0; final n = nw - l;
        for (int i = 0; i < n; i++) c += onset[i] * onset[i + l];
        if (c > best) { best = c; bestL = l; }
      }
      if (bestL == 0) return 0;
      return (60.0 / (bestL * hop / sr) * 2).round() / 2.0;
    } catch (_) { return 0; }
  }

  // ─── Playback ───

  void play() {
    if (_playing) return;
    _ensureRunning().then((_) => _doPlay());
  }

  void _doPlay() {
    _stopSources();
    _ctxStartTime = _ctx!.currentTime.toDartDouble;
    _playing = true;
    int count = 0;

    for (final t in _tracks) {
      final g = _gainNodes[t.id]; if (g == null) continue;
      for (final c in t.clips) {
        if (c.buffer == null || c.endTime <= _offset) continue;
        final src = _ctx!.createBufferSource();
        src['buffer'] = c.buffer;
        _connect(src, g);

        final into = _offset - c.startTime;
        final now = _ctx!.currentTime.toDartDouble;
        if (into >= 0 && into < c.clipDuration) {
          src.callMethod('start'.toJS, now.toJS, (c.offset + into).toJS, (c.clipDuration - into).toJS);
        } else if (into < 0) {
          src.callMethod('start'.toJS, (now - into).toJS, c.offset.toJS, c.clipDuration.toJS);
        }
        _sources.add(src);
        count++;
      }
    }
    debugPrint('[Engine] Play: $count sources from $_offset');
    if (metronomeEnabled) _startMet();
    if (loop.isActive && loop.isValid) _startLoop();
  }

  void pause() {
    if (!_playing) return;
    _offset = playhead;
    _stopSources(); _stopMet(); _stopLoop();
    _playing = false;
  }

  void stop() {
    _stopSources(); _stopMet(); _stopLoop();
    _playing = false; _offset = 0;
  }

  void seekTo(double t) {
    final was = _playing;
    if (_playing) { _stopSources(); _stopMet(); _stopLoop(); _playing = false; }
    _offset = t.clamp(0, totalDuration);
    if (was) play();
  }

  void _stopSources() {
    for (final s in _sources) {
      try { s.callMethod('stop'.toJS, 0.toJS); } catch (_) {}
    }
    _sources.clear();
  }

  // ─── Metronome ───

  void _startMet() {
    _metTimer?.cancel();
    _scheduleMet();
    _metTimer = Timer.periodic(Duration(milliseconds: (timing.secondsPerBar * 500).round().clamp(200, 2000)), (_) => _scheduleMet());
  }

  void _scheduleMet() {
    if (_ctx == null || !_playing) return;
    final now = _ctx!.currentTime.toDartDouble;
    final ph = playhead;
    final look = timing.secondsPerBar * 2;
    final sb = (timing.secondsToBeats(ph)).floor();
    final eb = timing.secondsToBeats(ph + look).ceil();
    for (int b = sb; b <= eb; b++) {
      final when = now + (timing.beatsToSeconds(b.toDouble()) - ph);
      if (when < now - 0.01 || when > now + look + 0.5) continue;
      _click(when, b % timing.beatsPerBar == 0);
    }
  }

  void _click(double when, bool accent) {
    try {
      final osc = _ctx!.callMethod('createOscillator'.toJS) as JSObject;
      final g = _ctx!.createGain();
      osc.setProperty('type'.toJS, 'sine'.toJS);
      _setParam(osc, 'frequency', accent ? 1000 : 800);
      _setParam(g, 'gain', accent ? 0.3 : 0.15);
      _connect(osc, g); _connect(g, _masterGain!);
      osc.callMethod('start'.toJS, when.toJS);
      osc.callMethod('stop'.toJS, (when + 0.03).toJS);
    } catch (e) {
      debugPrint('[Engine] Click failed: $e');
    }
  }

  void _stopMet() { _metTimer?.cancel(); }

  // ─── Loop ───

  void _startLoop() {
    _loopTimer?.cancel();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_playing || !loop.isActive || !loop.isValid) return;
      if (playhead >= loop.endTime) {
        _stopSources(); _stopMet(); _playing = false; _offset = loop.startTime; play();
      }
    });
  }

  void _stopLoop() { _loopTimer?.cancel(); }

  // ─── Count-in ───

  Future<void> _countIn() async {
    _countingIn = true;
    await _ensureRunning();
    final now = _ctx!.currentTime.toDartDouble;
    final spb = timing.secondsPerBeat;
    for (int i = 0; i < 4; i++) _click(now + i * spb, i == 0);
    await Future.delayed(Duration(milliseconds: (4 * spb * 1000).round()));
    _countingIn = false;
  }

  // ─── Recording ───

  Future<void> startRecording() async {
    if (_recording || _activeTrackId == null) return;
    await _ensureRunning();
    await _countIn();

    // Get mic — simple, no fancy constraints that might fail
    try {
      _mic = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS)).toDart;
    } catch (e) {
      debugPrint('[Engine] getUserMedia FAILED: $e');
      return;
    }

    debugPrint('[Engine] Mic active: ${_mic!.active}');
    _ctx!.createMediaStreamSource(_mic!); // creates node but don't connect to output

    _chunks.clear();
    final mime = _bestMime();
    JSObject? opts;
    if (mime.isNotEmpty) { opts = JSObject(); opts['mimeType'] = mime.toJS; }
    _recorder = _Rec(_mic!, opts);

    _recorder!.addEventListener('dataavailable', ((JSAny ev) {
      final blob = (ev as JSObject).getProperty('data'.toJS) as web.Blob?;
      if (blob != null && blob.size > 0) _chunks.add(blob);
    }).toJS);

    _recStart = (loop.isActive && loop.isValid) ? loop.startTime : snap(playhead);
    _recorder!.start(250);
    _recording = true;
    debugPrint('[Engine] REC started, track=$_activeTrackId, pos=$_recStart');

    if (!_playing) {
      if (loop.isActive && loop.isValid) seekTo(loop.startTime);
      play();
    }
  }

  Future<void> stopRecording() async {
    if (!_recording) return;
    _recording = false;
    pause();

    final c = Completer<void>();
    _recorder!.addEventListener('stop', ((JSAny _) {
      _stopMic();
      _decode().then((__) => c.complete());
    }).toJS);
    _recorder!.stop();
    await c.future;
  }

  Future<void> _decode() async {
    debugPrint('[Engine] Decoding ${_chunks.length} chunks');
    if (_chunks.isEmpty || _activeTrackId == null) return;

    final parts = _chunks.map((b) => b as JSAny).toList();
    final blob = web.Blob(parts.toJS);
    debugPrint('[Engine] Blob: ${blob.size} bytes');

    final ab = (await blob.arrayBuffer().toDart) as JSArrayBuffer;
    try {
      final buf = (await _ctx!.decodeAudioData(ab).toDart)! as JSObject;
      final dur = (buf.getProperty('duration'.toJS) as JSNumber).toDartDouble;
      debugPrint('[Engine] Vocal decoded: ${dur.toStringAsFixed(1)}s');

      final track = _tracks.firstWhere((t) => t.id == _activeTrackId);
      track.addClip(buf, _recStart, waveform: _waveform(buf, 300));
    } catch (e) {
      debugPrint('[Engine] DECODE FAILED: $e');
    }
  }

  void _stopMic() {
    if (_mic == null) return;
    for (final t in _mic!.getTracks().toDart) t.stop();
  }

  String _bestMime() {
    for (final m in ['audio/webm;codecs=opus', 'audio/webm', 'audio/ogg;codecs=opus', 'audio/mp4']) {
      if (_Rec.isSupported(m)) return m;
    }
    return '';
  }

  // ─── Clip ops ───

  void moveClip(String id, double t) {
    for (final tr in _tracks) for (final c in tr.clips) {
      if (c.id == id) { c.startTime = snap(t.clamp(0, double.infinity)); return; }
    }
  }

  void trimClipLeft(String id, double d) {
    for (final tr in _tracks) for (final c in tr.clips) {
      if (c.id != id) continue;
      final no = (c.offset + d).clamp(0.0, c.bufferDuration - AudioClip.minDuration);
      final trimmed = no - c.offset;
      c.offset = no; c.startTime = snap(c.startTime + trimmed);
      c.clipDuration = (c.clipDuration - trimmed).clamp(AudioClip.minDuration, c.maxDuration);
      return;
    }
  }

  void trimClipRight(String id, double d) {
    for (final tr in _tracks) for (final c in tr.clips) {
      if (c.id != id) continue;
      c.clipDuration = (c.clipDuration + d).clamp(AudioClip.minDuration, c.maxDuration);
      return;
    }
  }

  void deleteClip(String id) { for (final t in _tracks) t.removeClip(id); }

  String? duplicateClip(String id) {
    for (final t in _tracks) for (final c in t.clips) {
      if (c.id != id || !t.canAddClip || c.buffer == null) continue;
      final n = t.addClip(c.buffer!, snap(c.endTime), waveform: c.waveformCache);
      if (n != null) { n.offset = c.offset; n.clipDuration = c.clipDuration; }
      return n?.id;
    }
    return null;
  }

  String? splitClip(String id, double time) {
    for (final t in _tracks) for (final c in t.clips) {
      if (c.id != id || time <= c.startTime || time >= c.endTime) continue;
      if (!t.canAddClip || c.buffer == null) return null;
      final split = time - c.startTime;
      final origDur = c.clipDuration;
      c.clipDuration = split;
      final r = t.addClip(c.buffer!, snap(time), waveform: c.waveformCache);
      if (r != null) { r.offset = c.offset + split; r.clipDuration = origDur - split; }
      return r?.id;
    }
    return null;
  }

  // ─── AI actions ───

  void aiAlignVocals() {
    for (final t in _tracks) { if (t.isBeat) continue; for (final c in t.clips) c.startTime = snap(c.startTime); }
  }

  String? aiMakeDouble(String clipId) {
    for (final t in _tracks) for (final c in t.clips) {
      if (c.id != clipId || c.buffer == null) continue;
      final dbl = addVocalTrack('${t.name} Dbl');
      if (dbl == null) return null;
      final n = dbl.addClip(c.buffer!, c.startTime + 0.02, waveform: c.waveformCache);
      if (n != null) { n.offset = c.offset; n.clipDuration = c.clipDuration; }
      dbl.volume = 0.7;
      _applyGains();
      return n?.id;
    }
    return null;
  }

  void aiEnhanceSound(String trackId) {
    // Simple: boost volume slightly and enable FX flag
    final t = _tracks.firstWhere((t) => t.id == trackId);
    t.fx.enabled = true;
    t.fx.presetId = FxPresetId.wideStar;
    t.fx.intensity = 0.8;
  }

  void aiAutoMix() {
    final vocals = _tracks.where((t) => !t.isBeat && t.hasAudio).toList();
    for (final t in vocals) {
      double avg = 0; int cnt = 0;
      for (final c in t.clips) {
        if (c.waveformCache == null) continue;
        for (final v in c.waveformCache!) avg += v;
        cnt += c.waveformCache!.length;
      }
      if (cnt == 0) continue;
      avg /= cnt;
      t.volume = avg < 0.01 ? 1.0 : (0.15 / avg).clamp(0.3, 1.5);
    }
    _applyGains();
  }

  void setTrackFxEnabled(String id, bool on) { _tracks.firstWhere((t) => t.id == id).fx.enabled = on; }
  void setTrackFxPreset(String id, FxPresetId p) { _tracks.firstWhere((t) => t.id == id).fx.presetId = p; }
  void setTrackFxIntensity(String id, double v) { _tracks.firstWhere((t) => t.id == id).fx.intensity = v.clamp(0, 1); }
  void setAutotuneEnabled(String id, bool on) { _tracks.firstWhere((t) => t.id == id).fx.autotuneEnabled = on; }
  void setAutotuneStrength(String id, double v) { _tracks.firstWhere((t) => t.id == id).fx.autotuneStrength = v.clamp(0, 1); }
  void setAutotuneKey(String id, MusicalKey k) { _tracks.firstWhere((t) => t.id == id).fx.autotuneKey = k; }

  // ─── Export ───

  Future<String> exportBlobUrl() async => web.URL.createObjectURL(_mixWav());

  void downloadWav(String fn) {
    final url = web.URL.createObjectURL(_mixWav());
    final a = web.document.createElement('a') as web.HTMLAnchorElement;
    a.href = url; a.download = fn; a.click(); web.URL.revokeObjectURL(url);
  }

  web.Blob _mixWav() {
    final dur = totalDuration; if (dur == 0) throw Exception('No audio');
    final sr = _ctx!.sampleRate.toDartDouble.toInt();
    final len = (sr * dur).toInt();
    final mL = Float32List(len), mR = Float32List(len);
    final solo = _tracks.any((t) => t.isSolo);
    for (final t in _tracks) {
      double v = t.volume;
      if (t.isMuted) v = 0; if (solo && !t.isSolo) v = 0; if (v == 0) continue;
      for (final c in t.clips) {
        if (c.buffer == null) continue;
        final nCh = (c.buffer!.getProperty('numberOfChannels'.toJS) as JSNumber).toDartInt;
        final dL = (c.buffer!.callMethod('getChannelData'.toJS, 0.toJS) as JSFloat32Array).toDart;
        final dR = nCh > 1 ? (c.buffer!.callMethod('getChannelData'.toJS, 1.toJS) as JSFloat32Array).toDart : dL;
        final ds = (c.startTime * sr).toInt(), ss = (c.offset * sr).toInt();
        final n = (c.clipDuration * sr).toInt();
        for (int i = 0; i < n; i++) {
          final d = ds + i, s = ss + i;
          if (d < 0 || d >= len || s < 0 || s >= dL.length) continue;
          mL[d] += dL[s] * v; mR[d] += dR[s] * v;
        }
      }
    }
    return web.Blob([_wav(mL, mR, sr).toJS].toJS, web.BlobPropertyBag(type: 'audio/wav'));
  }

  Uint8List _wav(Float32List l, Float32List r, int sr) {
    final n = l.length; const ch = 2, bps = 16;
    final br = sr * ch * bps ~/ 8; const ba = ch * bps ~/ 8; final ds = n * ch * bps ~/ 8;
    final b = ByteData(44 + ds);
    void w8(int o, int v) => b.setUint8(o, v);
    void w16(int o, int v) => b.setUint16(o, v, Endian.little);
    void w32(int o, int v) => b.setUint32(o, v, Endian.little);
    w8(0,0x52);w8(1,0x49);w8(2,0x46);w8(3,0x46);w32(4,36+ds);
    w8(8,0x57);w8(9,0x41);w8(10,0x56);w8(11,0x45);
    w8(12,0x66);w8(13,0x6D);w8(14,0x74);w8(15,0x20);
    w32(16,16);w16(20,1);w16(22,ch);w32(24,sr);w32(28,br);w16(32,ba);w16(34,bps);
    w8(36,0x64);w8(37,0x61);w8(38,0x74);w8(39,0x61);w32(40,ds);
    int off = 44;
    for (int i = 0; i < n; i++) {
      b.setInt16(off, (l[i].clamp(-1,1)*32767).round().clamp(-32768,32767), Endian.little); off+=2;
      b.setInt16(off, (r[i].clamp(-1,1)*32767).round().clamp(-32768,32767), Endian.little); off+=2;
    }
    return b.buffer.asUint8List();
  }

  // ─── Device listing ───

  Future<List<({String id, String label})>> listInputDevices() async {
    try {
      await web.window.navigator.mediaDevices.getUserMedia(web.MediaStreamConstraints(audio: true.toJS)).toDart;
      final devs = await web.window.navigator.mediaDevices.enumerateDevices().toDart;
      final r = <({String id, String label})>[];
      for (final d in devs.toDart) {
        if (d.kind == 'audioinput') r.add((id: d.deviceId, label: d.label.isNotEmpty ? d.label : 'Mic ${r.length + 1}'));
      }
      return r;
    } catch (_) { return []; }
  }

  void dispose() { _stopSources(); _stopMet(); _stopLoop(); _stopMic(); _ctx?.close(); }
}
