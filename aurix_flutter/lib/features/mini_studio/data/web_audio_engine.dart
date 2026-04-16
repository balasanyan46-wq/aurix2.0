import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

// ─── JS interop: Web Audio API types ───

@JS('AudioContext')
extension type JSAudioCtx._(JSObject _) implements JSObject {
  external factory JSAudioCtx();
  external JSObject get destination;
  external JSString get state;
  external JSNumber get sampleRate;
  external JSNumber get currentTime;
  external JSPromise resume();
  external JSPromise close();
  external JSObject createGain();
  external JSObject createAnalyser();
  external JSObject createDynamicsCompressor();
  external JSObject createBiquadFilter();
  external JSObject createConvolver();
  external JSObject createBufferSource();
  external JSObject createBuffer(int channels, int length, num sampleRate);
  external JSPromise decodeAudioData(JSArrayBuffer data);
  external JSObject createMediaStreamSource(web.MediaStream stream);
}

@JS('MediaRecorder')
extension type JSMediaRec._(JSObject _) implements web.EventTarget {
  external factory JSMediaRec(web.MediaStream stream, [JSObject? options]);
  external void start([int? timeslice]);
  external void stop();
  @JS('isTypeSupported')
  external static bool typeSupported(String type);
}

// Helper to get/set JS properties on opaque JSObject nodes.
extension _NodeOps on JSObject {
  JSObject connectTo(JSObject dest) => callMethod('connect'.toJS, dest) as JSObject;
  void disconnectAll() => callMethod('disconnect'.toJS);

  void setParam(String name, num value) {
    final param = this[name] as JSObject;
    param['value'] = value.toJS;
  }

  double getParam(String name) {
    final param = this[name] as JSObject;
    return (param['value'] as JSNumber).toDartDouble;
  }

  void setProp(String name, JSAny? value) {
    this[name] = value;
  }

  T getProp<T extends JSAny?>(String name) => this[name] as T;
}

// ─── Preset definitions ───

class EffectPreset {
  final String id;
  final String label;
  final double compressorThreshold;
  final double compressorRatio;
  final double eqLowGain;
  final double eqMidGain;
  final double eqHighGain;
  final double reverbMix;
  final double pitchShift;

  const EffectPreset({
    required this.id,
    required this.label,
    this.compressorThreshold = -24,
    this.compressorRatio = 4,
    this.eqLowGain = 0,
    this.eqMidGain = 0,
    this.eqHighGain = 0,
    this.reverbMix = 0,
    this.pitchShift = 0,
  });
}

const kPresets = <EffectPreset>[
  EffectPreset(id: 'clean', label: 'Clean', compressorThreshold: -20, compressorRatio: 2),
  EffectPreset(id: 'rap', label: 'Rap', compressorThreshold: -18, compressorRatio: 6,
      eqLowGain: 3, eqMidGain: 2, eqHighGain: 4),
  EffectPreset(id: 'pop', label: 'Pop', compressorThreshold: -22, compressorRatio: 3,
      eqLowGain: -1, eqMidGain: 3, eqHighGain: 2, reverbMix: 0.3),
  EffectPreset(id: 'autotune', label: 'AutoTune Lite', compressorThreshold: -20,
      compressorRatio: 4, eqMidGain: 2, eqHighGain: 3, reverbMix: 0.15, pitchShift: 0.5),
];

// ─── Engine ───

class WebAudioEngine {
  JSAudioCtx? _ctx;
  JSObject? _beatGain;
  JSObject? _vocalGain;
  JSObject? _masterGain;
  JSObject? _beatSource;
  JSObject? _beatBuffer;
  JSObject? _beatAnalyser;
  JSObject? _vocalAnalyser;

  JSObject? _compressor;
  JSObject? _eqLow;
  JSObject? _eqMid;
  JSObject? _eqHigh;
  JSObject? _convolver;
  JSObject? _reverbWet;
  JSObject? _reverbDry;

  web.MediaStream? _micStream;
  JSObject? _micSource;
  JSMediaRec? _recorder;
  final List<web.Blob> _recordedChunks = [];
  JSObject? _vocalBuffer;

  bool _playing = false;
  bool _recording = false;
  double _beatStartTime = 0;
  double _beatOffset = 0;
  EffectPreset _currentPreset = kPresets[0];

  bool get isPlaying => _playing;
  bool get isRecording => _recording;
  bool get hasBeat => _beatBuffer != null;
  bool get hasVocal => _vocalBuffer != null;
  EffectPreset get currentPreset => _currentPreset;

  double get beatDuration =>
      _beatBuffer != null ? (_beatBuffer!['duration'] as JSNumber).toDartDouble : 0;

