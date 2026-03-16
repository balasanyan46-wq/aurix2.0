class AdminLogModel {
  final String id;
  final String? adminId;
  final String action;
  final String targetType;
  final String? targetId;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const AdminLogModel({
    required this.id,
    this.adminId,
    required this.action,
    required this.targetType,
    this.targetId,
    this.details = const {},
    required this.createdAt,
  });

  factory AdminLogModel.fromJson(Map<String, dynamic> json) {
    return AdminLogModel(
      id: (json['id'])?.toString() ?? '',
      adminId: json['admin_id']?.toString(),
      action: json['action']?.toString() ?? '',
      targetType: json['target_type']?.toString() ?? '',
      targetId: json['target_id']?.toString(),
      details: (json['details'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  String get actionLabel => switch (action) {
        'release_status_changed' => 'Статус релиза изменён',
        'user_role_changed' => 'Роль пользователя изменена',
        'user_plan_changed' => 'План пользователя изменён',
        'user_suspended' => 'Пользователь заблокирован',
        'user_activated' => 'Пользователь разблокирован',
        'ticket_replied' => 'Ответ на тикет',
        'ticket_closed' => 'Тикет закрыт',
        'report_imported' => 'Отчёт импортирован',
        _ => action,
      };
}
