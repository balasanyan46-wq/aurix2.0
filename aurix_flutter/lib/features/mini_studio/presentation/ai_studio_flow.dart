import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;
import 'package:dio/dio.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// AURIX AI Studio — simple 3-step flow:
/// 1. Load beat + record vocal
/// 2. Choose style + process on server
/// 3. Listen to result + export
class AiStudioFlow extends StatefulWidget {
  const AiStudioFlow({super.key});
  @override
  State<AiStudioFlow> createState() => _AiStudioFlowState();
}

enum _Step { record, process, result }

class _AiStudioFlowState extends State<AiStudioFlow> {
  _Step _step = _Step.record;

  // Beat
  String? _beatName;
  Uint8List? _beatBytes;
  web.HTMLAudioElement? _beatPlayer;
  bool _beatPlaying = false;
  double _beatDuration = 0;
  double _beatPosition = 0;
  Timer? _posTimer;

  // Recording
  web.MediaStream? _mic;
  web.MediaRecorder? _recorder;
  final _chunks = <web.Blob>[];
  bool _isRecording = false;
  web.Blob? _vocalBlob;
  String? _vocalUrl;
  web.HTMLAudioElement? _vocalPlayer;
  bool _vocalPlaying = false;

  // Processing
  String _style = 'wide_star';
  double _autotuneStrength = 0.5;
  String _autotuneKey = 'C_major';
  bool _autotuneOn = true;
  bool _processing = false;
  String _processingStep = '';

  // Result
  String? _resultUrl;
  web.HTMLAudioElement? _resultPlayer;
  bool _resultPlaying = false;
  bool _abShowOriginal = false; // A/B toggle

  @override
  void dispose() {
    _posTimer?.cancel();
    _beatPlayer?.pause();
    _vocalPlayer?.pause();
    _resultPlayer?.pause();
    _stopMic();
    super.dispose();
  }

  // ─── Beat ───

  Future<void> _pickBeat() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (r == null || r.files.isEmpty || r.files.first.bytes == null) return;

    _beatBytes = r.files.first.bytes!;
    _beatName = r.files.first.name;

    // Create audio element for playback
    final blob = web.Blob([_beatBytes!.toJS].toJS, web.BlobPropertyBag(type: 'audio/mpeg'));
    final url = web.URL.createObjectURL(blob);
    _beatPlayer = web.HTMLAudioElement()..src = url;
    _beatPlayer!.addEventListener('loadedmetadata', ((JSAny _) {
      setState(() => _beatDuration = _beatPlayer!.duration);
    }).toJS);
    _beatPlayer!.addEventListener('ended', ((JSAny _) {
      setState(() => _beatPlaying = false);
    }).toJS);

