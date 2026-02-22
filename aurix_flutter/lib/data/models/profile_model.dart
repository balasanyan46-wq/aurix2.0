class ProfileModel {
  final String userId;
  final String? name;
  final String? city;
  final String? phone;
  final String? gender;
  final String? bio;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Backward compatibility
  final String email;
  final String? displayName;
  final String? artistName;
  final String role;
  final String accountStatus;
  final String plan;

  const ProfileModel({
    required this.userId,
    this.name,
    this.city,
    this.phone,
    this.gender,
    this.bio,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.email = '',
    this.displayName,
    this.artistName,
    this.role = 'artist',
    this.accountStatus = 'active',
    this.plan = 'base',
  });

  String get id => userId;

  bool get hasStudioAccess => plan == 'pro' || plan == 'studio';
  bool get isAdmin => role == 'admin';
  bool get isActive => accountStatus == 'active';

  String get displayNameOrName => name ?? displayName ?? artistName ?? email;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ProfileModel(
      userId: (json['id'] ?? json['user_id']) as String? ?? '',
      name: json['name'] as String?,
      city: json['city'] as String?,
      phone: json['phone'] as String?,
      gender: json['gender'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : now,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : now,
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      artistName: json['artist_name'] as String?,
      role: json['role'] as String? ?? 'artist',
      accountStatus: json['account_status'] as String? ?? 'active',
      plan: json['plan'] as String? ?? 'base',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': userId,
        'name': name,
        'city': city,
        'phone': phone,
        'gender': gender,
        'bio': bio,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'email': email,
        'display_name': displayName,
        'artist_name': artistName,
        'role': role,
        'account_status': accountStatus,
        'plan': plan,
      };

  ProfileModel copyWith({
    String? name,
    String? city,
    String? phone,
    String? gender,
    String? bio,
    String? avatarUrl,
    String? displayName,
    String? artistName,
  }) {
    return ProfileModel(
      userId: userId,
      name: name ?? this.name,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      email: email,
      displayName: displayName ?? this.displayName,
      artistName: artistName ?? this.artistName,
      role: role,
      accountStatus: accountStatus,
      plan: plan,
    );
  }
}
