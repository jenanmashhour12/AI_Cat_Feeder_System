class ActivityLog {
  final String id;
  final ActivityLogType type;
  final String title;
  final String detail;
  final DateTime timestamp;
  final bool isSuccess;

  const ActivityLog({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.timestamp,
    required this.isSuccess,
  });

  factory ActivityLog.fromFeeding(String id, Map<String, dynamic> map) {
    final authorized = map['authorized'] == true;
    final catName = map['cat_name'] ?? 'Unknown Cat';
    final portion = map['portion_g'] ?? 0;
    final reason = map['reason'] ?? '';

    return ActivityLog(
      id: id,
      type: authorized
          ? ActivityLogType.feedingCompleted
          : ActivityLogType.feedingFailed,
      title: authorized ? 'Feeding Completed' : 'Feeding Failed',
      detail: authorized
          ? '$portion g dispensed for $catName'
          : reason.toString().isEmpty
              ? 'Access denied for $catName'
              : reason.toString(),
      timestamp: _parseDate(map['timestamp']),
      isSuccess: authorized,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return value.toDate();
  }

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays == 0) {
      final h = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
      final m = timestamp.minute.toString().padLeft(2, '0');
      final period = timestamp.hour < 12 ? 'AM' : 'PM';
      return 'Today, $h:$m $period';
    } else if (diff.inDays == 1) {
      final h = timestamp.hour % 12 == 0 ? 12 : timestamp.hour % 12;
      final m = timestamp.minute.toString().padLeft(2, '0');
      final period = timestamp.hour < 12 ? 'AM' : 'PM';
      return 'Yesterday, $h:$m $period';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

enum ActivityLogType {
  feedingCompleted,
  feedingFailed,
  catDetected,
  unknownAnimal,
  lowFood,
  lowWater,
  waterRefill,
  deviceConnected,
  deviceDisconnected,
  manualFeed,
}

extension ActivityLogTypeExtension on ActivityLogType {
  String get label {
    switch (this) {
      case ActivityLogType.feedingCompleted:
        return 'Feeding Completed';
      case ActivityLogType.feedingFailed:
        return 'Feeding Failed';
      case ActivityLogType.catDetected:
        return 'Cat Detected';
      case ActivityLogType.unknownAnimal:
        return 'Unknown Animal';
      case ActivityLogType.lowFood:
        return 'Low Food Level';
      case ActivityLogType.lowWater:
        return 'Low Water Level';
      case ActivityLogType.waterRefill:
        return 'Water Refill';
      case ActivityLogType.deviceConnected:
        return 'Device Connected';
      case ActivityLogType.deviceDisconnected:
        return 'Device Disconnected';
      case ActivityLogType.manualFeed:
        return 'Manual Feed';
    }
  }
}
