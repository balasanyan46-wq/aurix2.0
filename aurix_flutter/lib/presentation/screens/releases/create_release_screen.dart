import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:io' if (dart.library.html) 'package:aurix_flutter/io_stub.dart' show File;
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/core/api/api_error.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:aurix_flutter/features/covers/cover_generator_sheet.dart';
import 'package:aurix_flutter/presentation/screens/releases/widgets/track_player.dart';
import 'package:aurix_flutter/presentation/screens/releases/widgets/audio_blob_url.dart';

// ═══════════════════════════════════════════════════════════════
// Service model — loaded from server
// ═══════════════════════════════════════════════════════════════

class _Svc {
  final String id;
  String name, description;
  double price;
  int step;
  bool on;

  _Svc({required this.id, required this.name, required this.description, required this.price, required this.step, this.on = false});

  factory _Svc.fromJson(Map<String, dynamic> j) => _Svc(
    id: j['id'] as String? ?? '', name: j['name'] as String? ?? '',
    description: j['description'] as String? ?? '', price: (j['price'] as num?)?.toDouble() ?? 0,
    step: (j['step'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price, 'enabled': on};
}

// ═══════════════════════════════════════════════════════════════
// Genre catalog
// ═══════════════════════════════════════════════════════════════

const _genreMap = <String, List<String>>{
  'Pop': ['Dance Pop', 'Synth Pop', 'Indie Pop', 'Electro Pop', 'Dream Pop', 'K-Pop', 'Art Pop', 'Chamber Pop'],
  'Hip-Hop / Rap': ['Trap', 'Drill', 'Boom Bap', 'Cloud Rap', 'Melodic Rap', 'Gangsta Rap', 'Conscious Rap', 'Mumble Rap', 'Emo Rap', 'Phonk'],
  'R&B': ['Contemporary R&B', 'Neo Soul', 'Alternative R&B', 'Quiet Storm', 'New Jack Swing'],
  'Rock': ['Indie Rock', 'Alternative Rock', 'Punk Rock', 'Post-Punk', 'Shoegaze', 'Grunge', 'Garage Rock', 'Math Rock', 'Emo'],
  'Electronic': ['House', 'Techno', 'Drum & Bass', 'Dubstep', 'Trance', 'Ambient', 'IDM', 'Breakbeat', 'Downtempo', 'UK Garage'],
  'Metal': ['Heavy Metal', 'Death Metal', 'Black Metal', 'Metalcore', 'Deathcore', 'Nu Metal', 'Progressive Metal', 'Doom Metal'],
  'Jazz': ['Smooth Jazz', 'Bebop', 'Fusion', 'Acid Jazz', 'Free Jazz', 'Vocal Jazz', 'Latin Jazz'],
  'Classical': ['Orchestral', 'Chamber', 'Opera', 'Contemporary Classical', 'Neoclassical', 'Minimalism'],
  'Country': ['Country Pop', 'Americana', 'Bluegrass', 'Outlaw Country', 'Country Rock'],
  'Latin': ['Reggaeton', 'Latin Pop', 'Bachata', 'Salsa', 'Cumbia', 'Latin Trap', 'Dembow'],
  'Dancehall': ['Dancehall', 'Reggae', 'Dub', 'Ska', 'Afrobeats'],
  'Lo-Fi': ['Lo-Fi Hip-Hop', 'Lo-Fi Beats', 'Chillhop', 'Bedroom Pop'],
  'Soul / Funk': ['Soul', 'Funk', 'Disco', 'Gospel', 'Motown'],
  'Folk': ['Indie Folk', 'Singer-Songwriter', 'Acoustic', 'Folk Rock', 'Neofolk'],
  'Soundtrack': ['Film Score', 'Game OST', 'Trailer Music', 'Ambient Score'],
  'Other': ['Experimental', 'World Music', 'New Age', 'Spoken Word', 'ASMR', 'Meditation'],
};

final _fallbackSvcs = [
  _Svc(id: 'ai_cover', name: 'AI обложка', description: 'Генерация обложки нейросетью', price: 990, step: 1),
  _Svc(id: 'lyrics_sync', name: 'Синхронизация текста', description: 'Тайминг строк для площадок', price: 1970, step: 3),
  _Svc(id: 'lyrics_check', name: 'AI проверка текста', description: 'Орфография, рифмы, ритмика', price: 0, step: 3),
  _Svc(id: 'pitching', name: 'Питчинг в плейлисты', description: 'Отправка кураторам Spotify / Apple', price: 4970, step: 3),
  _Svc(id: 'tiktok_promo', name: 'TikTok продвижение', description: 'Посев — от 10 блогеров', price: 9970, step: 5),
  _Svc(id: 'youtube_clip', name: 'AI клип для YouTube', description: 'Визуализация трека нейросетью', price: 14970, step: 5),
];

// ═══════════════════════════════════════════════════════════════
// Track entry
// ═══════════════════════════════════════════════════════════════

class _Track {
  PlatformFile file;
  final TextEditingController titleCtrl, isrcCtrl;
  String version;
  bool explicit;

  _Track({required this.file})
      : titleCtrl = TextEditingController(text: file.name.replaceAll(RegExp(r'\.[^.]+$'), '')),
        isrcCtrl = TextEditingController(), version = 'original', explicit = false;

  void dispose() { titleCtrl.dispose(); isrcCtrl.dispose(); }
}

// ═══════════════════════════════════════════════════════════════
// FAQ item
// ═══════════════════════════════════════════════════════════════

class _Faq {
  final String q, a;
  const _Faq(this.q, this.a);
}

const _faqs = [
  _Faq('Куда загружается релиз?', 'Apple Music, iTunes, Spotify, ВКонтакте, Boom, Яндекс Музыка, TikTok, YouTube, Content ID, Deezer, Shazam, Сберзвук и др.'),
  _Faq('В каком виде статистика?', 'В личном кабинете доступна ежедневная статистика по самым популярным площадкам и детализация аудитории'),
  _Faq('Какие финансовые условия?', 'Вы будете получать 90% прибыли. Вывод средств доступен при накоплении минимального баланса в 2000 рублей.'),
];

// ═══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════

class CreateReleaseScreen extends ConsumerStatefulWidget {
  const CreateReleaseScreen({super.key});
  @override
  ConsumerState<CreateReleaseScreen> createState() => _State();
}

class _State extends ConsumerState<CreateReleaseScreen> with TickerProviderStateMixin {
  int _step = 0;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error, _progress;

  // Step 0 — type
  String _type = 'single';

  // Step 1 — info
  final _titleC = TextEditingController();
  final _artistC = TextEditingController();
  String? _genre;
  String? _subGenre;
  final _langC = TextEditingController(text: 'Русский');
  DateTime? _releaseDate;
  DateTime? _tiktokDate;
  bool _yandexSoon = false;
  PlatformFile? _coverFile;
  Uint8List? _coverBytes;
  String? _coverUrl;

  // Step 2 — tracks
  final List<_Track> _tracks = [];
  bool _isPicking = false;

  // Step 3 — important
  final _authorMusicC = TextEditingController();
  final _authorLyricsC = TextEditingController();
  final _subtitleC = TextEditingController();
  final _tiktokClipC = TextEditingController();
  final _copyrightC = TextEditingController();
  final _isrcC = TextEditingController();
  final _upcC = TextEditingController();
  final _lyricsC = TextEditingController();
  bool _explicit = false;
  bool _syncLyrics = false;

  // Step 4 — links
  final _appleC = TextEditingController();
  final _youtubeC = TextEditingController();
  final _spotifyC = TextEditingController();
  final _vkC = TextEditingController();
  final _yandexC = TextEditingController();
  bool _noArtistPage = false;
  bool _termsAccepted = false;

  // Services
  late List<_Svc> _svcs;

  // Step labels
  static const _labels = ['Шаг 1', 'Шаг 2', 'Шаг 3', 'Шаг 4', 'Шаг 5', 'Финал'];
  static const _titles = ['Что загружаем?', 'Информация о релизе', 'Нужны аудио', 'Важная информация', 'Ссылки на площадки', 'Оформление'];

  @override
  void initState() {
    super.initState();
    _svcs = _fallbackSvcs.map((s) => _Svc(id: s.id, name: s.name, description: s.description, price: s.price, step: s.step)).toList();
    _loadPrices();
    final p = ref.read(currentProfileProvider).valueOrNull;
    if (p != null) _artistC.text = p.artistName ?? p.displayName ?? '';
    _copyrightC.text = '\u00a9 ${DateTime.now().year}';
  }

  Future<void> _loadPrices() async {
    try {
      final res = await ApiClient.get('/system/service-prices');
      final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final list = d['services'] as List? ?? [];
      if (list.isNotEmpty && mounted) {
        setState(() { _svcs = list.map((j) => _Svc.fromJson(j is Map<String, dynamic> ? j : Map<String, dynamic>.from(j as Map))).where((s) => s.id.isNotEmpty).toList(); });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [_titleC, _artistC, _langC, _authorMusicC, _authorLyricsC, _subtitleC, _tiktokClipC, _copyrightC, _isrcC, _upcC, _lyricsC, _appleC, _youtubeC, _spotifyC, _vkC, _yandexC]) c.dispose();
    for (final t in _tracks) t.dispose();
    super.dispose();
  }

  double get _total => _svcs.where((s) => s.on).fold(0.0, (a, s) => a + s.price);

  // ── File helpers ──
  Future<Uint8List?> _bytes(PlatformFile f) async {
    if (f.bytes != null) return f.bytes;
    if (!kIsWeb && f.path != null) { try { return await File(f.path!).readAsBytes(); } catch (_) {} }
    return null;
  }

  Future<FilePickerResult?> _pick({required FileType type, bool multi = false}) async {
    if (_isPicking) return null;
    setState(() => _isPicking = true);
    try {
      return await FilePicker.platform.pickFiles(type: type, allowMultiple: multi, withData: true)
          .timeout(const Duration(seconds: 25));
    } on PlatformException catch (e) {
      if (e.code == 'multiple_request') return null;
      rethrow;
    } finally { if (mounted) setState(() => _isPicking = false); else _isPicking = false; }
  }

  Future<void> _pickCover() async {
    final r = await _pick(type: FileType.image);
    if (r == null) return;
    final f = r.files.single;
    if (f.size > 10 * 1024 * 1024) { _snack('Обложка не более 10 МБ'); return; }
    final b = await _bytes(f);
    if (b != null && mounted) setState(() { _coverFile = f; _coverBytes = b; _coverUrl = null; });
  }

  Future<void> _pickTracks() async {
    final r = await _pick(type: FileType.audio, multi: true);
    if (r == null) return;
    if (mounted) setState(() { for (final f in r.files) { if (f.size <= 200 * 1024 * 1024 && (f.bytes != null || f.path != null)) _tracks.add(_Track(file: f)); } });
  }

  Future<void> _aiCover() async {
    if (_loading || _isPicking) return;
    final url = await CoverGeneratorSheet.open(context, initialArtistName: _artistC.text.trim(), initialReleaseTitle: _titleC.text.trim(), initialGenre: (_genre ?? ''), onApplied: null);
    if (!mounted || url == null || url.isEmpty) return;
    setState(() { _coverUrl = url; _coverFile = null; _coverBytes = null; });
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ── Nav ──
  void _next() {
    if (_step == 1 && !(_formKey.currentState?.validate() ?? false)) return;
    if (_step == 2 && _tracks.isEmpty) { setState(() => _error = 'Добавьте хотя бы один трек'); return; }
    if (_step == 4 && !_termsAccepted) {
      setState(() => _error = 'Примите условия публичной Оферты, чтобы продолжить');
      return;
    }
    setState(() { _error = null; _step = (_step + 1).clamp(0, 5); });
  }

  void _prev() => setState(() { _error = null; _step = (_step - 1).clamp(0, 5); });

  // ── Submit ──
  Future<void> _submit() async {
    if (!_termsAccepted) { setState(() => _error = 'Примите условия оферты'); return; }
    final uid = ref.read(currentUserProvider)?.id;
    if (uid == null) { _snack('Войдите в аккаунт'); return; }
    if (_tracks.isEmpty) { setState(() => _error = 'Нет треков'); return; }
    if (_titleC.text.trim().isEmpty) { setState(() => _error = 'Введите название'); return; }

    setState(() { _error = null; _loading = true; _progress = 'Создание релиза...'; });
    try {
      final repo = ref.read(releaseRepositoryProvider);
      final fRepo = ref.read(fileRepositoryProvider);
      final tRepo = ref.read(trackRepositoryProvider);

      final links = <String, String>{};
      if (_spotifyC.text.trim().isNotEmpty) links['spotify'] = _spotifyC.text.trim();
      if (_appleC.text.trim().isNotEmpty) links['apple_music'] = _appleC.text.trim();
      if (_youtubeC.text.trim().isNotEmpty) links['youtube'] = _youtubeC.text.trim();
      if (_vkC.text.trim().isNotEmpty) links['vk'] = _vkC.text.trim();
      if (_yandexC.text.trim().isNotEmpty) links['yandex'] = _yandexC.text.trim();

      final rel = await repo.createRelease(
        ownerId: uid, title: _titleC.text.trim(),
        artist: _artistC.text.trim().isEmpty ? 'Unknown Artist' : _artistC.text.trim(),
        releaseType: _type, releaseDate: _releaseDate,
        genre: _genre == null ? null : _subGenre != null ? '$_genre / $_subGenre' : _genre,
        language: _langC.text.trim().isEmpty ? null : _langC.text.trim(),
        explicit: _explicit,
        upc: _upcC.text.trim().isEmpty ? null : _upcC.text.trim(),
      );

      setState(() => _progress = 'Сохранение данных...');
      await repo.updateRelease(rel.id, {
        if (_lyricsC.text.trim().isNotEmpty) 'lyrics': _lyricsC.text.trim(),
        if (_authorMusicC.text.trim().isNotEmpty) 'copyright_holders': _authorMusicC.text.trim(),
        if (links.isNotEmpty) 'platform_links': links,
        'services': _svcs.where((s) => s.on).map((s) => s.toJson()).toList(),
        'total_price': _total,
        'wizard_step': 5,
      });

      if (_coverUrl != null) {
        setState(() => _progress = 'Сохранение обложки...');
        await repo.updateRelease(rel.id, {'cover_url': _coverUrl!, 'cover_path': _coverUrl!});
      } else if (_coverFile != null) {
        setState(() => _progress = 'Загрузка обложки...');
        final b = _coverBytes ?? await _bytes(_coverFile!);
        if (b == null || b.isEmpty) throw StateError('Файл обложки не читается');
        final u = await fRepo.uploadCoverBytes(uid, rel.id, b, _coverFile!.name);
        await repo.updateRelease(rel.id, {'cover_url': u.publicUrl, 'cover_path': u.coverPath});
      }

      for (var i = 0; i < _tracks.length; i++) {
        final t = _tracks[i];
        setState(() => _progress = 'Загрузка трека ${i + 1}/${_tracks.length}...');
        final b = await _bytes(t.file);
        if (b == null || b.isEmpty) throw StateError('Файл не читается: ${t.file.name}');
        final tid = const Uuid().v4();
        final ext = t.file.extension ?? 'wav';
        final u = await fRepo.uploadTrackBytes(uid, rel.id, tid, b, ext);
        await tRepo.addTrack(id: tid, releaseId: rel.id, userId: uid, audioPath: u.path, audioUrl: u.publicUrl,
          title: t.titleCtrl.text.trim().isEmpty ? t.file.name : t.titleCtrl.text.trim(),
          isrc: t.isrcCtrl.text.trim().isEmpty ? null : t.isrcCtrl.text.trim(), trackNumber: i, version: t.version, explicit: t.explicit);
      }

      if (mounted) { _snack('Релиз создан!'); context.pushReplacement('/releases/${rel.id}'); }
    } catch (e, st) {
      debugPrint('$e\n$st');
      if (!mounted) return;
      final d = formatApiError(e);
      setState(() { _error = d.length > 120 ? '${d.substring(0, 117)}...' : d; _loading = false; _progress = null; });
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final desk = w >= kDesktopBreakpoint;

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: Column(children: [
        // ── Step indicator ──
        _StepBar(current: _step, labels: _labels),

        // ── Sticky price ──
        if (_total > 0) _StickyPrice(count: _svcs.where((s) => s.on).length, total: _total),

        // ── Content ──
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: desk ? 56 : 20, vertical: 32),
            child: Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Title
                Text(_titles[_step], style: TextStyle(fontFamily: AurixTokens.fontDisplay, color: AurixTokens.text, fontSize: desk ? 36 : 26, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.1)),
                const SizedBox(height: 32),
                if (_error != null) ...[_Err(msg: _error!), const SizedBox(height: 20)],
                _buildStep(desk),
                const SizedBox(height: 48),
              ])),
            )),
          ),
        ),

