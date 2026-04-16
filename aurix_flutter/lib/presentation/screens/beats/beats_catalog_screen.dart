import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/data/models/beat_model.dart';
import 'package:aurix_flutter/data/providers/beats_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/screens/beats/widgets/beat_card.dart';
import 'package:aurix_flutter/presentation/screens/beats/widgets/beat_player_bar.dart';
import 'package:aurix_flutter/presentation/screens/beats/widgets/beat_purchase_sheet.dart';
import 'package:aurix_flutter/design/widgets/section_onboarding.dart';

class BeatsCatalogScreen extends ConsumerStatefulWidget {
  const BeatsCatalogScreen({super.key});

  @override
  ConsumerState<BeatsCatalogScreen> createState() => _BeatsCatalogScreenState();
}

class _BeatsCatalogScreenState extends ConsumerState<BeatsCatalogScreen> {
  String _search = '';
  String? _genre;
  String? _mood;
  int? _bpmMin;
  int? _bpmMax;
  BeatModel? _playingBeat;

  BeatFilters get _filters => BeatFilters(
        genre: _genre,
        mood: _mood,
        bpmMin: _bpmMin,
        bpmMax: _bpmMax,
        search: _search.isEmpty ? null : _search,
      );

  static const _genres = [
    'Trap', 'Hip-Hop', 'R&B', 'Pop', 'Drill', 'Lo-Fi',
    'Rage', 'Phonk', 'Boom Bap', 'Afrobeat', 'Reggaeton',
  ];

  static const _moods = [
    'Dark', 'Aggressive', 'Chill', 'Sad', 'Energetic',
    'Romantic', 'Uplifting', 'Dreamy', 'Hard',
  ];

  void _onPlay(BeatModel beat) {
    setState(() => _playingBeat = beat);
    ref.read(beatRepositoryProvider).recordPlay(beat.id);
  }

  void _onLike(BeatModel beat) async {
    await ref.read(beatRepositoryProvider).toggleLike(beat.id);
    ref.invalidate(beatsProvider(_filters));
  }

