class CatProfile {
  final String id;
  final String name;
  final double portionG;
  final double waterG;
  final int totalFeedings;
  final DateTime? enrolledAt;
  final DateTime? lastSeen;
  final String? imageUrl;
  final String? voiceUrl;

  const CatProfile({
    required this.id,
    required this.name,
    required this.portionG,
    required this.waterG,
    required this.totalFeedings,
    this.enrolledAt,
    this.lastSeen,
    this.imageUrl,
    this.voiceUrl,
  });

  factory CatProfile.fromMap(String id, Map<String, dynamic> map) {
    return CatProfile(
      id: id,
      name: (map['name'] ?? 'Unnamed Cat').toString(),
      portionG: (map['portion_g'] ?? 30).toDouble(),
      waterG: (map['water_g'] ?? 150).toDouble(),
      totalFeedings: _parseInt(map['total_feedings']),
      enrolledAt: _parseDate(map['enrolled_at']),
      lastSeen: _parseDate(map['last_seen']),
      imageUrl: map['image_url'] as String?,
      voiceUrl: map['voice_url'] as String?,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      return value.toDate();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'portion_g': portionG,
      'water_g': waterG,
      'total_feedings': totalFeedings,
      'enrolled_at': enrolledAt?.toIso8601String(),
      'last_seen': lastSeen?.toIso8601String(),
      'image_url': imageUrl,
      'voice_url': voiceUrl,
    };
  }

  CatProfile copyWith({
    String? name,
    double? portionG,
    double? waterG,
    int? totalFeedings,
    DateTime? lastSeen,
    String? imageUrl,
    String? voiceUrl,
  }) {
    return CatProfile(
      id: id,
      name: name ?? this.name,
      portionG: portionG ?? this.portionG,
      waterG: waterG ?? this.waterG,
      totalFeedings: totalFeedings ?? this.totalFeedings,
      enrolledAt: enrolledAt,
      lastSeen: lastSeen ?? this.lastSeen,
      imageUrl: imageUrl ?? this.imageUrl,
      voiceUrl: voiceUrl ?? this.voiceUrl,
    );
  }
}
