import 'dart:convert';

typedef ToolBuildMessage = String Function(Map<String, dynamic> formData);

class ToolConfig {
  final String title;
  final ToolBuildMessage buildMessage;
  final List<String> quickPrompts;

  const ToolConfig({
    required this.title,
    required this.buildMessage,
    required this.quickPrompts,
  });
}

const toolIdGrowthMap = 'growth_map';
const toolIdBudgetManager = 'budget_manager';
const toolIdReleasePackaging = 'release_packaging';
const toolIdReelsContentPlan = 'reels_content_plan';
const toolIdPlaylistPitch = 'playlist_pitch';

String _baseInstruction({
  required String toolTitle,
}) {
  return '''
Ты — Aurix Studio AI. Работаешь как практик музыкального маркетинга и продюсер.

Контекст инструмента: $toolTitle.

Правила ответа (строго):
1) Короткое резюме (3–5 строк)
2) Пошаговый план (структурированно, с таймингом/приоритетами)
3) Чек-лист (буллеты)
4) Риски и как снизить (конкретные меры)
5) KPI/метрики (если уместно — числа/диапазоны и как измерять)

Пиши по-русски, без воды, максимально конкретно под артиста и релиз.
'''.trim();
}

String _withJsonFormData(String prefix, Map<String, dynamic> formData) {
  final jsonStr = const JsonEncoder.withIndent('  ').convert(formData);
  return '$prefix\n\nВходные данные (JSON):\n$jsonStr';
}

final Map<String, ToolConfig> toolsRegistry = {
  toolIdGrowthMap: ToolConfig(
    title: 'Карта роста релиза',
    quickPrompts: const [
      'Сделай план на 30 дней до/после релиза',
      'Упор на плейлисты и алгоритмы',
      'Упор на TikTok/shorts и рост подписчиков',
    ],
    buildMessage: (formData) => _withJsonFormData(
      '${_baseInstruction(toolTitle: 'Карта роста релиза')}\n'
          'Составь 30-дневную карту роста: что делать по дням/неделям, что подготовить заранее, какие каналы использовать.',
      formData,
    ),
  ),

  toolIdBudgetManager: ToolConfig(
    title: 'Бюджет-менеджер',
    quickPrompts: const [
      'Распредели бюджет максимально эффективно',
      'Сделай “дёшево и сердито” (минимум затрат)',
      'Сделай вариант “агрессивный рост”',
    ],
    buildMessage: (formData) => _withJsonFormData(
      '${_baseInstruction(toolTitle: 'Бюджет-менеджер')}\n'
          'Дай бюджет-план: категории, суммы, проценты, что даст каждый расход, и что НЕ делать.',
      formData,
    ),
  ),

  toolIdReleasePackaging: ToolConfig(
    title: 'AI-Упаковка релиза',
    quickPrompts: const [
      'Сделай упор на сторителлинг',
      'Сделай более дерзко/провокационно',
      'Сделай минималистично и “дорого”',
    ],
    buildMessage: (formData) => _withJsonFormData(
      '${_baseInstruction(toolTitle: 'AI-Упаковка релиза')}\n'
          'Сгенерируй упаковку: краткий хук, описания для платформ, варианты CTA, список хуков для видео.',
      formData,
    ),
  ),

  toolIdReelsContentPlan: ToolConfig(
    title: 'Контент-план Reels/Shorts',
    quickPrompts: const [
      '14 дней контента: 1 видео в день',
      'Упор на вирусные хуки',
      'Упор на конверсию в стримы',
    ],
    buildMessage: (formData) => _withJsonFormData(
      '${_baseInstruction(toolTitle: 'Контент-план Reels/Shorts')}\n'
          'Сделай контент-план (14 дней): форматы, хуки, сценарии, шотлисты, CTA и что измерять.',
      formData,
    ),
  ),

  toolIdPlaylistPitch: ToolConfig(
    title: 'Плейлист-питч пакет',
    quickPrompts: const [
      'Сделай питч для международных кураторов (EN коротко)',
      'Сделай питч для СНГ-кураторов (RU подробно)',
      'Сделай письмо для журналистов/блогеров',
    ],
    buildMessage: (formData) => _withJsonFormData(
      '${_baseInstruction(toolTitle: 'Плейлист-питч пакет')}\n'
          'Собери питч-пакет: short pitch (EN), long pitch (RU), темы писем, пресс-строки и био артиста.',
      formData,
    ),
  ),
};