  void _onBuy(BeatModel beat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BeatPurchaseSheet(
        beat: beat,
        onPurchased: () {
          ref.invalidate(beatsProvider(_filters));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final beats = ref.watch(beatsProvider(_filters));
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

    return Stack(
      children: [
        RefreshIndicator(
          color: AurixTokens.accent,
          onRefresh: () async => ref.invalidate(beatsProvider(_filters)),
          child: PremiumPageScaffold(
            title: 'Маркетплейс битов',
            subtitle: 'Найди идеальный бит для своего трека',
            systemLabel: 'BEAT STORE',
            systemColor: AurixTokens.accent,
            trailing: FilledButton.icon(
              onPressed: () => context.push('/beats/upload'),
              icon: const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Загрузить бит'),
              style: FilledButton.styleFrom(
                backgroundColor: AurixTokens.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AurixTokens.radiusButton),
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              isDesktop ? 32 : 16, 20, isDesktop ? 32 : 16,
              _playingBeat != null ? 100 : 32,
            ),
            children: [
              SectionOnboarding(tip: OnboardingTips.beats),
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildFilters(),
              const SizedBox(height: 16),
              beats.when(
                data: (list) => list.isEmpty
                    ? _buildEmptyState()
                    : _buildGrid(list, isDesktop),
                loading: () => _buildLoadingSkeleton(isDesktop),
                error: (e, _) => _buildError(e),
              ),
            ],
          ),
        ),
        if (_playingBeat != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BeatPlayerBar(
              beat: _playingBeat!,
              onClose: () => setState(() => _playingBeat = null),
              onBuy: () => _onBuy(_playingBeat!),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AurixTokens.surface1,
        borderRadius: BorderRadius.circular(AurixTokens.radiusField),
        border: Border.all(color: AurixTokens.stroke(0.18)),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _search = v),
        style: const TextStyle(color: AurixTokens.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Поиск по названию, тегам...',
          hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: AurixTokens.muted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterDropdown(
            label: 'Жанр',
            value: _genre,
            items: _genres,
            onChanged: (v) => setState(() => _genre = v),
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            label: 'Настроение',
            value: _mood,
            items: _moods,
            onChanged: (v) => setState(() => _mood = v),
          ),
          const SizedBox(width: 8),
          _BpmFilter(
            bpmMin: _bpmMin,
            bpmMax: _bpmMax,
            onChanged: (min, max) => setState(() {
              _bpmMin = min;
              _bpmMax = max;
            }),
          ),
          if (_genre != null || _mood != null || _bpmMin != null || _bpmMax != null) ...[
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('Сбросить', style: TextStyle(fontSize: 12)),
              avatar: const Icon(Icons.close, size: 14),
              backgroundColor: AurixTokens.surface1,
              side: BorderSide(color: AurixTokens.stroke(0.18)),
              onPressed: () => setState(() {
                _genre = null;
                _mood = null;
                _bpmMin = null;
                _bpmMax = null;
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGrid(List<BeatModel> beats, bool isDesktop) {
    final crossAxisCount = isDesktop ? 3 : 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isDesktop ? 0.78 : 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: beats.length,
      itemBuilder: (context, index) {
        final beat = beats[index];
        return BeatCard(
          beat: beat,
          isPlaying: _playingBeat?.id == beat.id,
          onPlay: () => _onPlay(beat),
          onLike: () => _onLike(beat),
          onBuy: () => _onBuy(beat),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return PremiumSectionCard(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.music_off_rounded, size: 48, color: AurixTokens.muted),
          const SizedBox(height: 16),
          Text(
            'Биты не найдены',
            style: TextStyle(
              fontFamily: AurixTokens.fontHeading,
              color: AurixTokens.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Попробуй изменить фильтры или загрузи свой бит',
            style: TextStyle(color: AurixTokens.muted, fontSize: 13),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool isDesktop) {
    final count = isDesktop ? 6 : 3;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : 1,
        childAspectRatio: isDesktop ? 0.78 : 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: count,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AurixTokens.surface1,
          borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
          border: Border.all(color: AurixTokens.stroke(0.1)),
        ),
      ),
    );
  }

  Widget _buildError(Object error) {
    return PremiumSectionCard(
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.error_outline_rounded, size: 40, color: AurixTokens.danger),
          const SizedBox(height: 12),
          Text(
            'Ошибка загрузки: $error',
            style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AurixTokens.accent.withValues(alpha: 0.12) : AurixTokens.surface1,
        borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
        border: Border.all(
          color: isActive ? AurixTokens.accent.withValues(alpha: 0.4) : AurixTokens.stroke(0.18),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
          icon: Icon(Icons.expand_more, size: 18, color: isActive ? AurixTokens.accent : AurixTokens.muted),
          dropdownColor: AurixTokens.bg1,
          style: TextStyle(color: AurixTokens.text, fontSize: 13),
          isDense: true,
          items: [
            DropdownMenuItem(
              value: null,
              child: Text('Все', style: TextStyle(color: AurixTokens.muted)),
            ),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _BpmFilter extends StatelessWidget {
  final int? bpmMin;
  final int? bpmMax;
  final void Function(int? min, int? max) onChanged;

  const _BpmFilter({this.bpmMin, this.bpmMax, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isActive = bpmMin != null || bpmMax != null;
    final label = isActive
        ? 'BPM: ${bpmMin ?? '—'} - ${bpmMax ?? '—'}'
        : 'BPM';

    return GestureDetector(
      onTap: () => _showBpmDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AurixTokens.accent.withValues(alpha: 0.12) : AurixTokens.surface1,
          borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
          border: Border.all(
            color: isActive ? AurixTokens.accent.withValues(alpha: 0.4) : AurixTokens.stroke(0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(
              color: isActive ? AurixTokens.accent : AurixTokens.muted,
              fontSize: 13,
            )),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18,
              color: isActive ? AurixTokens.accent : AurixTokens.muted),
          ],
        ),
      ),
    );
  }

  void _showBpmDialog(BuildContext context) {
    int? min = bpmMin;
    int? max = bpmMax;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AurixTokens.bg1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
            side: BorderSide(color: AurixTokens.stroke(0.2)),
          ),
          title: Text('Диапазон BPM', style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            color: AurixTokens.text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          )),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RangeSlider(
                values: RangeValues(
                  (min ?? 60).toDouble(),
                  (max ?? 200).toDouble(),
                ),
                min: 60,
                max: 200,
                divisions: 28,
                activeColor: AurixTokens.accent,
                inactiveColor: AurixTokens.surface2,
                labels: RangeLabels(
                  '${min ?? 60}',
                  '${max ?? 200}',
                ),
                onChanged: (v) {
                  setDialogState(() {
                    min = v.start.round();
                    max = v.end.round();
                  });
                },
              ),
              Text(
                '${min ?? 60} — ${max ?? 200} BPM',
                style: const TextStyle(color: AurixTokens.text, fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                onChanged(null, null);
                Navigator.pop(ctx);
              },
              child: const Text('Сбросить'),
            ),
            FilledButton(
              onPressed: () {
                onChanged(min, max);
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: AurixTokens.accent),
              child: const Text('Применить'),
            ),
          ],
        ),
      ),
    );
  }
}