        // ── Bottom nav ──
        _BottomBar(
          step: _step,
          loading: _loading,
          progress: _progress,
          nextEnabled: !(_step == 4 && !_termsAccepted),
          onNext: _next,
          onPrev: _prev,
          onSubmit: _submit,
        ),
      ]),
    );
  }

  Widget _buildStep(bool desk) => switch (_step) {
    0 => _step0(desk), 1 => _step1(desk), 2 => _step2(desk),
    3 => _step3(desk), 4 => _step4(desk), 5 => _step5(desk), _ => const SizedBox(),
  };

  // ═══════════════ STEP 0: TYPE ═══════════════

  Widget _step0(bool desk) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Wrap(spacing: 12, runSpacing: 12, children: [
      _TypeCard(label: 'Сингл', icon: Icons.music_note_rounded, sel: _type == 'single', onTap: () => setState(() => _type = 'single')),
      _TypeCard(label: 'Макси Сингл', icon: Icons.queue_music_rounded, sel: _type == 'maxi_single', onTap: () => setState(() => _type = 'maxi_single')),
      _TypeCard(label: 'Альбом', icon: Icons.album_rounded, sel: _type == 'album', onTap: () => setState(() => _type = 'album')),
      _TypeCard(label: 'EP', icon: Icons.playlist_play_rounded, sel: _type == 'ep', onTap: () => setState(() => _type = 'ep')),
    ]),
    const SizedBox(height: 48),
    ..._faqs.map((f) => _FaqTile(faq: f)),
  ]);

  // ═══════════════ STEP 1: INFO ═══════════════

  Widget _step1(bool desk) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Genre
      _Label('Выберите жанр'),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: DropdownButtonFormField<String>(
          value: _genre,
          dropdownColor: AurixTokens.bg2,
          style: const TextStyle(color: AurixTokens.text, fontSize: 14),
          decoration: const InputDecoration(labelText: 'Жанр'),
          items: _genreMap.keys.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() { _genre = v; _subGenre = null; }),
        )),
        const SizedBox(width: 12),
        Expanded(child: DropdownButtonFormField<String>(
          value: _subGenre,
          dropdownColor: AurixTokens.bg2,
          style: const TextStyle(color: AurixTokens.text, fontSize: 14),
          decoration: const InputDecoration(labelText: 'Поджанр'),
          items: (_genreMap[_genre] ?? []).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => _subGenre = v),
        )),
      ]),
      const SizedBox(height: 32),

      // Cover
      _Label('Обложка'),
      const SizedBox(height: 4),
      Row(children: [
        const Spacer(),
        GestureDetector(onTap: _aiCover, child: Text('Нарисовать обложку', style: TextStyle(color: AurixTokens.accent, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _CoverBox(bytes: _coverBytes, url: _coverUrl, onPick: _pickCover),
        const SizedBox(width: 12),
        _AiCoverBox(onTap: _aiCover),
      ]),
      const SizedBox(height: 32),

      // Artist + Title
      desk
          ? Row(children: [
              Expanded(child: _field('Исполнитель', _artistC, validator: _req)),
              const SizedBox(width: 12),
              Expanded(child: _field('Название релиза', _titleC, validator: _req)),
            ])
          : Column(children: [
              _field('Исполнитель', _artistC, validator: _req),
              const SizedBox(height: 12),
              _field('Название релиза', _titleC, validator: _req),
            ]),
      const SizedBox(height: 16),

      // Language
      _field('Язык композиции', _langC, hint: 'Русский'),
      const SizedBox(height: 16),

      // Dates
      desk
          ? Row(children: [
              Expanded(child: _datePicker('Дата основного релиза', _releaseDate, (d) => setState(() => _releaseDate = d))),
              const SizedBox(width: 12),
              Expanded(child: _datePicker('Дата выхода в TikTok', _tiktokDate, (d) => setState(() => _tiktokDate = d))),
            ])
          : Column(children: [
              _datePicker('Дата основного релиза', _releaseDate, (d) => setState(() => _releaseDate = d)),
              const SizedBox(height: 12),
              _datePicker('Дата выхода в TikTok', _tiktokDate, (d) => setState(() => _tiktokDate = d)),
            ]),
      const SizedBox(height: 20),

      // Yandex soon
      _Label('Яндекс музыка'),
      const SizedBox(height: 8),
      _Toggle(label: 'Скоро новый релиз', desc: 'Слушатель сохраняет релиз в коллекцию до его открытия', value: _yandexSoon, onChanged: (v) => setState(() => _yandexSoon = v)),

      ..._svcWidgets(1),
    ]);
  }

  // ═══════════════ STEP 2: AUDIO ═══════════════

  Widget _step2(bool desk) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    // Upload zone
    _UploadZone(onTap: _pickTracks, hasFiles: _tracks.isNotEmpty),
    const SizedBox(height: 20),

    // Track list
    ..._tracks.asMap().entries.map((e) {
      final i = e.key;
      final t = e.value;
      return _TrackRow(
        key: ValueKey(t),
        index: i, track: t, coverBytes: _coverBytes, coverUrl: _coverUrl,
        onRemove: () => setState(() { t.dispose(); _tracks.removeAt(i); }),
      );
    }),

    if (_tracks.isNotEmpty) ...[
      const SizedBox(height: 12),
      Center(child: TextButton.icon(
        onPressed: _pickTracks,
        icon: Icon(Icons.add_rounded, size: 18, color: AurixTokens.accent),
        label: Text('Добавить ещё', style: TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w600)),
      )),
    ],

    ..._svcWidgets(2),
  ]);

  // ═══════════════ STEP 3: IMPORTANT ═══════════════

  Widget _step3(bool desk) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    desk
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _field('Автор музыки*', _authorMusicC, hint: 'ФИО; ФИО; ...', maxLines: 3)),
            const SizedBox(width: 12),
            Expanded(child: _field('Автор слов*', _authorLyricsC, hint: 'ФИО; ФИО; ...', maxLines: 3)),
          ])
        : Column(children: [
            _field('Автор музыки*', _authorMusicC, hint: 'ФИО; ФИО; ...', maxLines: 3),
            const SizedBox(height: 12),
            _field('Автор слов*', _authorLyricsC, hint: 'ФИО; ФИО; ...', maxLines: 3),
          ]),
    const SizedBox(height: 16),

    _field('Подзаголовок', _subtitleC, hint: 'feat. Artist, Remix...'),
    const SizedBox(height: 16),
    _field('Отрезок в TikTok', _tiktokClipC, hint: '0:15'),
    const SizedBox(height: 16),

    desk
        ? Row(children: [
            Expanded(child: _field('Копирайт \u00a9', _copyrightC)),
            const SizedBox(width: 12),
            Expanded(child: _explicitDropdown()),
          ])
        : Column(children: [
            _field('Копирайт \u00a9', _copyrightC),
            const SizedBox(height: 12),
            _explicitDropdown(),
          ]),
    const SizedBox(height: 16),

    desk
        ? Row(children: [
            Expanded(child: _field('ISRC', _isrcC, hint: 'Код трека')),
            const SizedBox(width: 12),
            Expanded(child: _field('UPC', _upcC, hint: 'Штрихкод')),
          ])
        : Column(children: [
            _field('ISRC', _isrcC, hint: 'Код трека'),
            const SizedBox(height: 12),
            _field('UPC', _upcC, hint: 'Штрихкод'),
          ]),
    const SizedBox(height: 16),

    _field('Текст песни', _lyricsC, hint: 'Вставьте текст...', maxLines: 8),
    const SizedBox(height: 16),

    _Toggle(label: 'Синхронизировать текст', desc: 'Текст будет синхронизирован для караоке на площадках', value: _syncLyrics, onChanged: (v) => setState(() => _syncLyrics = v)),

    ..._svcWidgets(3),
  ]);

  // ═══════════════ STEP 4: LINKS ═══════════════

  Widget _step4(bool desk) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _linkField('Apple Music', _appleC),
    const SizedBox(height: 12),
    _linkField('YouTube', _youtubeC),
    const SizedBox(height: 12),
    _linkField('Spotify', _spotifyC),
    const SizedBox(height: 12),
    _linkField('VK', _vkC),
    const SizedBox(height: 12),
    _linkField('Яндекс', _yandexC),
    const SizedBox(height: 20),

    _Toggle(label: 'Нет карточки артиста', desc: '', value: _noArtistPage, onChanged: (v) => setState(() => _noArtistPage = v)),
    const SizedBox(height: 12),
    _Toggle(label: 'Принимаю условия публичной Оферты', desc: '', value: _termsAccepted, onChanged: (v) => setState(() => _termsAccepted = v), accent: true),

    ..._svcWidgets(4),
  ]);

  // ═══════════════ STEP 5: FINAL ═══════════════

  Widget _step5(bool desk) {
    final enabled = _svcs.where((s) => s.on).toList();
    final basePrice = 2000.0;

    return desk ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Column 1: Release preview
      SizedBox(width: 240, child: _releasePreview()),
      const SizedBox(width: 24),
      // Column 2: Payment
      Expanded(child: _paymentCard()),
      const SizedBox(width: 24),
      // Column 3: Summary
      SizedBox(width: 280, child: _summaryCard(basePrice, enabled)),
    ]) : Column(children: [
      _releasePreview(),
      const SizedBox(height: 20),
      _paymentCard(),
      const SizedBox(height: 20),
      _summaryCard(basePrice, enabled),
    ]);
  }

  Widget _releasePreview() {
    return _Card(child: Column(children: [
      _CardHeader(title: 'РЕЛИЗ'),
      const SizedBox(height: 16),
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 180, height: 180,
          color: AurixTokens.bg2,
          child: _coverBytes != null
              ? Image.memory(_coverBytes!, fit: BoxFit.cover)
              : _coverUrl != null
                  ? Image.network(_coverUrl!, fit: BoxFit.cover)
                  : Icon(Icons.album_rounded, size: 48, color: AurixTokens.muted),
        ),
      ),
      const SizedBox(height: 14),
      Text(_titleC.text.trim().isEmpty ? 'Без названия' : _titleC.text.trim(), style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(_artistC.text.trim().isEmpty ? 'Артист' : _artistC.text.trim(), style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: AurixTokens.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Text(_type == 'single' ? 'Сингл' : _type == 'ep' ? 'EP' : _type == 'album' ? 'Альбом' : 'Макси Сингл', style: TextStyle(color: AurixTokens.accent, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]));
  }

  Widget _paymentCard() {
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _CardHeader(title: 'СПОСОБ ОПЛАТЫ'),
      const SizedBox(height: 16),
      _PayOption(icon: Icons.account_balance_wallet_rounded, label: 'Баланс кабинета', sub: '0 \u20bd', selected: true),
      const SizedBox(height: 16),
      Text('Способ оплаты: Карты РФ', style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _PayMethodChip(label: 'Карты РФ', icon: Icons.credit_card_rounded, selected: true)),
        const SizedBox(width: 10),
        Expanded(child: _PayMethodChip(label: 'Международные', icon: Icons.language_rounded, selected: false)),
      ]),
    ]));
  }

  Widget _summaryCard(double base, List<_Svc> enabled) {
    final svcTotal = enabled.fold(0.0, (a, s) => a + s.price);
    final total = base + svcTotal;

    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _CardHeader(title: 'СВОДКА'),
      const SizedBox(height: 16),
      _PriceRow(label: 'Загрузка релиза', price: base),
      if (svcTotal > 0) _PriceRow(label: 'Доп. услуги', price: svcTotal),
      const Divider(color: AurixTokens.border, height: 24),
      Row(children: [
        const Text('К оплате:', style: TextStyle(color: AurixTokens.text, fontSize: 14)),
        const Spacer(),
        Text('${total.toStringAsFixed(0)} \u20bd', style: TextStyle(color: AurixTokens.accent, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: AurixTokens.fontDisplay)),
      ]),
      const SizedBox(height: 16),
      // Promo
      TextFormField(
        style: const TextStyle(color: AurixTokens.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Промокод',
          hintStyle: TextStyle(color: AurixTokens.muted),
          filled: true, fillColor: AurixTokens.surface1,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AurixTokens.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AurixTokens.border)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ]));
  }

  // ═══════════════ HELPERS ═══════════════

  List<Widget> _svcWidgets(int step) {
    final list = _svcs.where((s) => s.step == step).toList();
    if (list.isEmpty) return [];
    return [const SizedBox(height: 24), ...list.map((s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _SvcCheck(svc: s, onChanged: (v) => setState(() => s.on = v))))];
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null;

  Widget _field(String label, TextEditingController c, {String? hint, String? Function(String?)? validator, int maxLines = 1}) {
    return TextFormField(controller: c, maxLines: maxLines, validator: validator,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontFamily: AurixTokens.fontBody),
      decoration: InputDecoration(labelText: label, hintText: hint));
  }

  Widget _linkField(String label, TextEditingController c) {
    return TextFormField(controller: c,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
      decoration: InputDecoration(labelText: 'Ссылка на карточку в $label', hintText: 'https://...'));
  }

  Widget _datePicker(String label, DateTime? date, ValueChanged<DateTime> onPick) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: date ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030),
          builder: (ctx, ch) => Theme(data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.dark(primary: AurixTokens.accent, surface: AurixTokens.bg1)), child: ch!));
        if (d != null) onPick(d);
      },
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: Icon(Icons.help_outline_rounded, size: 18, color: AurixTokens.muted)),
        child: Text(date != null ? DateFormat('dd.MM.yyyy').format(date) : '', style: const TextStyle(color: AurixTokens.text, fontSize: 14)),
      ),
    );
  }

  Widget _explicitDropdown() {
    return DropdownButtonFormField<bool>(
      value: _explicit, dropdownColor: AurixTokens.bg2,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
      decoration: const InputDecoration(labelText: 'Наличие мата'),
      items: const [DropdownMenuItem(value: false, child: Text('Нет')), DropdownMenuItem(value: true, child: Text('Да'))],
      onChanged: (v) => setState(() => _explicit = v ?? false),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STEP BAR — horizontal with labels + connecting lines
// ═══════════════════════════════════════════════════════════════

class _StepBar extends StatelessWidget {
  final int current;
  final List<String> labels;
  const _StepBar({required this.current, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      color: AurixTokens.bg0,
      child: Row(children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connecting line
          final segIdx = i ~/ 2;
          final done = segIdx < current;
          return Expanded(child: Container(height: 2, color: done ? AurixTokens.accent : AurixTokens.border));
        }
        final idx = i ~/ 2;
        final done = idx < current;
        final active = idx == current;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text(labels[idx], style: TextStyle(
            color: active ? AurixTokens.accent : done ? AurixTokens.text : AurixTokens.muted,
            fontSize: 11, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 6),
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done || active ? AurixTokens.accent : Colors.transparent,
              border: Border.all(color: done || active ? AurixTokens.accent : AurixTokens.muted, width: 1.5),
            ),
          ),
        ]);
      })),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STICKY PRICE