  Future<void> init() async {
    _ctx = JSAudioCtx();

    _masterGain = _ctx!.createGain();
    _masterGain!.setParam('gain', 1.0);
    _masterGain!.connectTo(_ctx!.destination);

    _beatGain = _ctx!.createGain();
    _beatGain!.setParam('gain', 0.8);
    _beatAnalyser = _ctx!.createAnalyser();
    _beatAnalyser!['fftSize'] = 2048.toJS;
    _beatGain!.connectTo(_beatAnalyser!);
    _beatAnalyser!.connectTo(_masterGain!);

    _compressor = _ctx!.createDynamicsCompressor();
    _eqLow = _ctx!.createBiquadFilter();
    _eqLow!['type'] = 'lowshelf'.toJS;
    _eqLow!.setParam('frequency', 320);
    _eqMid = _ctx!.createBiquadFilter();
    _eqMid!['type'] = 'peaking'.toJS;
    _eqMid!.setParam('frequency', 1000);
    _eqMid!.setParam('Q', 1.0);
    _eqHigh = _ctx!.createBiquadFilter();
    _eqHigh!['type'] = 'highshelf'.toJS;
    _eqHigh!.setParam('frequency', 3200);

    _reverbWet = _ctx!.createGain();
    _reverbWet!.setParam('gain', 0);
    _reverbDry = _ctx!.createGain();
    _reverbDry!.setParam('gain', 1.0);
    _convolver = _ctx!.createConvolver();
    _convolver!['buffer'] = _generateImpulseResponse(2.0, 2.0);

    _vocalGain = _ctx!.createGain();
    _vocalGain!.setParam('gain', 1.0);
    _vocalAnalyser = _ctx!.createAnalyser();
    _vocalAnalyser!['fftSize'] = 2048.toJS;

    _compressor!.connectTo(_eqLow!);
    _eqLow!.connectTo(_eqMid!);
    _eqMid!.connectTo(_eqHigh!);
    _eqHigh!.connectTo(_reverbDry!);
    _eqHigh!.connectTo(_convolver!);
    _convolver!.connectTo(_reverbWet!);
    _reverbDry!.connectTo(_vocalGain!);
    _reverbWet!.connectTo(_vocalGain!);
    _vocalGain!.connectTo(_vocalAnalyser!);
    _vocalAnalyser!.connectTo(_masterGain!);

    _applyPreset(_currentPreset);
  }

  JSObject _generateImpulseResponse(double duration, double decay) {
    final sampleRate = _ctx!.sampleRate.toDartDouble;
    final length = (sampleRate * duration).toInt();
    final buffer = _ctx!.createBuffer(2, length, sampleRate);
    final rng = math.Random();
    for (int ch = 0; ch < 2; ch++) {
      final jsData = buffer.callMethod('getChannelData'.toJS, ch.toJS) as JSFloat32Array;
      final data = jsData.toDart;
      for (int i = 0; i < length; i++) {
        data[i] = (rng.nextDouble() * 2 - 1) * math.pow(1 - i / length, decay);
      }
    }
    return buffer;
  }

  Future<void> loadBeatFromFile(web.File file) async {
    final arrayBuf = (await file.arrayBuffer().toDart) as JSArrayBuffer;
    _beatBuffer = (await _ctx!.decodeAudioData(arrayBuf).toDart)! as JSObject;
  }

  Future<void> loadBeatFromBytes(Uint8List bytes) async {
    if (_ctx!.state.toDart == 'suspended') await _ctx!.resume().toDart;
    final jsArr = bytes.toJS;
    final arrayBuf = (jsArr as JSObject).getProperty('buffer'.toJS) as JSArrayBuffer;
    _beatBuffer = (await _ctx!.decodeAudioData(arrayBuf).toDart)! as JSObject;
  }

  Float32List? getBeatWaveform() {
    if (_beatAnalyser == null) return null;
    final len = (_beatAnalyser!['frequencyBinCount'] as JSNumber).toDartInt;
    final jsArr = JSFloat32Array.withLength(len);
    _beatAnalyser!.callMethod('getFloatTimeDomainData'.toJS, jsArr);
    return jsArr.toDart;
  }

  Float32List? getVocalWaveform() {
    if (_vocalAnalyser == null) return null;
    final len = (_vocalAnalyser!['frequencyBinCount'] as JSNumber).toDartInt;
    final jsArr = JSFloat32Array.withLength(len);
    _vocalAnalyser!.callMethod('getFloatTimeDomainData'.toJS, jsArr);
    return jsArr.toDart;
  }

