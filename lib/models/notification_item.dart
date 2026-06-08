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

  factory NotificationItem.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    NotificationType type;

    switch (map['type']) {
      case 'low_food':
        type = NotificationType.lowFood;
        break;
      case 'low_water':
        type = NotificationType.lowWater;
        break;
      case 'feeding_complete':
        type = NotificationType.feedingComplete;
        break;
      case 'unknown_animal':
        type = NotificationType.unknownAnimal;
        break;
      case 'device_offline':
        type = NotificationType.deviceOffline;
        break;
      case 'device_online':
        type = NotificationType.deviceOnline;
        break;
      case 'manual_feed':
        type = NotificationType.manualFeed;
        break;
      default:
        type = NotificationType.manualFeed;
    }

    return NotificationItem(
      id: id,
      type: type,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      timestamp: DateTime.tryParse(
            map['timestamp']?.toString() ?? '',
          ) ??
          DateTime.now(),
      isRead: map['is_read'] ?? false,
    );
  }

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
