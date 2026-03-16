import 'package:aurix_flutter/presentation/screens/studio/tools/tool_configs/tool_config_base.dart';
import 'package:flutter/material.dart';

const StudioToolConfig budgetToolConfig = StudioToolConfig(
  toolId: 'budget-plan',
  backendToolKey: 'budget-plan',
  title: 'Бюджет-менеджер',
  subtitle: 'Умное распределение бюджета и анти-слив сценарии.',
  icon: Icons.account_balance_wallet_rounded,
  accent: Color(0xFFFF6B35),
  defaultAnswers: {
    'budgetSize': 30000,
    'currency': 'RUB',
    'releaseGoal': 'streams',
    'artistStage': 'emerging',
    'teamReady': false,
  },
  questions: [
    ToolQuestion(
      id: 'budgetSize',
      title: 'Общий бюджет релиза',
      hint: 'AI построит low/standard/aggressive планы.',
      example: '30000',
      required: true,
      type: ToolQuestionType.number,
    ),
    ToolQuestion(
      id: 'currency',
      title: 'Валюта',
      hint: 'Для корректной финансовой выдачи.',
      example: 'RUB',
      required: true,
      type: ToolQuestionType.single,
      options: [
        ToolQuestionOption(id: 'RUB', label: 'RUB'),
        ToolQuestionOption(id: 'AMD', label: 'AMD'),
        ToolQuestionOption(id: 'USD', label: 'USD'),
      ],
    ),
    ToolQuestion(
      id: 'releaseGoal',
      title: 'Финальная цель',
      hint: 'Определяет главные статьи бюджета.',
      example: 'Стримы',
      required: true,
      type: ToolQuestionType.single,
      options: [
        ToolQuestionOption(id: 'streams', label: 'Стримы'),
        ToolQuestionOption(id: 'followers', label: 'Подписчики'),
        ToolQuestionOption(id: 'brand', label: 'Бренд'),
        ToolQuestionOption(id: 'press', label: 'Пресса'),
      ],
    ),
    ToolQuestion(
      id: 'teamReady',
      title: 'Есть команда?',
      hint: 'AI учитывает, что нужно аутсорсить.',
      example: 'Да',
      required: true,
      type: ToolQuestionType.boolean,
    ),
    ToolQuestion(
      id: 'prioritySpend',
      title: 'Где хотите сделать акцент?',
      hint: 'Помогает приоритизировать расход.',
      example: 'Контент и посевы в блогах.',
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
  final budget = answers['budgetSize']?.toString() ?? '0';
  final currency = answers['currency']?.toString() ?? 'RUB';
  return {
    'goal': answers['releaseGoal']?.toString() ?? 'streams',
    'constraints': (answers['teamReady'] == true) ? 'Команда есть, можно ускорять execution.' : 'Часть задач потребует внешних ресурсов.',
    'strengths': 'Есть бюджет: $budget $currency',
    'platforms': context.platformPriorities.join(', '),
    'region': context.language.isNotEmpty ? context.language : 'RU',
    'resources': 'Бюджет + ${answers['teamReady'] == true ? "команда" : "ограниченная команда"}',
    'missing': (answers['prioritySpend']?.toString().trim().isEmpty ?? true) ? 'Не задан приоритет расходов' : 'Критичных пробелов нет',
  };
}

Map<String, dynamic> _buildPayload({
  required StudioToolContext context,
  required Map<String, dynamic> answers,
  required String aiSummary,
  required String locale,
}) {
  return {
    'tool_id': 'budget-plan',
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
  'tool_specific': {'allocation': ['object'], 'anti_waste': ['string'], 'fallback': ['string']},
  'assets': {'tables': ['string']},
  'quality_meta': {'confidence_0_1': 0.8, 'missing_inputs': ['string'], 'assumptions': ['string']},
};
