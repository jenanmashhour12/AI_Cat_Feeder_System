import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/constants/app_text_styles.dart';
import '../models/notification_item.dart';

/// Shows a temporary top banner for [notification] that auto-dismisses
/// after a few seconds. Call this from anywhere in the app whenever a new
/// notification arrives so the user notices it without having to open the
/// Notifications tab.
void showNotificationToast(
  BuildContext context,
  NotificationItem notification, {
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);

  late OverlayEntry entry;
  final controller = _ToastController();

  entry = OverlayEntry(
    builder: (context) => _NotificationToast(
      notification: notification,
      controller: controller,
      duration: duration,
      onDismiss: () => entry.remove(),
      onTap: () {
        entry.remove();
        onTap?.call();
      },
    ),
  );

  overlay.insert(entry);
}

/// Lets the toast widget signal back when its exit animation is done.
class _ToastController {
  VoidCallback? _requestClose;
}

class _NotificationToast extends StatefulWidget {
  final NotificationItem notification;
  final _ToastController controller;
  final Duration duration;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NotificationToast({
    required this.notification,
    required this.controller,
    required this.duration,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_NotificationToast> createState() => _NotificationToastState();
}

class _NotificationToastState extends State<_NotificationToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.2),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _anim, curve: Curves.easeOut);

  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    widget.controller._requestClose = _close;
    _anim.forward();
    _autoCloseTimer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (!mounted) return;
    _autoCloseTimer?.cancel();
    await _anim.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Color get _iconColor {
    switch (widget.notification.type) {
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
    switch (widget.notification.type) {
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
    switch (widget.notification.type) {
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
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    widget.controller._requestClose?.call();
                    widget.onTap();
                  },
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) < 0) {
                      _close();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _iconBg,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(AppSpacing.iconRadius),
                            ),
                          ),
                          child: Icon(_icon, color: _iconColor, size: 20),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.notification.title,
                                style: AppTextStyles.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.notification.message,
                                style: AppTextStyles.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
