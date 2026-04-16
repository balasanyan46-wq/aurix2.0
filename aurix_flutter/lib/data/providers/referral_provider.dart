import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/api_client.dart';

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}

final referralStatsProvider = FutureProvider<ReferralStats>((ref) async {
  final res = await ApiClient.get('/referral/stats');
  final body = _asMap(res.data);
  return ReferralStats.fromJson(body);
});

class ReferralStats {
  final String code;
  final String referralLink;
  final int referralsCount;
  final List<ReferralUser> referrals;
  final int totalEarned;
  final int totalRewards;
  final int currentBalance;
  final List<ReferralReward> recentRewards;

  ReferralStats({
    required this.code,
    required this.referralLink,
    required this.referralsCount,
    required this.referrals,
    required this.totalEarned,
    required this.totalRewards,
    required this.currentBalance,
    required this.recentRewards,
  });

  static int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    return ReferralStats(
      code: (json['code'] ?? '').toString(),
      referralLink: (json['referral_link'] ?? '').toString(),
      referralsCount: _toInt(json['referrals_count']),
      referrals: ((json['referrals'] as List?) ?? [])
          .map((e) => ReferralUser.fromJson(_asMap(e)))
          .toList(),
      totalEarned: _toInt(json['total_earned']),
      totalRewards: _toInt(json['total_rewards']),
      currentBalance: _toInt(json['current_balance']),
      recentRewards: ((json['recent_rewards'] as List?) ?? [])
          .map((e) => ReferralReward.fromJson(_asMap(e)))
          .toList(),
    );
  }
}

class ReferralUser {
  final int id;
  final String name;
  final DateTime joinedAt;

  ReferralUser({required this.id, required this.name, required this.joinedAt});

  factory ReferralUser.fromJson(Map<String, dynamic> json) {
    return ReferralUser(
      id: ReferralStats._toInt(json['id']),
      name: (json['name'] ?? 'Аноним').toString(),
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ReferralReward {
  final int amount;
  final String type;
  final DateTime date;
  final String fromName;

  ReferralReward({required this.amount, required this.type, required this.date, required this.fromName});

  factory ReferralReward.fromJson(Map<String, dynamic> json) {
    return ReferralReward(
      amount: ReferralStats._toInt(json['amount']),
      type: (json['type'] ?? '').toString(),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      fromName: (json['from_name'] ?? 'Аноним').toString(),
    );
  }
}