// ═══════════════════════════════════════════════════════════════

class _StickyPrice extends StatelessWidget {
  final int count;
  final double total;
  const _StickyPrice({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(color: AurixTokens.accent.withValues(alpha: 0.06), border: Border(bottom: BorderSide(color: AurixTokens.accent.withValues(alpha: 0.12)))),
      child: Row(children: [
        Icon(Icons.shopping_cart_outlined, size: 16, color: AurixTokens.accent),
        const SizedBox(width: 8),
        Text('$count услуг', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
        const Spacer(),
        Text('${total.toStringAsFixed(0)} \u20bd', style: TextStyle(color: AurixTokens.accent, fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BOTTOM BAR
// ═══════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  final int step;
  final bool loading;
  final bool nextEnabled;
  final String? progress;
  final VoidCallback onNext, onPrev, onSubmit;
  const _BottomBar({required this.step, required this.loading, this.progress, this.nextEnabled = true, required this.onNext, required this.onPrev, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(color: AurixTokens.bg1, border: Border(top: BorderSide(color: AurixTokens.border))),
      child: SafeArea(top: false, child: loading
          ? Container(
              height: 52, decoration: BoxDecoration(color: AurixTokens.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.accent)),
                if (progress != null) ...[const SizedBox(width: 12), Text(progress!, style: TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w600))],
              ]),
            )
          : Row(children: [
              if (step > 0) Expanded(child: OutlinedButton(
                onPressed: onPrev,
                style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.muted, padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: AurixTokens.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Назад', style: TextStyle(fontWeight: FontWeight.w600)),
              )),
              if (step > 0) const SizedBox(width: 12),
              Expanded(flex: 2, child: step < 5
                  ? AurixButton(text: 'Далее', icon: Icons.arrow_forward_rounded, onPressed: nextEnabled ? onNext : null)
                  : AurixButton(text: 'Оплатить', icon: Icons.payment_rounded, onPressed: onSubmit)),
            ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TYPE CARD
// ═══════════════════════════════════════════════════════════════

class _TypeCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool sel;
  final VoidCallback onTap;
  const _TypeCard({required this.label, required this.icon, required this.sel, required this.onTap});
  @override State<_TypeCard> createState() => _TypeCardState();
}

class _TypeCardState extends State<_TypeCard> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true), onExit: (_) => setState(() => _h = false),
      child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
        duration: AurixTokens.dMedium, curve: AurixTokens.cEase,
        width: 160, padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: widget.sel ? AurixTokens.accent.withValues(alpha: 0.08) : _h ? AurixTokens.surface2 : AurixTokens.surface1,
          borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
          border: Border.all(color: widget.sel ? AurixTokens.accent.withValues(alpha: 0.5) : AurixTokens.stroke(0.15), width: widget.sel ? 1.5 : 1),
          boxShadow: widget.sel ? AurixTokens.accentGlowShadow : [],
        ),
        child: Column(children: [
          Icon(widget.icon, size: 28, color: widget.sel ? AurixTokens.accent : AurixTokens.muted),
          const SizedBox(height: 10),
          Text(widget.label, style: TextStyle(color: widget.sel ? AurixTokens.text : AurixTokens.muted, fontWeight: FontWeight.w700, fontSize: 14), textAlign: TextAlign.center),
        ]),
      )),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// FAQ TILE
// ═══════════════════════════════════════════════════════════════

class _FaqTile extends StatefulWidget {
  final _Faq faq;
  const _FaqTile({required this.faq});
  @override State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AurixTokens.stroke(0.1)))),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Row(children: [
            Expanded(child: Text(widget.faq.q, style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700))),
            Icon(_open ? Icons.remove : Icons.add, color: AurixTokens.muted, size: 20),
          ])),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(padding: const EdgeInsets.only(bottom: 18), child: Text(widget.faq.a, style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.6))),
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: AurixTokens.dMedium,
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// COVER BOX
// ═══════════════════════════════════════════════════════════════