  Float32List? getBeatStaticWaveform({int samples = 200}) {
    if (_beatBuffer == null) return null;
    final jsData = _beatBuffer!.callMethod('getChannelData'.toJS, 0.toJS) as JSFloat32Array;
    final channelData = jsData.toDart;
    final step = channelData.length ~/ samples;
    if (step == 0) return null;
    final result = Float32List(samples);
    for (int i = 0; i < samples; i++) {
      double max = 0;
      final start = i * step;
      final end = math.min(start + step, channelData.length);
      for (int j = start; j < end; j++) {
        final abs = channelData[j].abs();
        if (abs > max) max = abs;
      }
      result[i] = max;
    }
    return result;
  }

  void playBeat() {
    if (_beatBuffer == null || _ctx == null) return;
    stopBeat();

    if (_ctx!.state.toDart == 'suspended') _ctx!.resume();

    _beatSource = _ctx!.createBufferSource();
    _beatSource!['buffer'] = _beatBuffer;
    _beatSource!.connectTo(_beatGain!);
    _beatSource!.callMethod('start'.toJS, 0.toJS, _beatOffset.toJS);
    _beatStartTime = _ctx!.currentTime.toDartDouble - _beatOffset;
    _playing = true;

    _beatSource!['onended'] = ((JSAny e) {
      _playing = false;
      _beatOffset = 0;
    }).toJS;
  }

  void stopBeat() {
    if (_beatSource != null && _playing) {
      _beatOffset = _ctx!.currentTime.toDartDouble - _beatStartTime;
      try {
        _beatSource!.callMethod('stop'.toJS, 0.toJS);
      } catch (_) {}
      _playing = false;
    }
  }

  void resetBeat() {
    stopBeat();
    _beatOffset = 0;
  }

  double get currentTime {
    if (!_playing) return _beatOffset;
    return _ctx!.currentTime.toDartDouble - _beatStartTime;
  }

  Future<void> startRecording() async {
    if (_recording) return;

    if (_ctx!.state.toDart == 'suspended') {
      await _ctx!.resume().toDart;
    }

    _micStream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart;

    _micSource = _ctx!.createMediaStreamSource(_micStream!);
    _micSource!.connectTo(_compressor!);

    _recordedChunks.clear();

    final mimeType = _getSupportedMimeType();
    JSObject? opts;
    if (mimeType.isNotEmpty) {
      opts = JSObject();
      opts['mimeType'] = mimeType.toJS;
    }
    _recorder = JSMediaRec(_micStream!, opts);

    _recorder!.addEventListener(
      'dataavailable',
      ((JSAny event) {
        final data = (event as JSObject)['data'];
        if (data != null) {
          final blob = data as web.Blob;
          if (blob.size > 0) _recordedChunks.add(blob);
        }
      }).toJS,
    );

    _recorder!.start(100);
    _recording = true;

    resetBeat();
    playBeat();
  }

