class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.isRead,
  });

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${diff.inDays} days ago';
    }
  }

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

enum NotificationType {
  lowFood,
  lowWater,
  feedingComplete,
  unknownAnimal,
  deviceOffline,
  deviceOnline,
  manualFeed,
}

extension NotificationTypeExtension on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.lowFood:
        return 'Low Food';
      case NotificationType.lowWater:
        return 'Low Water';
      case NotificationType.feedingComplete:
        return 'Feeding Done';
      case NotificationType.unknownAnimal:
        return 'Unknown Animal';
      case NotificationType.deviceOffline:
        return 'Device Offline';
      case NotificationType.deviceOnline:
        return 'Device Online';
      case NotificationType.manualFeed:
        return 'Manual Feed';
    }
  }
}
