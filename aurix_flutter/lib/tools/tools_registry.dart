import 'dart:convert';

enum ToolId { growthMap, budgetManager, releasePackaging, reelsShortsPlan, playlistPitch }

class ToolDefinition {
  final ToolId id;
  final String title;
  final String subtitle;
  final String Function(Map<String, dynamic> formData) buildMessage;
  final List<String> quickPrompts;

  const ToolDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.buildMessage,
    required this.quickPrompts,
  });
}

String _baseInstruction(String title) => '''
Ты — Aurix Studio AI. Работаешь как практик музыкального маркетинга и продюсер.

Контекст инструмента: $title.

Правила ответа (строго):
Пиши строго markdown-секциями (используй только заголовки `##` и `###`).

Формат (строго):
## Коротко
3–5 строк: что делать и зачем (без воды).

## Что делать сейчас (первые 60 минут)
Список шагов 1–7, максимально конкретно.

## План на 7 дней
План по дням/блокам: приоритет, время, ожидаемый эффект.

## Чек-лист
- буллеты

## Риски → как снизить
Таблично/парами: риск — мера.

## KPI / как измерять
Если уместно — числа/диапазоны и как измерять.

Пиши по-русски, без воды, максимально конкретно под артиста и релиз.
'''.trim();

String _withJson(Map<String, dynamic> formData, String instruction) {
  final jsonStr = const JsonEncoder.withIndent('  ').convert(formData);
  return '$instruction\n\nВходные данные (JSON):\n$jsonStr';
}

final Map<ToolId, ToolDefinition> toolsRegistry = {
  ToolId.growthMap: ToolDefinition(
    id: ToolId.growthMap,
    title: 'Карта роста релиза',
    subtitle: '30-дневный план продвижения: шаги, чек-листы, KPI и риски',
    quickPrompts: const [
      'План на 30 дней до/после релиза',
      'Упор на плейлисты и алгоритмы',
      'Упор на Reels/Shorts и рост подписчиков',
    ],
    buildMessage: (formData) => _withJson(
      formData,
      '${_baseInstruction('Карта роста релиза')}\n'
          'Составь 30-дневную карту роста: что делать по дням/неделям, что подготовить заранее, какие каналы использовать.',
    ),
  ),
  ToolId.budgetManager: ToolDefinition(
    id: ToolId.budgetManager,
    title: 'Бюджет-менеджер',
    subtitle: 'Распределение бюджета и анти-слив стратегия',
    quickPrompts: const [
      'Распредели бюджет максимально эффективно',
      'Вариант “минимум затрат”',
      'Вариант “агрессивный рост”',
    ],
    buildMessage: (formData) => _withJson(
      formData,
      '${_baseInstruction('Бюджет-менеджер')}\n'
          'Дай бюджет-план: категории, суммы, проценты, что даст каждый расход, и что НЕ делать.',
    ),
  ),
  ToolId.releasePackaging: ToolDefinition(
    id: ToolId.releasePackaging,
    title: 'AI-Упаковка релиза',
    subtitle: 'Описания, хуки, CTA и сторителлинг',
    quickPrompts: const [
      'Упор на сторителлинг',
      'Более дерзко/провокационно',
      'Минималистично и “дорого”',
    ],
    buildMessage: (formData) => _withJson(
      formData,
      '${_baseInstruction('AI-Упаковка релиза')}\n'
          'Сгенерируй упаковку: краткий хук, описания для платформ, варианты CTA, список хуков для видео.',
    ),
  ),
  ToolId.reelsShortsPlan: ToolDefinition(
    id: ToolId.reelsShortsPlan,
    title: 'Контент-план Reels/Shorts',
    subtitle: '14 дней контента: сценарии, хуки, CTA и метрики',
    quickPrompts: const [
      '14 дней: 1 видео в день',
      'Упор на вирусные хуки',
      'Упор на конверсию в стримы',
    ],
    buildMessage: (formData) => _withJson(
      formData,
      '${_baseInstruction('Контент-план Reels/Shorts')}\n'
          'Сделай контент-план (14 дней): форматы, хуки, сценарии, шотлисты, CTA и что измерять.',
    ),
  ),
  ToolId.playlistPitch: ToolDefinition(
    id: ToolId.playlistPitch,
    title: 'Плейлист-питч пакет',
    subtitle: 'Short pitch (EN), long pitch (RU), темы писем и био артиста',
    quickPrompts: const [
      'Питч для международных кураторов (EN коротко)',
      'Питч для СНГ-кураторов (RU подробно)',
      'Письмо для журналистов/блогеров',
    ],
    buildMessage: (formData) => _withJson(
      formData,
      '${_baseInstruction('Плейлист-питч пакет')}\n'
          'Собери питч-пакет: short pitch (EN), long pitch (RU), темы писем, пресс-строки и био артиста.',
    ),
  ),
};

