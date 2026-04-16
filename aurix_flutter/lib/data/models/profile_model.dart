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
  final String planId;
  final String billingPeriod;
  final String subscriptionStatus;
  final DateTime? subscriptionEnd;

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
    this.plan = 'none',
    this.planId = 'none',
    this.billingPeriod = 'monthly',
    this.subscriptionStatus = 'none',
    this.subscriptionEnd,
  });

  String get id => userId;

  bool get hasStudioAccess => plan == 'breakthrough' || plan == 'empire';
  bool get isAdmin => role == 'admin';
  bool get isActive => accountStatus == 'active';

  String get displayNameOrName => name ?? displayName ?? artistName ?? email;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ProfileModel(
      userId: (json['user_id'] ?? json['id'])?.toString() ?? '',
      name: json['name']?.toString(),
      city: json['city']?.toString(),
      phone: json['phone']?.toString(),
      gender: json['gender']?.toString(),
      bio: json['bio']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      createdAt: json['created_at'] != null ? (DateTime.tryParse(json['created_at'].toString()) ?? now) : now,
      updatedAt: json['updated_at'] != null ? (DateTime.tryParse(json['updated_at'].toString()) ?? now) : now,
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString(),
      artistName: json['artist_name']?.toString(),
      role: json['role']?.toString() ?? 'artist',
      accountStatus: json['account_status']?.toString() ?? 'active',
      plan: _migratePlanSlug((json['plan_id'] ?? json['plan'])?.toString()),
      planId: _migratePlanSlug((json['plan_id'] ?? json['plan'])?.toString()),
      billingPeriod: json['billing_period']?.toString() ?? 'monthly',
      subscriptionStatus: json['subscription_status']?.toString() ?? 'none',
      subscriptionEnd: json['subscription_end'] != null
          ? DateTime.tryParse(json['subscription_end'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
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
        'plan_id': planId,
        'billing_period': billingPeriod,
        'subscription_status': subscriptionStatus,
        'subscription_end': subscriptionEnd?.toIso8601String(),
      };

  bool get isYearly => billingPeriod == 'yearly';

  ProfileModel copyWith({
    String? name,
    String? city,
    String? phone,
    String? gender,
    String? bio,
    String? avatarUrl,
    String? displayName,
    String? artistName,
    String? plan,
    String? planId,
    String? billingPeriod,
    String? subscriptionStatus,
    DateTime? subscriptionEnd,
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
      plan: plan ?? this.plan,
      planId: planId ?? this.planId,
      billingPeriod: billingPeriod ?? this.billingPeriod,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionEnd: subscriptionEnd ?? this.subscriptionEnd,
    );
  }
}

/// Normalize legacy DB values to new slugs (client-side safety net).
String _migratePlanSlug(String? raw) {
  switch (raw) {
    case 'start': case 'breakthrough': case 'empire': return raw!;
    case 'base': case 'basic': case 'BASE': return 'start';
    case 'pro': case 'PRO': return 'breakthrough';
    case 'studio': case 'STUDIO': return 'empire';
    case null: case '': case 'none': return 'none';
    default: return 'none';
  }
}
