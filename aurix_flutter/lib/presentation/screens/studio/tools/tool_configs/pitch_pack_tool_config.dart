import 'package:aurix_flutter/presentation/screens/studio/tools/tool_configs/tool_config_base.dart';
import 'package:flutter/material.dart';

const StudioToolConfig pitchPackToolConfig = StudioToolConfig(
  toolId: 'playlist-pitch-pack',
  backendToolKey: 'playlist-pitch-pack',
  title: 'Плейлист-питч пакет',
  subtitle: 'Pitch, email-пакет, press-note и risk notes.',
  icon: Icons.mail_rounded,
  accent: Color(0xFF0EA5E9),
  defaultAnswers: {
    'pitchTarget': 'playlists',
    'region': 'RU',
  },
  questions: [
    ToolQuestion(
      id: 'pitchTarget',
      title: 'Кому питчим в приоритете?',
      hint: 'Определяет формулировки и угол подачи.',
      example: 'Редакторы плейлистов.',
      required: true,
      type: ToolQuestionType.single,
      options: [
        ToolQuestionOption(id: 'playlists', label: 'Редакторы'),
        ToolQuestionOption(id: 'bloggers', label: 'Блогеры'),
        ToolQuestionOption(id: 'press', label: 'Пресса'),
      ],
    ),
    ToolQuestion(
      id: 'aboutTrack',
      title: 'Краткое описание релиза',
      hint: 'Ядро short/long pitch.',
      example: 'Интимный alt-pop трек с контрастным припевом.',
      required: true,
      type: ToolQuestionType.text,
    ),
    ToolQuestion(
      id: 'angleEditors',
      title: 'Angle для редакторов',
      hint: 'Почему релиз релевантен именно им.',
      example: 'Локальный артист с международным саундом.',
      required: true,
      type: ToolQuestionType.text,
    ),
    ToolQuestion(
      id: 'angleBloggers',
      title: 'Angle для блогеров',
      hint: 'Повышает шанс органического подхвата.',
      example: 'Цитируемый hook и личная история.',
      required: false,
      type: ToolQuestionType.text,
    ),
    ToolQuestion(
      id: 'achievements',
      title: 'Факты/достижения артиста',
      hint: 'Укрепляет доверие к питчу.',
      example: '100k streams, support от локальных медиа.',
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
    'goal': 'Собрать рабочий pitch pack',
    'constraints': 'Нужен сильный angle без воды.',
    'strengths': answers['angleEditors']?.toString() ?? 'Есть релизные метаданные',
    'platforms': context.platformPriorities.join(', '),
    'region': answers['region']?.toString() ?? 'RU',
    'resources': 'Pitch + email + press-note',
    'missing': (answers['aboutTrack']?.toString().trim().isEmpty ?? true) ? 'Не описан релиз' : 'Критичных пробелов нет',
  };
}

Map<String, dynamic> _buildPayload({
  required StudioToolContext context,
  required Map<String, dynamic> answers,
  required String aiSummary,
  required String locale,
}) {
  return {
    'tool_id': 'playlist-pitch-pack',
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
  'tool_specific': {'short_pitch': 'string', 'long_pitch': 'string', 'subjects': ['string']},
  'assets': {'email_bodies': ['string'], 'press_notes': ['string']},
  'quality_meta': {'confidence_0_1': 0.8, 'missing_inputs': ['string'], 'assumptions': ['string']},
};
