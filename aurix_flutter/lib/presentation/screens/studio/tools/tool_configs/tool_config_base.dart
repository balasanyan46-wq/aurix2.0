import 'package:flutter/material.dart';

enum ToolQuestionType { single, multi, text, number, boolean }

class ToolQuestionOption {
  final String id;
  final String label;
  const ToolQuestionOption({required this.id, required this.label});
}

class ToolQuestion {
  final String id;
  final String title;
  final String hint;
  final String example;
  final bool required;
  final ToolQuestionType type;
  final List<ToolQuestionOption> options;
  final bool Function(Map<String, dynamic> answers)? isVisible;

  const ToolQuestion({
    required this.id,
    required this.title,
    required this.hint,
    required this.example,
    required this.required,
    required this.type,
    this.options = const [],
    this.isVisible,
  });
}

class ToolSummaryField {
  final String id;
  final String title;
  const ToolSummaryField({required this.id, required this.title});
}

class StudioToolContext {
  final String releaseId;
  final String title;
  final String artist;
  final String releaseType;
  final String? releaseDateIso;
  final String genre;
  final String language;
  final bool explicit;
  final String? coverUrl;
  final String? coverPath;
  final Map<String, dynamic> existingMetadata;
  final List<String> platformPriorities;
  final Map<String, dynamic> pastReleaseData;
  final List<dynamic> studioHistory;
  final Map<String, dynamic> profile;

  const StudioToolContext({
    required this.releaseId,
    required this.title,
    required this.artist,
    required this.releaseType,
    required this.releaseDateIso,
    required this.genre,
    required this.language,
    required this.explicit,
    required this.coverUrl,
    required this.coverPath,
    required this.existingMetadata,
    required this.platformPriorities,
    required this.pastReleaseData,
    required this.studioHistory,
    required this.profile,
  });

  Map<String, dynamic> toJson() {
    return {
      'release_id': releaseId,
      'title': title,
      'artist': artist,
      'release_type': releaseType,
      'release_date': releaseDateIso,
      'genre': genre,
      'language': language,
      'explicit': explicit,
      'cover_url': coverUrl,
      'cover_path': coverPath,
      'existing_metadata': existingMetadata,
      'platform_priorities': platformPriorities,
      'past_release_data': pastReleaseData,
      'studio_history': studioHistory,
      'profile': profile,
    };
  }
}

typedef BuildSummaryDraft = Map<String, String> Function(
  StudioToolContext context,
  Map<String, dynamic> answers,
);

typedef BuildToolPayload = Map<String, dynamic> Function({
  required StudioToolContext context,
  required Map<String, dynamic> answers,
  required String aiSummary,
  required String locale,
});

class StudioToolConfig {
  final String toolId;
  final String backendToolKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<ToolQuestion> questions;
  final List<ToolSummaryField> summaryFields;
  final Map<String, dynamic> defaultAnswers;
  final BuildSummaryDraft buildSummaryDraft;
  final BuildToolPayload buildPayload;
  final Map<String, dynamic> outputSchema;

  const StudioToolConfig({
    required this.toolId,
    required this.backendToolKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.questions,
    required this.summaryFields,
    required this.defaultAnswers,
    required this.buildSummaryDraft,
    required this.buildPayload,
    required this.outputSchema,
  });
}
