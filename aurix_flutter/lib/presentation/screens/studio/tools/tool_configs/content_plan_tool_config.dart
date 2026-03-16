import 'package:aurix_flutter/presentation/screens/studio/tools/tool_configs/tool_config_base.dart';
import 'package:flutter/material.dart';

const StudioToolConfig contentPlanToolConfig = StudioToolConfig(
  toolId: 'content-plan-14',
  backendToolKey: 'content-plan-14',
  title: 'Контент-план Reels/Shorts',
  subtitle: 'Контент-угол, pillar-сценарии и план роликов под релиз.',
  icon: Icons.video_library_rounded,
  accent: Color(0xFFEC4899),
  defaultAnswers: {
    'releaseGoal': 'streams',
    'platforms': <String>['instagram', 'youtube', 'tiktok'],
    'hasFaceInFrame': true,
    'editingSkill': 'basic',
  },
  questions: [
    ToolQuestion(
      id: 'releaseGoal',
      title: 'Какая цель контента?',
      hint: 'Определяет CTA и формат роликов.',
      example: 'Рост стриминга в первые 2 недели.',
      required: true,
      type: ToolQuestionType.single,
      options: [
        ToolQuestionOption(id: 'streams', label: 'Стриминг'),
        ToolQuestionOption(id: 'followers', label: 'Подписчики'),
        ToolQuestionOption(id: 'brand', label: 'Имидж'),
      ],
    ),
    ToolQuestion(
      id: 'aboutTrack',
      title: 'Настроение релиза',
      hint: 'Нужно для сценариев, а не абстрактных идей.',
      example: 'Ночной меланхоличный вайб, тема одиночества.',
      required: true,
      type: ToolQuestionType.text,
    ),
    ToolQuestion(
      id: 'hasFaceInFrame',
      title: 'Артист готов сниматься лицом?',
      hint: 'Меняет форматы: личные ролики или абстрактные.',
      example: 'Да',
      required: true,
      type: ToolQuestionType.boolean,
    ),
    ToolQuestion(
      id: 'editingSkill',
      title: 'Уровень монтажа',
      hint: 'Определяет сложность исполнения.',
      example: 'basic',
      required: true,
      type: ToolQuestionType.single,
      options: [
        ToolQuestionOption(id: 'low', label: 'Минимальный'),
        ToolQuestionOption(id: 'basic', label: 'Базовый'),
        ToolQuestionOption(id: 'pro', label: 'Продвинутый'),
      ],
    ),
    ToolQuestion(
      id: 'platforms',
      title: 'Где публикуете?',
      hint: 'Нужны платформо-специфичные идеи.',
      example: 'Reels + Shorts',
      required: true,
      type: ToolQuestionType.multi,
      options: [
        ToolQuestionOption(id: 'instagram', label: 'Reels'),
        ToolQuestionOption(id: 'youtube', label: 'Shorts'),
        ToolQuestionOption(id: 'tiktok', label: 'TikTok'),
        ToolQuestionOption(id: 'vk', label: 'VK Clips'),
      ],
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
    'goal': answers['releaseGoal']?.toString() ?? 'streams',
    'constraints': (answers['hasFaceInFrame'] == true) ? 'Можно делать личные форматы.' : 'Фокус на безлицевом визуале.',
    'strengths': answers['aboutTrack']?.toString() ?? 'Базовый контекст релиза',
    'platforms': (answers['platforms'] as List?)?.join(', ') ?? context.platformPriorities.join(', '),
    'region': context.language,
    'resources': 'Монтаж: ${answers['editingSkill'] ?? "basic"}',
    'missing': (answers['aboutTrack']?.toString().trim().isEmpty ?? true) ? 'Не задан mood релиза' : 'Критичных пробелов нет',
  };
}

Map<String, dynamic> _buildPayload({
  required StudioToolContext context,
  required Map<String, dynamic> answers,
  required String aiSummary,
  required String locale,
}) {
  return {
    'tool_id': 'content-plan-14',
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
  'tool_specific': {'pillars': ['string'], 'videos': ['object'], 'timing': ['string']},
  'assets': {'hooks': ['string'], 'captions': ['string'], 'cta': ['string']},
  'quality_meta': {'confidence_0_1': 0.8, 'missing_inputs': ['string'], 'assumptions': ['string']},
};