class _CoverBox extends StatelessWidget {
  final Uint8List? bytes;
  final String? url;
  final VoidCallback onPick;
  const _CoverBox({this.bytes, this.url, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onPick, child: Container(
      width: 120, height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14), color: AurixTokens.surface1,
        border: Border.all(color: AurixTokens.stroke(0.15)),
        image: bytes != null ? DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover) : url != null ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover) : null,
      ),
      child: (bytes == null && url == null) ? Center(child: Icon(Icons.add_photo_alternate_rounded, color: AurixTokens.muted, size: 32)) : null,
    ));
  }
}

class _AiCoverBox extends StatelessWidget {
  final VoidCallback onTap;
  const _AiCoverBox({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      width: 120, height: 120,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: AurixTokens.surface1, border: Border.all(color: AurixTokens.stroke(0.15))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.auto_awesome_rounded, color: AurixTokens.aiAccent, size: 28),
        const SizedBox(height: 6),
        Text('ИИ студия', style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ));
  }
}

// ═══════════════════════════════════════════════════════════════
// UPLOAD ZONE
// ═══════════════════════════════════════════════════════════════

class _UploadZone extends StatefulWidget {
  final VoidCallback onTap;
  final bool hasFiles;
  const _UploadZone({required this.onTap, required this.hasFiles});
  @override State<_UploadZone> createState() => _UploadZoneState();
}

