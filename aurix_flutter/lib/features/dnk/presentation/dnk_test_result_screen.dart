import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../data/dnk_tests_models.dart';

class DnkTestResultScreen extends StatelessWidget {
  final DnkTestResult result;

  const DnkTestResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1,
        iconTheme: const IconThemeData(color: AurixTokens.textSecondary),
        title: Text(_titleBySlug(result.testSlug), style: const TextStyle(color: AurixTokens.text)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card(
            title: 'Краткий вывод',
            child: Text(
              result.summary,
              style: const TextStyle(color: AurixTokens.text, fontSize: 15, height: 1.45),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: 'Оси теста',
            child: Column(
              children: result.scoreAxes.entries.map((e) {
                final v = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _axisLabel(e.key),
                          style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 13),
                        ),
                      ),
                      Text(
                        v.toStringAsFixed(0),
                        style: const TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: LinearProgressIndicator(
                          value: (v / 100).clamp(0, 1),
                          minHeight: 6,
                          color: AurixTokens.accent,
                          backgroundColor: AurixTokens.border,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _card(title: 'Сильные стороны', child: _bullets(result.strengths)),
          const SizedBox(height: 12),
          _card(title: 'Риски', child: _bullets(result.risks)),
          const SizedBox(height: 12),
          ..._specificSections(),
          if (_specificSections().isNotEmpty) const SizedBox(height: 12),
          _card(title: 'План на 7 дней', child: _numbered(result.actions7Days)),
          const SizedBox(height: 12),
          _card(
            title: 'DNK → Контент-план автосвязка',
            child: const Text(
              'Этот результат можно использовать для автозаполнения в инструменте "Контент-план Reels/Shorts".',
              style: TextStyle(
                color: AurixTokens.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_mainContentPrompts().isNotEmpty) ...[
            _card(
              title: 'Готовые идеи для контента',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Это готовые заготовки для Reels, сторис, постов и подписи к релизу. '
                    'Выбери 1-2 пункта и используй в Studio AI или сразу в своём контенте.',
                    style: TextStyle(
                      color: AurixTokens.muted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _bullets(_mainContentPrompts()),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _bullets(List<String> items) {
    if (items.isEmpty) {
      return const Text('Нет данных', style: TextStyle(color: AurixTokens.muted));
    }
    return Column(
      children: items.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(color: AurixTokens.textSecondary)),
              Expanded(child: Text(s, style: const TextStyle(color: AurixTokens.textSecondary, height: 1.4))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _numbered(List<String> items) {
    if (items.isEmpty) {
      return const Text('Нет данных', style: TextStyle(color: AurixTokens.muted));
    }
    return Column(
      children: items.asMap().entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AurixTokens.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text('${e.key + 1}', style: const TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(e.value, style: const TextStyle(color: AurixTokens.textSecondary, height: 1.4))),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _titleBySlug(String slug) {
    switch (slug) {
      case 'artist_archetype':
        return 'Результат: Архетип артиста';
      case 'tone_communication':
        return 'Результат: Тон коммуникации';
      case 'story_core':
        return 'Результат: Сюжетное ядро';
      case 'growth_profile':
        return 'Результат: Профиль роста';
      case 'discipline_index':
        return 'Результат: Индекс дисциплины';
      case 'career_risk':
        return 'Результат: Риск-профиль карьеры';
      default:
        return 'Результат теста';
    }
  }

  String _axisLabel(String axis) {
    const labels = <String, String>{
      // artist_archetype
      'stage_power': 'Сценическая сила',
      'vulnerability': 'Уязвимость',
      'novelty_drive': 'Тяга к новизне',
      'cohesion': 'Цельность образа',

      // tone_communication
      'directness': 'Прямота',
      'warmth': 'Теплота',
      'provocation': 'Провокативность',
      'clarity': 'Ясность',

      // story_core
      'inner_conflict': 'Внутренний конфликт',
      'narrative_depth': 'Глубина сюжета',
      'emotional_range': 'Эмоциональный диапазон',
      'resolution_style': 'Стиль развязки',

      // growth_profile
      'community_bias': 'Опора на комьюнити',
      'viral_bias': 'Вирусный потенциал',
      'playlist_bias': 'Фокус на плейлистах',
      'live_bias': 'Фокус на лайвах',

      // discipline_index
      'planning': 'Планирование',
      'execution': 'Исполнение',
      'recovery': 'Восстановление ритма',
      'focus_protection': 'Защита фокуса',

      // career_risk
      'avoidance': 'Избегание',
      'impulsivity': 'Импульсивность',
      'dependency': 'Зависимость от внешнего',
      'identity_rigidity': 'Жесткость идентичности',
    };
    final mapped = labels[axis];
    if (mapped != null) return mapped;
    return axis
        .replaceAll('_', ' ')
        .replaceFirstMapped(RegExp(r'^[a-zа-я]'), (m) => m.group(0)!.toUpperCase());
  }

  List<Widget> _specificSections() {
    switch (result.testSlug) {
      case 'artist_archetype':
        return [
          _card(
            title: 'Архетип и сценическая роль',
            child: _bullets(result.strengths.take(3).toList()),
          ),
        ];
      case 'tone_communication':
        return [
          _card(
            title: 'Правила формулировок',
            child: _numbered(result.actions7Days.take(5).toList()),
          ),
          const SizedBox(height: 12),
          _card(
            title: 'Готовые фразы',
            child: _bullets(result.contentPrompts.take(10).toList()),
          ),
        ];
      case 'story_core':
        return [
          _card(
            title: 'Линии сюжетов',
            child: _bullets(result.contentPrompts.take(5).toList()),
          ),
        ];
      case 'growth_profile':
        return [
          _card(
            title: '30-дневный вектор',
            child: _numbered(result.actions7Days),
          ),
        ];
      case 'discipline_index':
        return [
          _card(
            title: 'Регламент без срывов',
            child: _numbered(result.actions7Days.take(4).toList()),
          ),
        ];
      case 'career_risk':
        return [
          _card(
            title: 'Сценарии самосаботажа',
            child: _bullets(result.risks.take(3).toList()),
          ),
        ];
      default:
        return const [];
    }
  }

  List<String> _mainContentPrompts() {
    switch (result.testSlug) {
      case 'tone_communication':
        // Для "Тон коммуникации" уже есть отдельный блок "Готовые фразы".
        return const [];
      case 'story_core':
        // В отдельном блоке показаны первые 5 сюжетных линий.
        return result.contentPrompts.skip(5).toList();
      default:
        return result.contentPrompts;
    }
  }
}