    setState(() {});
  }

  void _toggleBeat() {
    if (_beatPlayer == null) return;
    if (_beatPlaying) {
      _beatPlayer!.pause();
      _posTimer?.cancel();
    } else {
      _beatPlayer!.play();
      _posTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() => _beatPosition = _beatPlayer!.currentTime);
      });
    }
    setState(() => _beatPlaying = !_beatPlaying);
  }

  // ─── Record ───

  Future<void> _startRecord() async {
    if (_beatPlayer == null) return;

    try {
      _mic = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS)).toDart;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Микрофон недоступен: $e'), backgroundColor: AurixTokens.danger));
      return;
    }

    _chunks.clear();
    final mime = _bestMime();
    web.MediaRecorderOptions? opts;
    if (mime.isNotEmpty) { opts = web.MediaRecorderOptions(mimeType: mime); }
    _recorder = web.MediaRecorder(_mic!, opts ?? web.MediaRecorderOptions());

    _recorder!.addEventListener('dataavailable', ((JSAny ev) {
      final blob = (ev as JSObject).getProperty('data'.toJS) as web.Blob?;
      if (blob != null && blob.size > 0) _chunks.add(blob);
    }).toJS);

    _recorder!.start(250);
    _beatPlayer!.currentTime = 0;
    _beatPlayer!.play();
    _posTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() => _beatPosition = _beatPlayer!.currentTime);
    });

    setState(() { _isRecording = true; _beatPlaying = true; _vocalBlob = null; _vocalUrl = null; });
  }

  Future<void> _stopRecord() async {
    if (!_isRecording) return;
    setState(() => _isRecording = false);

    _beatPlayer?.pause();
    _posTimer?.cancel();
    setState(() => _beatPlaying = false);

    final c = Completer<void>();
    _recorder!.addEventListener('stop', ((JSAny _) {
      _stopMic();
      if (_chunks.isNotEmpty) {
        _vocalBlob = web.Blob(_chunks.map((b) => b as JSAny).toList().toJS);
        _vocalUrl = web.URL.createObjectURL(_vocalBlob!);
        _vocalPlayer = web.HTMLAudioElement()..src = _vocalUrl!;
      }
      c.complete();
    }).toJS);
    _recorder!.stop();
    await c.future;
    setState(() {});
  }

  void _toggleVocal() {
    if (_vocalPlayer == null) return;
    if (_vocalPlaying) { _vocalPlayer!.pause(); }
    else { _vocalPlayer!.play(); }
    setState(() => _vocalPlaying = !_vocalPlaying);
  }

  void _stopMic() {
    if (_mic == null) return;
    for (final t in _mic!.getTracks().toDart) t.stop();
    _mic = null;
  }

  String _bestMime() {
    for (final m in ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4']) {
      if (web.MediaRecorder.isTypeSupported(m)) return m;
    }
    return '';
  }

  // ─── Process (full pipeline: vocal processing + beat mix + mastering) ───

  Future<void> _process() async {
    if (_vocalBlob == null || _beatBytes == null) return;
    setState(() { _step = _Step.process; _processing = true; _processingStep = 'Загружаем на сервер...'; });

    try {
      final vocalAB = (await _vocalBlob!.arrayBuffer().toDart) as JSArrayBuffer;
      final vocalBytes = vocalAB.toDart.asUint8List();

      setState(() => _processingStep = 'Обработка вокала + микс + мастеринг...');

      final formData = FormData.fromMap({
        'beat': MultipartFile.fromBytes(_beatBytes!, filename: _beatName ?? 'beat.mp3'),
        'vocal': MultipartFile.fromBytes(vocalBytes, filename: 'vocal.webm'),
      });

      final res = await ApiClient.dio.post(
        '/api/ai/full-pipeline',
        data: formData,
        queryParameters: {
          'style': _style,
          'autotune': _autotuneOn ? 'on' : 'off',
          'strength': _autotuneStrength.toString(),
          'key': _autotuneKey,
          'target': 'spotify',
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      setState(() => _processingStep = 'Готово!');

      final resultBytes = Uint8List.fromList(res.data as List<int>);
      final resultBlob = web.Blob([resultBytes.toJS].toJS, web.BlobPropertyBag(type: 'audio/wav'));
      _resultUrl = web.URL.createObjectURL(resultBlob);
      _resultPlayer = web.HTMLAudioElement()..src = _resultUrl!;

      setState(() { _step = _Step.result; _processing = false; });
    } catch (e) {
      setState(() { _processing = false; _step = _Step.record; _processingStep = ''; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обработки: $e'), backgroundColor: AurixTokens.danger));
    }
  }

  void _toggleResult() {
    if (_resultPlayer == null) return;
    if (_resultPlaying) { _resultPlayer!.pause(); }
    else { _resultPlayer!.play(); }
    setState(() => _resultPlaying = !_resultPlaying);
  }

  void _download() {
    if (_resultUrl == null) return;
    final a = web.document.createElement('a') as web.HTMLAnchorElement;
    a.href = _resultUrl!;
    a.download = '${_beatName ?? "track"}_processed.wav';
    a.click();
  }

  void _retry() {
    _resultPlayer?.pause();
    setState(() { _step = _Step.record; _resultUrl = null; _resultPlayer = null; });
  }

  // ─── BUILD ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: switch (_step) {
              _Step.record => _buildRecord(),
              _Step.process => _buildProcess(),
              _Step.result => _buildResult(),
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AurixTokens.surface1.withValues(alpha: 0.5),
                border: Border.all(color: AurixTokens.stroke(0.15))),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AurixTokens.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Text('AI СТУДИЯ', style: TextStyle(
            fontFamily: AurixTokens.fontDisplay, fontSize: 16,
            fontWeight: FontWeight.w700, color: AurixTokens.text, letterSpacing: 1.5)),
          const Spacer(),
          // Step indicator
          Row(children: [
            _dot(_step == _Step.record, 'Запись'),
            const SizedBox(width: 8),
            _dot(_step == _Step.process, 'Стиль'),
            const SizedBox(width: 8),
            _dot(_step == _Step.result, 'Результат'),
          ]),
        ],
      ),
    );
  }

  Widget _dot(bool active, String label) {
    return Column(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? AurixTokens.accent : AurixTokens.surface2)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(
        fontFamily: AurixTokens.fontMono, fontSize: 8,
        color: active ? AurixTokens.accent : AurixTokens.micro)),
    ]);
  }

  // ─── STEP 1: RECORD ───

  Widget _buildRecord() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(children: [
          const SizedBox(height: 24),

          // Beat upload
          if (_beatBytes == null) ...[
            GestureDetector(
              onTap: _pickBeat,
              child: Container(
                height: 120, width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.3)),
                  color: AurixTokens.accent.withValues(alpha: 0.04)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.music_note_rounded, size: 32, color: AurixTokens.accent.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text('Загрузи бит', style: TextStyle(
                    fontFamily: AurixTokens.fontBody, fontSize: 16,
                    fontWeight: FontWeight.w700, color: AurixTokens.accent)),
                  Text('MP3, WAV, OGG', style: TextStyle(
                    fontFamily: AurixTokens.fontMono, fontSize: 11, color: AurixTokens.muted)),
                ]),
              ),
            ),
          ] else ...[
            // Beat player
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AurixTokens.surface1.withValues(alpha: 0.4),
                border: Border.all(color: AurixTokens.stroke(0.12))),
              child: Column(children: [
                Row(children: [
                  Icon(Icons.music_note_rounded, size: 18, color: AurixTokens.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_beatName ?? 'Бит', overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: AurixTokens.fontBody, fontSize: 14,
                      fontWeight: FontWeight.w600, color: AurixTokens.text))),
                  GestureDetector(
                    onTap: _pickBeat,
                    child: Text('Сменить', style: TextStyle(
                      fontFamily: AurixTokens.fontBody, fontSize: 12, color: AurixTokens.muted))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  GestureDetector(
                    onTap: _toggleBeat,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AurixTokens.accent),
                      child: Icon(_beatPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white, size: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _beatDuration > 0 ? (_beatPosition / _beatDuration).clamp(0, 1) : 0,
                        backgroundColor: AurixTokens.surface2,
                        valueColor: AlwaysStoppedAnimation(AurixTokens.accent.withValues(alpha: 0.6)),
                        minHeight: 4)),
                    const SizedBox(height: 4),
                    Text(_fmt(_beatPosition), style: TextStyle(
                      fontFamily: AurixTokens.fontMono, fontSize: 11, color: AurixTokens.muted)),
                  ])),
                ]),
              ]),
            ),
          ],

          const SizedBox(height: 32),

          // Record button
          if (_beatBytes != null) ...[
            GestureDetector(
              onTap: _isRecording ? _stopRecord : _startRecord,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? AurixTokens.danger : AurixTokens.accent,
                  boxShadow: [BoxShadow(
                    color: (_isRecording ? AurixTokens.danger : AurixTokens.accent).withValues(alpha: 0.3),
                    blurRadius: 24, spreadRadius: -4)]),
                child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 12),
            Text(_isRecording ? 'Остановить запись' : 'Нажми и читай под бит',
              style: TextStyle(fontFamily: AurixTokens.fontBody, fontSize: 14, color: AurixTokens.muted)),
          ],

          const SizedBox(height: 32),

          // Vocal preview
          if (_vocalUrl != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AurixTokens.positive.withValues(alpha: 0.06),
                border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.2))),
              child: Row(children: [
                GestureDetector(
                  onTap: _toggleVocal,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: AurixTokens.positive.withValues(alpha: 0.15)),
                    child: Icon(_vocalPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AurixTokens.positive, size: 20)),
                ),
                const SizedBox(width: 12),
                Text('Твоя запись', style: TextStyle(
                  fontFamily: AurixTokens.fontBody, fontSize: 14,
                  fontWeight: FontWeight.w600, color: AurixTokens.text)),
                const Spacer(),
                GestureDetector(
                  onTap: _startRecord,
                  child: Text('Переписать', style: TextStyle(
                    fontFamily: AurixTokens.fontBody, fontSize: 12, color: AurixTokens.muted))),
              ]),
            ),
            const SizedBox(height: 24),

            // Next button
            GestureDetector(
              onTap: _process,
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [AurixTokens.accent, AurixTokens.accentMuted]),
                  boxShadow: [BoxShadow(color: AurixTokens.accent.withValues(alpha: 0.25),
                    blurRadius: 16, spreadRadius: -4)]),
                child: Center(child: Text('Обработать →', style: TextStyle(
                  fontFamily: AurixTokens.fontBody, fontSize: 16,
                  fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ),
          ],
        ]),
      )),
    );
  }

  // ─── STEP 2: PROCESS ───

  Widget _buildProcess() {
    if (_processing) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 40, height: 40,
          child: CircularProgressIndicator(strokeWidth: 3, color: AurixTokens.accent)),
        const SizedBox(height: 20),
        Text(_processingStep, style: TextStyle(
          fontFamily: AurixTokens.fontBody, fontSize: 14, color: AurixTokens.text)),
        const SizedBox(height: 8),
        Text('Обычно 3-5 секунд', style: TextStyle(
          fontFamily: AurixTokens.fontBody, fontSize: 12, color: AurixTokens.muted)),
      ]));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(children: [
          const SizedBox(height: 16),
          Text('Выбери стиль', style: TextStyle(
            fontFamily: AurixTokens.fontDisplay, fontSize: 20,
            fontWeight: FontWeight.w700, color: AurixTokens.text)),
          const SizedBox(height: 24),

          // Style chips
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final s in [('trap', 'Trap'), ('pop', 'Pop'), ('dark', 'Dark'), ('wide_star', 'Wide Star'), ('lofi', 'Lo-Fi'), ('rnb', 'R&B'), ('phonk', 'Phonk'), ('drill', 'Drill')])
              _styleChip(s.$1, s.$2),
          ]),
          const SizedBox(height: 32),

          // AutoTune toggle
          Row(children: [
            Text('AutoTune', style: TextStyle(
              fontFamily: AurixTokens.fontBody, fontSize: 14,
              fontWeight: FontWeight.w600, color: AurixTokens.text)),
            const Spacer(),
            Switch(
              value: _autotuneOn,
              onChanged: (v) => setState(() => _autotuneOn = v),
              activeColor: AurixTokens.accent),
          ]),

          if (_autotuneOn) ...[
            const SizedBox(height: 8),
            Row(children: [
              Text('Сила: ${(_autotuneStrength * 100).round()}%', style: TextStyle(
                fontFamily: AurixTokens.fontMono, fontSize: 12, color: AurixTokens.muted)),
              Expanded(child: Slider(
                value: _autotuneStrength, min: 0, max: 1,
                activeColor: AurixTokens.accent,
                onChanged: (v) => setState(() => _autotuneStrength = v))),
            ]),
          ],

          const SizedBox(height: 32),

          // Process button
          GestureDetector(
            onTap: _process,
            child: Container(
              width: double.infinity, height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [AurixTokens.aiAccent, AurixTokens.accent]),
                boxShadow: [BoxShadow(color: AurixTokens.aiAccent.withValues(alpha: 0.25),
                  blurRadius: 16, spreadRadius: -4)]),
              child: Center(child: Text('✨ Обработать', style: TextStyle(
                fontFamily: AurixTokens.fontBody, fontSize: 16,
                fontWeight: FontWeight.w700, color: Colors.white))),
            ),
          ),
        ]),
      )),
    );
  }

  Widget _styleChip(String id, String label) {
    final sel = _style == id;
    return GestureDetector(
      onTap: () => setState(() => _style = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: sel ? AurixTokens.accent.withValues(alpha: 0.15) : AurixTokens.surface1.withValues(alpha: 0.4),
          border: Border.all(
            color: sel ? AurixTokens.accent.withValues(alpha: 0.5) : AurixTokens.stroke(0.12),
            width: sel ? 1.5 : 1),
          boxShadow: sel ? [BoxShadow(color: AurixTokens.accent.withValues(alpha: 0.1), blurRadius: 10)] : null),
        child: Text(label, style: TextStyle(
          fontFamily: AurixTokens.fontBody, fontSize: 14,
          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          color: sel ? AurixTokens.accent : AurixTokens.textSecondary)),
      ),
    );
  }

  // ─── STEP 3: RESULT ───

  Widget _buildResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(children: [
          const SizedBox(height: 32),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AurixTokens.positive.withValues(alpha: 0.1)),
            child: Icon(Icons.check_rounded, size: 32, color: AurixTokens.positive)),
          const SizedBox(height: 16),
          Text('Готово!', style: TextStyle(
            fontFamily: AurixTokens.fontDisplay, fontSize: 24,
            fontWeight: FontWeight.w700, color: AurixTokens.text)),
          const SizedBox(height: 4),
          Text('Трек обработан в стиле ${_style.replaceAll('_', ' ')}',
            style: TextStyle(fontFamily: AurixTokens.fontBody, fontSize: 14, color: AurixTokens.muted)),
          const SizedBox(height: 32),

          // A/B toggle
          Container(
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AurixTokens.surface1.withValues(alpha: 0.4),
              border: Border.all(color: AurixTokens.stroke(0.12))),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: () { setState(() => _abShowOriginal = false); _vocalPlayer?.pause(); setState(() => _vocalPlaying = false); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: !_abShowOriginal ? AurixTokens.positive.withValues(alpha: 0.15) : Colors.transparent),
                  child: Text('После обработки', style: TextStyle(
                    fontFamily: AurixTokens.fontBody, fontSize: 13,
                    fontWeight: !_abShowOriginal ? FontWeight.w700 : FontWeight.w500,
                    color: !_abShowOriginal ? AurixTokens.positive : AurixTokens.muted))))),
              Expanded(child: GestureDetector(
                onTap: () { setState(() => _abShowOriginal = true); _resultPlayer?.pause(); setState(() => _resultPlaying = false); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: _abShowOriginal ? AurixTokens.muted.withValues(alpha: 0.15) : Colors.transparent),
                  child: Text('Оригинал', style: TextStyle(
                    fontFamily: AurixTokens.fontBody, fontSize: 13,
                    fontWeight: _abShowOriginal ? FontWeight.w700 : FontWeight.w500,
                    color: _abShowOriginal ? AurixTokens.text : AurixTokens.micro))))),
            ]),
          ),
          const SizedBox(height: 16),

          // Active player
          _playerCard(
            _abShowOriginal ? 'Оригинальная запись' : 'Обработанный трек',
            _abShowOriginal ? _vocalPlayer : _resultPlayer,
            _abShowOriginal ? _vocalPlaying : _resultPlaying,
            _abShowOriginal ? _toggleVocal : _toggleResult,
            _abShowOriginal ? AurixTokens.muted : AurixTokens.positive),
          const SizedBox(height: 32),

          // Download
          GestureDetector(
            onTap: _download,
            child: Container(
              width: double.infinity, height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [AurixTokens.accent, AurixTokens.accentMuted])),
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Скачать WAV', style: TextStyle(
                  fontFamily: AurixTokens.fontBody, fontSize: 16,
                  fontWeight: FontWeight.w700, color: Colors.white)),
              ])),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => context.push('/releases/create'),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.3))),
                child: Center(child: Text('Выпустить трек', style: TextStyle(
                  fontFamily: AurixTokens.fontBody, fontSize: 13,
                  fontWeight: FontWeight.w600, color: AurixTokens.positive)))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: _retry,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AurixTokens.stroke(0.15))),
                child: Center(child: Text('Обработать иначе', style: TextStyle(
                  fontFamily: AurixTokens.fontBody, fontSize: 13,
                  fontWeight: FontWeight.w600, color: AurixTokens.muted)))))),
          ]),
        ]),
      )),
    );
  }

  Widget _playerCard(String label, web.HTMLAudioElement? player, bool playing, VoidCallback onTap, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.15))),
      child: Row(children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
            child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: color, size: 22)),
        ),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(
          fontFamily: AurixTokens.fontBody, fontSize: 14,
          fontWeight: FontWeight.w600, color: AurixTokens.text)),
      ]),
    );
  }

  String _fmt(double s) {
    if (s.isNaN || s.isInfinite) return '0:00';
    return '${s ~/ 60}:${(s.toInt() % 60).toString().padLeft(2, '0')}';
  }
}