class _UploadZoneState extends State<_UploadZone> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true), onExit: (_) => setState(() => _h = false),
      child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
        duration: AurixTokens.dMedium,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: _h ? AurixTokens.accent.withValues(alpha: 0.04) : AurixTokens.surface1.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
          border: Border.all(color: _h ? AurixTokens.accent.withValues(alpha: 0.3) : AurixTokens.stroke(0.15), style: BorderStyle.solid),
        ),
        child: Column(children: [
          Text('Загрузите WAV файл(ы)', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(
              onPressed: widget.onTap,
              icon: Icon(Icons.upload_file_rounded, size: 18, color: AurixTokens.text),
              label: const Text('Заменить'),
              style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.text),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: widget.onTap,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(widget.hasFiles ? 'Продолжить' : 'Выбрать файлы'),
              style: FilledButton.styleFrom(backgroundColor: AurixTokens.positive, foregroundColor: Colors.white),
            ),
          ]),
        ]),
      )),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TRACK ROW
// ═══════════════════════════════════════════════════════════════

class _TrackRow extends StatefulWidget {
  final int index;
  final _Track track;
  final Uint8List? coverBytes;
  final String? coverUrl;
  final VoidCallback onRemove;

  const _TrackRow({super.key, required this.index, required this.track, this.coverBytes, this.coverUrl, required this.onRemove});

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> {
  String? _audioUrl;

  @override
  void initState() {
    super.initState();
    _buildAudioUrl();
  }

  void _buildAudioUrl() {
    final f = widget.track.file;
    // Web: build a blob URL from bytes. Mobile/desktop: use file path.
    if (f.bytes != null && f.bytes!.isNotEmpty) {
      final ext = f.extension?.toLowerCase() ?? '';
      final mime = ext == 'wav' ? 'audio/wav'
          : ext == 'mp3' ? 'audio/mpeg'
          : ext == 'flac' ? 'audio/flac'
          : ext == 'aac' || ext == 'm4a' ? 'audio/aac'
          : ext == 'ogg' ? 'audio/ogg'
          : 'audio/mpeg';
      final url = createAudioBlobUrl(f.bytes!, mime);
      if (url.isNotEmpty) _audioUrl = url;
    } else if (!kIsWeb && f.path != null) {
      _audioUrl = f.path;
    }
  }

  @override
  void dispose() {
    if (_audioUrl != null && _audioUrl!.startsWith('blob:')) {
      revokeAudioBlobUrl(_audioUrl!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    final sizeMb = (track.file.size / (1024 * 1024)).toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AurixTokens.surface1, borderRadius: BorderRadius.circular(14), border: Border.all(color: AurixTokens.stroke(0.12))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Cover thumb
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8), color: AurixTokens.bg2,
              image: widget.coverBytes != null ? DecorationImage(image: MemoryImage(widget.coverBytes!), fit: BoxFit.cover) : widget.coverUrl != null ? DecorationImage(image: NetworkImage(widget.coverUrl!), fit: BoxFit.cover) : null,
            ),
            child: (widget.coverBytes == null && widget.coverUrl == null) ? Icon(Icons.music_note_rounded, size: 20, color: AurixTokens.muted) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(track.titleCtrl.text, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('$sizeMb МБ', style: TextStyle(color: AurixTokens.muted, fontSize: 11)),
          ])),
          const SizedBox(width: 8),
          IconButton(icon: Icon(Icons.delete_outline_rounded, size: 20, color: AurixTokens.danger), onPressed: widget.onRemove),
        ]),
        if (_audioUrl != null) ...[
          const SizedBox(height: 12),
          TrackPlayer(key: ValueKey('player-${_audioUrl!}'), url: _audioUrl!),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TOGGLE
// ═══════════════════════════════════════════════════════════════

class _Toggle extends StatelessWidget {
  final String label, desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool accent;
  const _Toggle({required this.label, required this.desc, required this.value, required this.onChanged, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: value ? (accent ? AurixTokens.accent : AurixTokens.text).withValues(alpha: 0.9) : Colors.transparent,
            border: Border.all(color: value ? Colors.transparent : AurixTokens.muted, width: 1.5),
          ),
          child: value ? const Icon(Icons.check_rounded, size: 16, color: AurixTokens.bg0) : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: accent && value ? AurixTokens.accent : AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w500)),
          if (desc.isNotEmpty) Text(desc, style: TextStyle(color: AurixTokens.muted, fontSize: 11)),
        ])),
      ])),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LABEL
