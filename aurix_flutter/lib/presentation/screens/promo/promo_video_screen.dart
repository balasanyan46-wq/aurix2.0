import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/track_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'widgets/track_selector.dart';
import 'widgets/promo_audio_player.dart';
import 'widgets/range_selector.dart';
import 'widgets/video_result.dart';

/// Single-request provider: GET /tracks/my returns tracks + release metadata.
final _userTracksProvider = FutureProvider<List<TrackWithRelease>>((ref) async {
  final trackRepo = ref.read(trackRepositoryProvider);
  final raw = await trackRepo.getMyTracks();

  return raw
      .where((r) => (r['audio_url'] ?? '').toString().isNotEmpty)
      .map((r) {
    final track = TrackModel.fromJson(r);
    final release = ReleaseModel(
      id: r['release_id']?.toString() ?? '',
      ownerId: '',
      title: r['release_title']?.toString() ?? '',
      artist: r['artist']?.toString(),
      releaseType: '',
      status: '',
      coverUrl: r['cover_url']?.toString(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return TrackWithRelease(track: track, release: release);
  }).toList();
});

class PromoVideoScreen extends ConsumerStatefulWidget {
  const PromoVideoScreen({super.key});

  @override
  ConsumerState<PromoVideoScreen> createState() => _PromoVideoScreenState();
}

class _PromoVideoScreenState extends ConsumerState<PromoVideoScreen> {
  TrackWithRelease? _selected;
  double _startTime = 0;
  double _endTime = 15;
  double _trackDuration = 0;

  bool _generating = false;
  String? _resultUrl;
  String? _styleUsed;
  String? _error;

  final _playerKey = GlobalKey<PromoAudioPlayerState>();

  void _onTrackSelected(TrackWithRelease t) {
    setState(() {
      _selected = t;
      _startTime = 0;
      _endTime = 15;
      _trackDuration = 0;
      _resultUrl = null;
      _error = null;
    });
  }

  void _onDurationKnown(double d) {
    if (d > 0 && mounted) {
      setState(() {
        _trackDuration = d;
        _endTime = d < 15 ? d : 15;
      });
    }
  }

  void _onRangeChanged(RangeValues v) {
    setState(() {
      _startTime = v.start;
      _endTime = v.end;
    });
  }

  Future<void> _generate() async {
    if (_selected == null) return;
    final segment = _endTime - _startTime;
    if (segment < 3 || segment > 60) return;

    setState(() { _generating = true; _error = null; _resultUrl = null; });

    try {
      final resp = await ApiClient.post('/promo/generate-video',
        data: {
          'trackId': int.tryParse(_selected!.track.id) ?? _selected!.track.id,
          'startTime': _startTime.round(),
          'duration': segment.round(),
          'style': 'auto',
        },
        receiveTimeout: const Duration(minutes: 3),
      );

      if (!mounted) return;
      final respData = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : <String, dynamic>{};
      final url = respData['url'] as String?;
      final usedStyle = respData['styleUsed'] as String?;
      if (url != null && url.isNotEmpty) {
        setState(() {
          _resultUrl = url;
          _styleUsed = usedStyle;
        });
      } else {
        setState(() => _error = 'Не удалось получить URL видео');
      }
    } catch (e) {
      if (!mounted) return;
      String msg = 'Ошибка генерации';
      final s = e.toString();
      if (s.contains('403')) {
        msg = 'Нет доступа к этому треку';
      } else if (s.contains('400')) {
        msg = 'Некорректные параметры';
      } else if (s.contains('429')) {
        msg = 'Слишком много запросов. Подождите минуту';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _reset() {
    setState(() {
      _selected = null;
      _startTime = 0;
      _endTime = 15;
      _trackDuration = 0;
      _resultUrl = null;
      _styleUsed = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(_userTracksProvider);

    return PremiumPageScaffold(
      title: 'Промо-видео',
      children: [
        tracksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
          error: (e, _) => Center(child: Text('Ошибка загрузки: $e', style: const TextStyle(color: AurixTokens.muted))),
          data: (tracks) => _buildContent(tracks),
        ),
      ],
    );
  }

  Widget _buildContent(List<TrackWithRelease> tracks) {
    // If we have a result — show it
    if (_resultUrl != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: VideoResult(
          videoUrl: _resultUrl!,
          styleUsed: _styleUsed,
          onCreateAnother: _reset,
        ),
      );
    }

    // If generating — show loader
    if (_generating) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              color: AurixTokens.accent,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Создаём видео…', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Это может занять до минуты', style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 13)),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Step 1: Track selector
        TrackSelector(
          tracks: tracks,
          selected: _selected,
          onSelect: _onTrackSelected,
        ),

        if (_selected != null) ...[
          const SizedBox(height: 24),

          // Step 2: Audio player
          PromoAudioPlayer(
            key: ValueKey('player_${_selected!.track.id}'),
            url: ApiClient.fixUrl(_selected!.track.audioUrl),
            title: _selected!.track.title ?? 'Трек ${_selected!.track.trackNumber}',
            onDurationKnown: _onDurationKnown,
          ),

          // Step 3: Range selector (show once duration is known)
          if (_trackDuration > 0) ...[
            const SizedBox(height: 20),
            RangeSelector(
              duration: _trackDuration,
              startTime: _startTime,
              endTime: _endTime.clamp(0, _trackDuration),
              onChanged: _onRangeChanged,
            ),
          ],

          const SizedBox(height: 24),

          // Error
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AurixTokens.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.15)),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline, size: 18, color: AurixTokens.danger.withValues(alpha: 0.7)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: TextStyle(color: AurixTokens.danger.withValues(alpha: 0.9), fontSize: 13))),
                ]),
              ),
            ),

          // Step 5: Generate button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_trackDuration > 0 && (_endTime - _startTime) >= 3) ? _generate : null,
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: const Text('Сгенерировать видео', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: AurixTokens.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AurixTokens.glass(0.1),
                disabledForegroundColor: AurixTokens.muted.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              '1080×1920 MP4 · 9:16 · Для Reels / Stories',
              style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.5), fontSize: 12),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ]),
    );
  }
}
