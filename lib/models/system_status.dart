class SystemStatus {
  final double foodLevelPct;
  final double waterLevelPct;
  final bool piOnline;
  final DateTime lastUpdated;

  const SystemStatus({
    required this.foodLevelPct,
    required this.waterLevelPct,
    required this.piOnline,
    required this.lastUpdated,
  });

  factory SystemStatus.fromMap(Map<String, dynamic> map) {
    return SystemStatus(
      foodLevelPct: (map['food_level_pct'] ?? 0).toDouble(),
      waterLevelPct: (map['water_level_pct'] ?? 0).toDouble(),
      piOnline: map['pi_online'] ?? false,
      lastUpdated: map['last_updated']?.toDate() ?? DateTime.now(),
    );
  }
}
