import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';

/// Релиз — пошаговый экран: Информация → Треки → Участники → Проверка → Отправка.
class ReleaseDetailScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;

  const ReleaseDetailScreen({super.key, required this.release});

  @override
  ConsumerState<ReleaseDetailScreen> createState() => _ReleaseDetailScreenState();
}

class _ReleaseDetailScreenState extends ConsumerState<ReleaseDetailScreen> {
  int _step = 0;
  static const _stepKeys = ['stepInfo', 'stepTracks', 'stepParticipants', 'stepReview', 'stepSubmit'];

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => appState.goBack(),
              ),
              const SizedBox(width: 8),
              Text(widget.release.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 24),
          _StepProgress(current: _step, stepKeys: _stepKeys, onStepTap: (i) => setState(() => _step = i)),
          const SizedBox(height: 32),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(key: ValueKey(_step), child: _buildStepContent(appState)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(AppState appState) {
    switch (_step) {
      case 0:
        return _StepInfo(release: widget.release, onNext: () => setState(() => _step = 1));
      case 1:
        return _StepTracks(
          onNext: () => setState(() => _step = 2),
          onPrev: () => setState(() => _step = 0),
        );
      case 2:
        return _StepParticipants(
          onNext: () => setState(() => _step = 3),
          onPrev: () => setState(() => _step = 1),
        );
      case 3:
        return _StepReview(
          release: widget.release,
          onNext: () => setState(() => _step = 4),
          onPrev: () => setState(() => _step = 2),
        );
      case 4:
        return _StepSubmit(
          release: widget.release,
          onPrev: () => setState(() => _step = 3),
          onSubmit: () {
            if (appState.canSubmitRelease) {
              appState.goBack();
            } else {
              appState.navigateTo(AppScreen.subscription);
            }
          },
          canSubmit: appState.canSubmitRelease,
        );
      default:
        return const SizedBox();
    }
  }
}

class _StepProgress extends StatelessWidget {
  final int current;
  final List<String> stepKeys;
  final ValueChanged<int>? onStepTap;

  const _StepProgress({required this.current, required this.stepKeys, this.onStepTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(stepKeys.length, (i) {
        final active = i == current;
        final past = i < current;
        return Expanded(
          child: Column(
            children: [
              GestureDetector(
                onTap: onStepTap != null ? () => onStepTap!(i) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  margin: EdgeInsets.only(right: i < stepKeys.length - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: active || past ? AurixTokens.orange : AurixTokens.glass(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                L10n.t(context, stepKeys[i]),
                style: TextStyle(
                  color: active ? AurixTokens.text : AurixTokens.muted,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _StepInfo extends StatelessWidget {
  final ReleaseModel release;
  final VoidCallback onNext;

  const _StepInfo({required this.release, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final statusLabel = releaseStatusFromString(release.status).label;
    final dateStr = release.releaseDate != null
        ? '${release.releaseDate!.day}.${release.releaseDate!.month}.${release.releaseDate!.year}'
        : '—';
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Статус', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(statusLabel, style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Text('Дата релиза', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(dateStr, style: TextStyle(color: AurixTokens.muted)),
          const SizedBox(height: 20),
          Text('Прогресс заполнения', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: 0.4,
            backgroundColor: AurixTokens.glass(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(AurixTokens.orange),
          ),
          const SizedBox(height: 4),
          Text('40%', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AurixButton(text: L10n.t(context, 'next'), onPressed: onNext, icon: Icons.arrow_forward_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepTracks extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _StepTracks({required this.onNext, required this.onPrev});

  @override
  Widget build(BuildContext context) {
    final mockTracks = ['Track 1 (Original)', 'Track 2 (Instrumental)'];
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(L10n.t(context, 'stepTracks'), style: Theme.of(context).textTheme.titleLarge),
              TextButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mock: Add track'))),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add track'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...mockTracks.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.drag_handle, color: AurixTokens.muted),
                    const SizedBox(width: 12),
                    Icon(Icons.music_note, color: AurixTokens.orange),
                    const SizedBox(width: 12),
                    Expanded(child: Text(t, style: TextStyle(color: AurixTokens.text))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AurixTokens.glass(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text('3:45', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: onPrev, child: Text(L10n.t(context, 'back'))),
              AurixButton(text: L10n.t(context, 'next'), onPressed: onNext, icon: Icons.arrow_forward_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepParticipants extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _StepParticipants({required this.onNext, required this.onPrev});

  @override
  Widget build(BuildContext context) {
    final mockSplits = [('Artist A', 60), ('Producer B', 40)];
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(L10n.t(context, 'stepParticipants'), style: Theme.of(context).textTheme.titleLarge),
              TextButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mock: Add participant'))),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...mockSplits.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(s.$1)),
                    Text('${s.$2}%', style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle, size: 18, color: Colors.green),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          Text('Total: 100%', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: onPrev, child: Text(L10n.t(context, 'back'))),
              AurixButton(text: L10n.t(context, 'next'), onPressed: onNext, icon: Icons.arrow_forward_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepReview extends StatelessWidget {
  final ReleaseModel release;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _StepReview({required this.release, required this.onNext, required this.onPrev});

  @override
  Widget build(BuildContext context) {
    final errors = ['Обложка не загружена', 'ISRC нужен для Track 2'];
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(L10n.t(context, 'stepReview'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          if (errors.isNotEmpty) ...[
            Text('Ошибки для исправления', style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...errors.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: AurixTokens.orange),
                      const SizedBox(width: 8),
                      Text(e, style: TextStyle(color: AurixTokens.text)),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
          ],
          Text('Обязательные поля: ${errors.isEmpty ? "OK" : "Исправьте выше"}', style: TextStyle(color: errors.isEmpty ? Colors.green : AurixTokens.muted, fontSize: 13)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: onPrev, child: Text(L10n.t(context, 'back'))),
              AurixButton(text: L10n.t(context, 'next'), onPressed: onNext, icon: Icons.arrow_forward_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepSubmit extends StatelessWidget {
  final ReleaseModel release;
  final VoidCallback onPrev;
  final VoidCallback onSubmit;
  final bool canSubmit;

  const _StepSubmit({required this.release, required this.onPrev, required this.onSubmit, required this.canSubmit});

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(L10n.t(context, 'stepSubmit'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Text('Готовы отправить релиз на проверку?', style: TextStyle(color: AurixTokens.muted)),
          if (!canSubmit) ...[
            const SizedBox(height: 16),
            Text('Требуется подписка для отправки', style: TextStyle(color: AurixTokens.orange, fontSize: 14)),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: onPrev, child: Text(L10n.t(context, 'back'))),
              AurixButton(
                text: canSubmit ? 'Submit' : L10n.t(context, 'viewPlans'),
                onPressed: onSubmit,
                icon: Icons.send_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