// ═══════════════════════════════════════════════════════════════

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override Widget build(BuildContext context) => Text(text, style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700));
}

// ═══════════════════════════════════════════════════════════════
// CARD
// ═══════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AurixTokens.surface1, borderRadius: BorderRadius.circular(AurixTokens.radiusCard), border: Border.all(color: AurixTokens.stroke(0.12))),
    child: child,
  );
}

class _CardHeader extends StatelessWidget {
  final String title;
  const _CardHeader({required this.title});
  @override Widget build(BuildContext context) => Text(title, style: TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5));
}

// ═══════════════════════════════════════════════════════════════
// PAYMENT WIDGETS
// ═══════════════════════════════════════════════════════════════

class _PayOption extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final bool selected;
  const _PayOption({required this.icon, required this.label, required this.sub, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? AurixTokens.positive.withValues(alpha: 0.06) : AurixTokens.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AurixTokens.positive.withValues(alpha: 0.3) : AurixTokens.border),
      ),
      child: Row(children: [
        Icon(selected ? Icons.check_circle_rounded : icon, size: 22, color: selected ? AurixTokens.positive : AurixTokens.muted),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(sub, style: TextStyle(color: selected ? AurixTokens.positive : AurixTokens.muted, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _PayMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  const _PayMethodChip({required this.label, required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: selected ? AurixTokens.surface2 : AurixTokens.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AurixTokens.accent.withValues(alpha: 0.3) : AurixTokens.border),
      ),
      child: Column(children: [
        Icon(icon, size: 24, color: selected ? AurixTokens.text : AurixTokens.muted),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: selected ? AurixTokens.text : AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double price;
  const _PriceRow({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
      Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
      const Spacer(),
      Text('${price.toStringAsFixed(0)} \u20bd', style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600)),
    ]));
  }
}

// ═══════════════════════════════════════════════════════════════
// SERVICE CHECKBOX
// ═══════════════════════════════════════════════════════════════

class _SvcCheck extends StatelessWidget {
  final _Svc svc;
  final ValueChanged<bool> onChanged;
  const _SvcCheck({required this.svc, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!svc.on),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: AurixTokens.dMedium,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: svc.on ? AurixTokens.accent.withValues(alpha: 0.05) : AurixTokens.surface1.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: svc.on ? AurixTokens.accent.withValues(alpha: 0.3) : AurixTokens.stroke(0.12)),
        ),
        child: Row(children: [
          Icon(svc.on ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 22, color: svc.on ? AurixTokens.accent : AurixTokens.muted),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(svc.name, style: TextStyle(color: svc.on ? AurixTokens.accent : AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(svc.price > 0 ? '${svc.price.toStringAsFixed(0)} \u20bd' : 'Бесплатно', style: TextStyle(color: AurixTokens.accent, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
            if (svc.description.isNotEmpty) ...[const SizedBox(height: 2), Text(svc.description, style: TextStyle(color: AurixTokens.muted, fontSize: 12))],
          ])),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ERROR BANNER
// ═══════════════════════════════════════════════════════════════

class _Err extends StatelessWidget {
  final String msg;
  const _Err({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AurixTokens.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: AurixTokens.danger, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(msg, style: const TextStyle(color: AurixTokens.danger, fontSize: 13))),
      ]),
    );
  }
}
