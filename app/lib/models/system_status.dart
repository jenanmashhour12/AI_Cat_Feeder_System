class SystemStatus {
  final double foodLevelPct;
  final double waterLevelPct;
  final bool piOnline;
  final DateTime lastUpdated;

  /// Only populated if the Raspberry Pi writes this field itself — there is
  /// no other source of truth for its network address.
  final String? ipAddress;

  const SystemStatus({
    required this.foodLevelPct,
    required this.waterLevelPct,
    required this.piOnline,
    required this.lastUpdated,
    this.ipAddress,
  });

  factory SystemStatus.fromMap(Map<String, dynamic> map) {
    return SystemStatus(
      foodLevelPct: (map['food_level_pct'] ?? 0).toDouble(),
      waterLevelPct: (map['water_level_pct'] ?? 0).toDouble(),
      piOnline: map['pi_online'] == true || map['pi_online'] == 'true',
      lastUpdated: _parseDate(map['last_updated']),
      ipAddress: (map['ip_address'] as String?)?.trim().isNotEmpty == true
          ? map['ip_address'] as String
          : null,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();

    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return value.toDate();
  }
}