  String _getSupportedMimeType() {
    const types = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/mp4',
    ];
    for (final type in types) {
      if (JSMediaRec.typeSupported(type)) return type;
    }
    return '';
  }

  Future<void> stopRecording() async {
    if (!_recording) return;
    _recording = false;
    stopBeat();

    final completer = Completer<void>();

    _recorder!.addEventListener(
      'stop',
      ((JSAny _) {
        _micSource?.disconnectAll();
        _stopMicTracks();
        _decodeRecordedVocal().then((_) => completer.complete());
      }).toJS,
    );

    _recorder!.stop();
    await completer.future;
  }

  Future<void> _decodeRecordedVocal() async {
    if (_recordedChunks.isEmpty) return;
    final parts = _recordedChunks.map((b) => b as JSAny).toList();
    final blob = web.Blob(parts.toJS);
    final arrayBuf = (await blob.arrayBuffer().toDart) as JSArrayBuffer;
    try {
      _vocalBuffer = (await _ctx!.decodeAudioData(arrayBuf).toDart)! as JSObject;
    } catch (e) {
      debugPrint('Failed to decode vocal: $e');
    }
  }

  void _stopMicTracks() {
    if (_micStream == null) return;
    final tracks = _micStream!.getTracks();
    for (final track in tracks.toDart) {
      track.stop();
    }
  }

  void playMixed() {
    resetBeat();
    playBeat();

    if (_vocalBuffer != null) {
      final src = _ctx!.createBufferSource();
      src['buffer'] = _vocalBuffer;
      src.connectTo(_compressor!);
      src.callMethod('start'.toJS, 0.toJS);
    }
  }

  void setBeatVolume(double v) => _beatGain?.setParam('gain', v.clamp(0.0, 1.0));
  void setVocalVolume(double v) => _vocalGain?.setParam('gain', v.clamp(0.0, 1.5));

  void applyPreset(EffectPreset preset) {
    _currentPreset = preset;
    _applyPreset(preset);
  }

  void _applyPreset(EffectPreset p) {
    _compressor?.setParam('threshold', p.compressorThreshold);
    _compressor?.setParam('ratio', p.compressorRatio);
    _eqLow?.setParam('gain', p.eqLowGain);
    _eqMid?.setParam('gain', p.eqMidGain);
    _eqHigh?.setParam('gain', p.eqHighGain);
    _reverbWet?.setParam('gain', p.reverbMix);
    _reverbDry?.setParam('gain', 1.0 - p.reverbMix * 0.5);
  }

  Future<String> exportBlobUrl() async {
    final blob = _exportWavBlob();
    return web.URL.createObjectURL(blob);
  }

  void downloadWav(String filename) {
    final blob = _exportWavBlob();
    final url = web.URL.createObjectURL(blob);
    final a = web.document.createElement('a') as web.HTMLAnchorElement;
    a.href = url;
    a.download = filename;
    a.click();
    web.URL.revokeObjectURL(url);
  }

  web.Blob _exportWavBlob() {
    final dur = beatDuration;
    final vDur = _vocalBuffer != null
        ? (_vocalBuffer!['duration'] as JSNumber).toDartDouble
        : 0.0;
    final duration = dur > 0 ? dur : vDur;
    if (duration == 0) throw Exception('No audio to export');

    final sampleRate = _ctx!.sampleRate.toDartDouble.toInt();
    final length = (sampleRate * duration).toInt();

    final mixed = Float32List(length);
    final mixedR = Float32List(length);

    if (_beatBuffer != null) {
      final nCh = (_beatBuffer!['numberOfChannels'] as JSNumber).toDartInt;
      final beatL = (_beatBuffer!.callMethod('getChannelData'.toJS, 0.toJS) as JSFloat32Array).toDart;
      final beatR = nCh > 1
          ? (_beatBuffer!.callMethod('getChannelData'.toJS, 1.toJS) as JSFloat32Array).toDart
          : beatL;
      final beatVol = _beatGain?.getParam('gain') ?? 0.8;
      final len = math.min(length, beatL.length);
      for (int i = 0; i < len; i++) {
        mixed[i] += beatL[i] * beatVol;
        mixedR[i] += beatR[i] * beatVol;
      }
    }

    if (_vocalBuffer != null) {
      final vocalL = (_vocalBuffer!.callMethod('getChannelData'.toJS, 0.toJS) as JSFloat32Array).toDart;
      final vocalVol = _vocalGain?.getParam('gain') ?? 1.0;
      final len = math.min(length, vocalL.length);
      for (int i = 0; i < len; i++) {
        mixed[i] += vocalL[i] * vocalVol;
        mixedR[i] += vocalL[i] * vocalVol;
      }
    }

    final wavBytes = _encodeWav(mixed, mixedR, sampleRate);
    return web.Blob([wavBytes.toJS].toJS, web.BlobPropertyBag(type: 'audio/wav'));
  }

  Uint8List _encodeWav(Float32List left, Float32List right, int sampleRate) {
    final numSamples = left.length;
    const numChannels = 2;
    const bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = numSamples * numChannels * bitsPerSample ~/ 8;
    final fileSize = 36 + dataSize;
    final buf = ByteData(44 + dataSize);

    // RIFF
    buf.setUint8(0, 0x52); buf.setUint8(1, 0x49);
    buf.setUint8(2, 0x46); buf.setUint8(3, 0x46);
    buf.setUint32(4, fileSize, Endian.little);
    buf.setUint8(8, 0x57); buf.setUint8(9, 0x41);
    buf.setUint8(10, 0x56); buf.setUint8(11, 0x45);
    // fmt
    buf.setUint8(12, 0x66); buf.setUint8(13, 0x6D);
    buf.setUint8(14, 0x74); buf.setUint8(15, 0x20);
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, numChannels, Endian.little);
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, byteRate, Endian.little);
    buf.setUint16(32, blockAlign, Endian.little);
    buf.setUint16(34, bitsPerSample, Endian.little);
    // data
    buf.setUint8(36, 0x64); buf.setUint8(37, 0x61);
    buf.setUint8(38, 0x74); buf.setUint8(39, 0x61);
    buf.setUint32(40, dataSize, Endian.little);

    int offset = 44;
    for (int i = 0; i < numSamples; i++) {
      final sL = (left[i].clamp(-1.0, 1.0) * 32767).round().clamp(-32768, 32767);
      final sR = (right[i].clamp(-1.0, 1.0) * 32767).round().clamp(-32768, 32767);
      buf.setInt16(offset, sL, Endian.little); offset += 2;
      buf.setInt16(offset, sR, Endian.little); offset += 2;
    }
    return buf.buffer.asUint8List();
  }

  void dispose() {
    stopBeat();
    _stopMicTracks();
    _ctx?.close();
  }
}
