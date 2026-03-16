import 'package:aurix_flutter/presentation/screens/studio/tools/tool_configs/tool_config_base.dart';
import 'package:flutter/material.dart';

const StudioToolConfig packagingToolConfig = StudioToolConfig(
  toolId: 'release-packaging',
  backendToolKey: 'release-packaging',
  title: 'AI-упаковка релиза',
  subtitle: 'Позиционирование, hook, storytelling и platform-ready тексты.',
  icon: Icons.auto_awesome_rounded,
  accent: Color(0xFF8B5CF6),
  defaultAnswers: {
    'tone': 'emotional',
    'platforms': <String>['yandex', 'vk', 'shorts'],
    'region': 'RU',
  },
  questions: [
    ToolQuestion(
      id: 'aboutTrack',
      title: 'В чем суть трека?',
      hint: 'Основа позиционирования и описаний.',
      example: 'Про боль расставания и возвращение к себе.',
      required: true,
      type: ToolQuestionType.text,
    ),
    ToolQuestion(
      id: 'mainHook',
      title: 'Ключевой hook',
      hint: 'Должен цеплять в 1-2 фразы.',
      example: 'Фраза, которую хочется процитировать.',
      required: true,
      type: ToolQuestionType.text,
    ),
    ToolQuestion(
      id: 'tone',
      title: 'Tone of voice',
      hint: 'Тон влияет на всю упаковку.',
      example: 'poetic',
      required: true,
      type: ToolQuestionType.single,
      options: [
        ToolQuestionOption(id: 'emotional', label: 'Эмоциональный'),
        ToolQuestionOption(id: 'poetic', label: 'Поэтичный'),
        ToolQuestionOption(id: 'minimalist', label: 'Минималистичный'),
        ToolQuestionOption(id: 'provocative', label: 'Провокационный'),
      ],
    ),
    ToolQuestion(
      id: 'platforms',
      title: 'Под какие платформы адаптируем?',
      hint: 'Нужны platform-specific варианты.',
      example: 'VK + Яндекс + Shorts',
      required: true,
      type: ToolQuestionType.multi,
      options: [
        ToolQuestionOption(id: 'yandex', label: 'Яндекс'),
        ToolQuestionOption(id: 'vk', label: 'VK'),
        ToolQuestionOption(id: 'shorts', label: 'Shorts'),
        ToolQuestionOption(id: 'instagram', label: 'Instagram'),
      ],
    ),
    ToolQuestion(
      id: 'references',
      title: 'Референсы (опционально)',
      hint: 'Позволяет удержать нужный образ.',
      example: 'Billie Eilish + Скриптонит по атмосфере.',
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
  return {
    'goal': 'Собрать сильную упаковку релиза',
    'constraints': 'Нужно удержать единый тон в разных каналах.',
    'strengths': answers['mainHook']?.toString() ?? 'Есть базовый контекст релиза',
    'platforms': (answers['platforms'] as List?)?.join(', ') ?? context.platformPriorities.join(', '),
    'region': answers['region']?.toString() ?? 'RU',
    'resources': 'Тексты + идеи для визуала и CTA',
    'missing': (answers['aboutTrack']?.toString().trim().isEmpty ?? true) ? 'Не описана суть трека' : 'Критичных пробелов нет',
  };
}

Map<String, dynamic> _buildPayload({
  required StudioToolContext context,
  required Map<String, dynamic> answers,
  required String aiSummary,
  required String locale,
}) {
  return {
    'tool_id': 'release-packaging',
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
  'tool_specific': {'positioning': ['string'], 'descriptions': ['string'], 'hooks': ['string']},
  'assets': {'cta': ['string'], 'captions': ['string'], 'visual_mood': ['string']},
  'quality_meta': {'confidence_0_1': 0.8, 'missing_inputs': ['string'], 'assumptions': ['string']},
};
