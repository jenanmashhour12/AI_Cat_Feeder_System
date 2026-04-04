import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/notification_item.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      type: NotificationType.lowWater,
      title: 'Low Water Level',
      message: 'Water level has dropped below 40%. Please refill soon.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      isRead: false,
    ),
    NotificationItem(
      id: '2',
      type: NotificationType.feedingComplete,
      title: 'Feeding Completed',
      message: '30g of food was successfully dispensed at 9:00 AM.',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
    ),
    NotificationItem(
      id: '3',
      type: NotificationType.unknownAnimal,
      title: 'Unrecognized Animal Detected',
      message:
          'An unrecognized animal approached the feeder. Access was denied.',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: false,
    ),
    NotificationItem(
      id: '4',
      type: NotificationType.lowFood,
      title: 'Low Food Level',
      message: 'Food container is at 28%. Consider refilling soon.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
    NotificationItem(
      id: '5',
      type: NotificationType.feedingComplete,
      title: 'Feeding Completed',
      message: '30g of food was successfully dispensed at 6:00 PM.',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      isRead: true,
    ),
    NotificationItem(
      id: '6',
      type: NotificationType.deviceOffline,
      title: 'Device Went Offline',
      message:
          'The feeder lost connection briefly. It reconnected after 2 minutes.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
    ),
    NotificationItem(
      id: '7',
      type: NotificationType.deviceOnline,
      title: 'Device Back Online',
      message: 'Raspberry Pi reconnected to Firebase successfully.',
      timestamp: DateTime.now().subtract(const Duration(days: 2, minutes: 2)),
      isRead: true,
    ),
    NotificationItem(
      id: '8',
      type: NotificationType.manualFeed,
      title: 'Manual Feed Triggered',
      message: '20g was dispensed manually via the app.',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      isRead: true,
    ),
  ];

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _markAllRead() {
    setState(() {
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });
  }

  void _markRead(String id) {
    setState(() {
      _notifications = _notifications.map((n) {
        if (n.id == id) return n.copyWith(isRead: true);
        return n;
      }).toList();
    });
  }

  void _deleteNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        title: Text('Clear All', style: AppTextStyles.headlineMedium),
        content: Text(
          'Remove all notifications? This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _notifications.clear());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$_unreadCount',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                'Mark all read',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.primary),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _notifications.isEmpty ? null : _clearAll,
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                if (_unreadCount > 0) _buildUnreadBanner(),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      return _NotificationTile(
                        notification: n,
                        onTap: () => _markRead(n.id),
                        onDelete: () => _deleteNotification(n.id),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUnreadBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle_notifications_outlined,
              color: AppColors.primary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$_unreadCount unread notification${_unreadCount > 1 ? 's' : ''}',
              style:
                  AppTextStyles.titleSmall.copyWith(color: AppColors.primary),
            ),
          ),
          GestureDetector(
            onTap: _markAllRead,
            child: Text(
              'Mark all read',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              color: AppColors.textHint,
              size: 34,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('No Notifications', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You are all caught up.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  Color get _iconColor {
    switch (notification.type) {
      case NotificationType.feedingComplete:
      case NotificationType.deviceOnline:
      case NotificationType.manualFeed:
        return AppColors.success;
      case NotificationType.lowFood:
      case NotificationType.lowWater:
        return AppColors.warning;
      case NotificationType.unknownAnimal:
      case NotificationType.deviceOffline:
        return AppColors.error;
    }
  }

  Color get _iconBg {
    switch (notification.type) {
      case NotificationType.feedingComplete:
      case NotificationType.deviceOnline:
      case NotificationType.manualFeed:
        return AppColors.successLight;
      case NotificationType.lowFood:
      case NotificationType.lowWater:
        return AppColors.warningLight;
      case NotificationType.unknownAnimal:
      case NotificationType.deviceOffline:
        return AppColors.errorLight;
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case NotificationType.feedingComplete:
        return Icons.check_circle_outline;
      case NotificationType.lowFood:
        return Icons.set_meal_outlined;
      case NotificationType.lowWater:
        return Icons.water_drop_outlined;
      case NotificationType.unknownAnimal:
        return Icons.pets;
      case NotificationType.deviceOffline:
        return Icons.wifi_off_outlined;
      case NotificationType.deviceOnline:
        return Icons.wifi_outlined;
      case NotificationType.manualFeed:
        return Icons.touch_app_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(
              color:
                  isUnread ? _iconColor.withOpacity(0.3) : AppColors.cardBorder,
              width: isUnread ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(AppSpacing.iconRadius),
                ),
                child: Icon(_icon, color: _iconColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.titleSmall,
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _iconColor,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 11,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          notification.formattedTime,
                          style: AppTextStyles.labelSmall,
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '• Tap to mark read',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: _iconColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
