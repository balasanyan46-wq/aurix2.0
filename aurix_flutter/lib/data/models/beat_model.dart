class BeatModel {
  final int id;
  final int sellerId;
  final String title;
  final String? description;
  final String? genre;
  final String? subGenre;
  final int? bpm;
  final String? key;
  final String? mood;
  final List<String> tags;
  final String audioUrl;
  final String? audioPath;
  final String? previewUrl;
  final String? coverUrl;
  final int? duration;
  final int priceLease;
  final int priceUnlimited;
  final int priceExclusive;
  final bool isFree;
  final String status;
  final bool isSoldExclusive;
  final int plays;
  final int purchases;
  final int likes;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Seller info (joined)
  final String? sellerName;
  // Current user state
  final bool? isLiked;

  const BeatModel({
    required this.id,
    required this.sellerId,
    required this.title,
    this.description,
    this.genre,
    this.subGenre,
    this.bpm,
    this.key,
    this.mood,
    this.tags = const [],
    required this.audioUrl,
    this.audioPath,
    this.previewUrl,
    this.coverUrl,
    this.duration,
    this.priceLease = 0,
    this.priceUnlimited = 0,
    this.priceExclusive = 0,
    this.isFree = false,
    this.status = 'active',
    this.isSoldExclusive = false,
    this.plays = 0,
    this.purchases = 0,
    this.likes = 0,
    required this.createdAt,
    required this.updatedAt,
    this.sellerName,
    this.isLiked,
  });

  static int _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return double.tryParse(v)?.toInt() ?? 0;
    return 0;
  }

  factory BeatModel.fromJson(Map<String, dynamic> json) {
    DateTime _parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    List<String> _parseTags(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return BeatModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sellerId: (json['seller_id'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      genre: json['genre']?.toString(),
      subGenre: json['sub_genre']?.toString(),
      bpm: (json['bpm'] as num?)?.toInt(),
      key: json['key']?.toString(),
      mood: json['mood']?.toString(),
      tags: _parseTags(json['tags']),
      audioUrl: (json['audio_url'] ?? '').toString(),
      audioPath: json['audio_path']?.toString(),
      previewUrl: json['preview_url']?.toString(),
      coverUrl: json['cover_url']?.toString(),
      duration: _safeInt(json['duration']),
      priceLease: _safeInt(json['price_lease']),
      priceUnlimited: _safeInt(json['price_unlimited']),
      priceExclusive: _safeInt(json['price_exclusive']),
      isFree: json['is_free'] == true,
      status: (json['status'] ?? 'active').toString(),
      isSoldExclusive: json['is_sold_exclusive'] == true,
      plays: _safeInt(json['plays']),
      purchases: _safeInt(json['purchases']),
      likes: _safeInt(json['likes']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      sellerName: json['seller_name']?.toString(),
      isLiked: json['is_liked'] == true || json['is_liked'] == 'true',
    );
  }

  String get formattedDuration {
    if (duration == null) return '--:--';
    final m = duration! ~/ 60;
    final s = duration! % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int priceForLicense(String licenseType) {
    switch (licenseType) {
      case 'exclusive':
        return priceExclusive;
      case 'unlimited':
        return priceUnlimited;
      default:
        return priceLease;
    }
  }
}
