class TeamMemberModel {
  final String id;
  final String ownerId;
  final String memberName;
  final String? memberEmail;
  final String role;
  final double splitPercent;
  final String status;
  final DateTime createdAt;

  const TeamMemberModel({
    required this.id,
    required this.ownerId,
    required this.memberName,
    this.memberEmail,
    this.role = 'producer',
    this.splitPercent = 0,
    this.status = 'active',
    required this.createdAt,
  });

  String get roleLabel => switch (role) {
        'producer' => 'Продюсер',
        'manager' => 'Менеджер',
        'engineer' => 'Звукорежиссёр',
        'songwriter' => 'Автор',
        'designer' => 'Дизайнер',
        _ => 'Другое',
      };

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    return TeamMemberModel(
      id: (json['id'])?.toString() ?? '',
      ownerId: json['owner_id']?.toString() ?? '',
      memberName: json['member_name']?.toString() ?? '',
      memberEmail: json['member_email']?.toString(),
      role: json['role']?.toString() ?? 'producer',
      splitPercent: (json['split_percent'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'active',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'owner_id': ownerId,
        'member_name': memberName,
        'member_email': memberEmail,
        'role': role,
        'split_percent': splitPercent,
        'status': status,
      };
}
