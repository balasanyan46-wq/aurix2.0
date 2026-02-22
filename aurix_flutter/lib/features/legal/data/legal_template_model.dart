/// Категория шаблона юридического документа.
enum LegalCategory {
  all,
  distribution,
  team,
  production,
  nda,
}

extension LegalCategoryX on LegalCategory {
  String get label {
    switch (this) {
      case LegalCategory.all:
        return 'Все';
      case LegalCategory.distribution:
        return 'Дистрибуция';
      case LegalCategory.team:
        return 'Команда';
      case LegalCategory.production:
        return 'Продакшн';
      case LegalCategory.nda:
        return 'NDA';
    }
  }

  static LegalCategory fromString(String? s) {
    if (s == null || s.isEmpty) return LegalCategory.all;
    switch (s.toLowerCase()) {
      case 'distribution':
        return LegalCategory.distribution;
      case 'team':
        return LegalCategory.team;
      case 'production':
        return LegalCategory.production;
      case 'nda':
        return LegalCategory.nda;
      default:
        return LegalCategory.all;
    }
  }
}

/// Шаблон из public.legal_templates (Supabase).
class LegalTemplateModel {
  const LegalTemplateModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.body,
    this.schema,
    this.version,
  });

  final String id;
  final String title;
  final String description;
  final LegalCategory category;
  final String body;
  final List<String>? schema;
  final int? version;

  /// Поля для формы: schema из БД или плейсхолдеры из body.
  List<String> get formKeys {
    if (schema != null && schema!.isNotEmpty) return schema!;
    final regex = RegExp(r'\{\{([A-Z_0-9]+)\}\}');
    return regex.allMatches(body).map((m) => m.group(1)!).toSet().toList();
  }

  factory LegalTemplateModel.fromJson(Map<String, dynamic> json) {
    List<String>? schemaList;
    final schemaRaw = json['schema'];
    if (schemaRaw is List) {
      schemaList = schemaRaw.map((e) => e.toString()).toList();
    }
    return LegalTemplateModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: LegalCategoryX.fromString(json['category'] as String?),
      body: json['body'] as String? ?? '',
      schema: schemaList,
      version: json['version'] as int?,
    );
  }
}
