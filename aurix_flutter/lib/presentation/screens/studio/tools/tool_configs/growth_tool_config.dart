import 'package:aurix_flutter/presentation/screens/studio/tools/tool_configs/tool_config_base.dart';
import 'package:flutter/material.dart';

const StudioToolConfig growthToolConfig = StudioToolConfig(
  toolId: 'growth-plan',
  backendToolKey: 'growth-plan',
  title: 'Карта роста релиза',
  subtitle: 'Стратегия релиза, рычаги роста и маршрут на 30 дней.',
  icon: Icons.trending_up_rounded,
  accent: Color(0xFF22C55E),
  defaultAnswers: {
    'releaseGoal': 'streams',
    'artistStage': 'emerging',
    'resourcesLevel': 'medium',
    'region': 'RU',
    'platforms': <String>['yandex', 'vk', 'youtube'],
  },
  questions: [
    ToolQuestion(
      id: 'releaseGoal',
      title: 'Что главнее в этом релизе?',
      hint: 'Цель определяет структуру всей стратегии.',
      example: 'Стримы + узнаваемость среди новой аудитории.',
      required: true,
      type: ToolQuestionType.single,
      options: [
        ToolQuestionOption(id: 'streams', label: 'Стримы'),
        ToolQuestionOption(id: 'playlisting', label: 'Плейлисты'),
        ToolQuestionOption(id: 'followers', label: 'Подписчики'),
        ToolQuestionOption(id: 'brand', label: 'Бренд'),
      ],
    ),
    ToolQuestion(
      id: 'artistStage',
      title: 'Стадия артиста',
      hint: 'Нужна для реалистичного плана и KPI.',
      example: 'Растущий артист с ядром аудитории.',
      required: true,
      type: ToolQuestionType.single,
      options: [
        ToolQuestionOption(id: 'new', label: 'Новый'),
        ToolQuestionOption(id: 'emerging', label: 'Растущий'),
        ToolQuestionOption(id: 'established', label: 'Сформированный'),
      ],
    ),
    ToolQuestion(
      id: 'region',
      title: 'Приоритетный регион',
      hint: 'Влияет на платформы, форматы и коммуникацию.',
      example: 'Россия / СНГ.',
      required: true,
      type: ToolQuestionType.single,
      options: [
        ToolQuestionOption(id: 'RU', label: 'Россия'),
        ToolQuestionOption(id: 'CIS', label: 'СНГ'),
        ToolQuestionOption(id: 'AM', label: 'Армения'),
        ToolQuestionOption(id: 'GLOBAL', label: 'Глобально'),
      ],
    ),
    ToolQuestion(
      id: 'platforms',
      title: 'Где фокусируемся?',
      hint: 'AI распределит усилия по ключевым платформам.',
      example: 'Яндекс + VK + Shorts.',
      required: true,
      type: ToolQuestionType.multi,
      options: [
        ToolQuestionOption(id: 'yandex', label: 'Яндекс'),
        ToolQuestionOption(id: 'vk', label: 'VK'),
        ToolQuestionOption(id: 'spotify', label: 'Spotify'),
        ToolQuestionOption(id: 'youtube', label: 'YouTube'),
        ToolQuestionOption(id: 'instagram', label: 'Instagram'),
      ],
    ),
    ToolQuestion(
      id: 'strongSides',
      title: 'Сильные стороны релиза',
      hint: 'Это базовые рычаги роста, которые AI должен усилить.',
      example: 'Сильный припев, активная аудитория в VK.',
      required: false,
      type: ToolQuestionType.text,
    ),
  ],
  summaryFields: [
    ToolSummaryField(id: 'goal', title: 'Цель'),
    ToolSummaryField(id: 'constraints', title: 'Ограничения'),
    ToolSummaryField(id: 'strengths', title: 'Сильные стороны'),
    ToolSummaryField(id: 'platforms', title: 'Приоритетные платформы'),
    ToolSummaryField(id: 'region', title: 'Регион'),
    ToolSummaryField(id: 'resources', title: 'Ресурсы'),
    ToolSummaryField(id: 'missing', title: 'Чего не хватает'),
  ],
  buildSummaryDraft: _buildSummary,
  buildPayload: _buildPayload,
  outputSchema: _outputSchema,
);

Map<String, String> _buildSummary(StudioToolContext context, Map<String, dynamic> answers) {
  final platforms = (answers['platforms'] as List?)?.join(', ') ?? context.platformPriorities.join(', ');
  final constraints = (answers['resourcesLevel'] == 'low')
      ? 'Ограниченные ресурсы и аккуратный бюджет.'
      : 'Можно тестировать гипотезы и усиливать лучшие каналы.';
  final strengths = (answers['strongSides']?.toString().trim().isNotEmpty ?? false)
      ? answers['strongSides'].toString()
      : 'Жанр и базовый релизный контекст уже определены.';

  return {
    'goal': answers['releaseGoal']?.toString() ?? 'streams',
    'constraints': constraints,
    'strengths': strengths,
    'platforms': platforms,
    'region': answers['region']?.toString() ?? 'RU',
    'resources': answers['resourcesLevel']?.toString() ?? 'medium',
    'missing': context.coverUrl == null ? 'Нет обложки' : 'Критичных пробелов нет',
  };
}

Map<String, dynamic> _buildPayload({
  required StudioToolContext context,
  required Map<String, dynamic> answers,
  required String aiSummary,
  required String locale,
}) {
  return {
    'tool_id': 'growth-plan',
    'context': context.toJson(),
    'answers': answers,
    'ai_summary': aiSummary,
    'locale': locale,
    'output_format': 'json',
    'output_version': 'v1',
    'output_schema': _outputSchema,
  };
}

const Map<String, dynamic> _outputSchema = {
  'hero': {'title': 'string', 'subtitle': 'string', 'one_liner': 'string'},
  'summary': {'what_changed': 'string', 'why_it_matters': 'string', 'metrics': ['string']},
  'priorities': [
    {'title': 'string', 'why': 'string', 'effort': 'low|mid|high', 'impact': 'low|mid|high', 'steps': ['string']}
  ],
  'first_actions': [
    {'title': 'string', 'time_estimate_min': 30, 'steps': ['string']}
  ],
  'risks': [
    {'risk': 'string', 'signal': 'string', 'fix': 'string'}
  ],
  'alt_scenario': {'when_to_use': 'string', 'plan_short': ['string']},
  'tool_specific': {'strategy': 'string', 'levers': ['string'], 'timeline': ['string']},
  'assets': {'captions': ['string'], 'hooks': ['string']},
  'quality_meta': {'confidence_0_1': 0.8, 'missing_inputs': ['string'], 'assumptions': ['string']},
};
