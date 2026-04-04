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
