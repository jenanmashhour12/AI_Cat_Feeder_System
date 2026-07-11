import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/cat_session.dart';
import '../../widgets/status_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/info_chip.dart';
import '../../widgets/cat_switcher.dart';
import '../../models/system_status.dart';
import '../../models/feeding_schedule.dart';
import '../../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});
  static final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    final session = CatSessionScope.of(context);
    final catId = session.currentCatId;

    if (catId == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<SystemStatus>(
      stream: _firebaseService.watchSystemStatus(catId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final status = snapshot.data!;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  _buildHeader(context),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildSystemStatusBanner(status, catId),
                  const SizedBox(height: AppSpacing.xxl),
                  SectionHeader(
                    title: 'System Status',
                    actionLabel:
                        snapshot.connectionState == ConnectionState.waiting
                            ? 'Loading'
                            : 'Live',
                    onAction: () {},
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildStatusGrid(status, catId),
                  const SizedBox(height: AppSpacing.xxl),
                  const SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: AppSpacing.md),
                  _buildQuickActions(),
                  const SizedBox(height: AppSpacing.xxl),
                  SectionHeader(
                    title: 'Latest Activity',
                    actionLabel: 'View All',
                    onAction: () => onNavigate?.call(2),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildActivityPreview(catId),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final session = CatSessionScope.of(context);
    final catName = session.currentCat?.name ?? 'Cat Feeder';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good Morning,', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 2),
              Text(catName, style: AppTextStyles.displayMedium),
              const SizedBox(height: AppSpacing.sm),
              CatSwitcher(firebaseService: _firebaseService),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        GestureDetector(
          onTap: () => onNavigate?.call(3),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.iconRadius),
              border: Border.all(
                color: AppColors.cardBorder,
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemStatusBanner(SystemStatus status, String catId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F6EF7), Color(0xFF7B93F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: status.piOnline ? AppColors.online : AppColors.error,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.online.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                status.piOnline ? 'Feeder Online' : 'Feeder Offline',
                style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StreamBuilder<List<FeedingSchedule>>(
                stream: _firebaseService.watchSchedules(catId),
                builder: (context, snapshot) {
                  final next =
                      _computeNextFeeding(snapshot.data ?? const []);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Feeding',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next?.schedule.formattedTime ?? '--:--',
                        style: AppTextStyles.displayMedium
                            .copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        next == null
                            ? 'No active schedules'
                            : _formatCountdown(next.time),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.white70),
                      ),
                    ],
                  );
                },
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  InfoChip(
                    label: 'Cat Detected',
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    textColor: Colors.white,
                    icon: Icons.pets,
                  ),
                  const SizedBox(height: 8),
                  InfoChip(
                    label: 'Authorized',
                    backgroundColor: AppColors.success.withValues(alpha: 0.25),
                    textColor: Colors.white,
                    icon: Icons.verified_outlined,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Finds the soonest upcoming occurrence across all enabled schedules,
  /// respecting each schedule's active days. Returns null if there are no
  /// enabled schedules with at least one active day.
  _NextFeeding? _computeNextFeeding(List<FeedingSchedule> schedules) {
    final now = DateTime.now();
    DateTime? soonest;
    FeedingSchedule? soonestSchedule;

    for (final schedule in schedules.where((s) => s.isEnabled)) {
      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final day = DateTime(now.year, now.month, now.day)
            .add(Duration(days: dayOffset));
        final weekdayIndex = day.weekday - 1; // Mon=0 ... Sun=6
        if (weekdayIndex >= schedule.activeDays.length ||
            !schedule.activeDays[weekdayIndex]) {
          continue;
        }

        final candidate = DateTime(
          day.year,
          day.month,
          day.day,
          schedule.hour,
          schedule.minute,
        );

        if (candidate.isBefore(now)) continue;

        if (soonest == null || candidate.isBefore(soonest)) {
          soonest = candidate;
          soonestSchedule = schedule;
        }
        break;
      }
    }

    if (soonest == null || soonestSchedule == null) return null;
    return _NextFeeding(time: soonest, schedule: soonestSchedule);
  }

  String _formatCountdown(DateTime target) {
    final diff = target.difference(DateTime.now());

    if (diff.inDays >= 1) {
      return diff.inDays == 1 ? 'Tomorrow' : 'In ${diff.inDays} days';
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (hours > 0 && minutes > 0) {
      return 'In $hours hour${hours == 1 ? '' : 's'} '
          '$minutes minute${minutes == 1 ? '' : 's'}';
    } else if (hours > 0) {
      return 'In $hours hour${hours == 1 ? '' : 's'}';
    } else if (minutes > 0) {
      return 'In $minutes minute${minutes == 1 ? '' : 's'}';
    } else {
      return 'Feeding now';
    }
  }

  Widget _buildStatusGrid(SystemStatus status, String catId) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatusCard(
                title: 'Food Level',
                value: '${status.foodLevelPct.toStringAsFixed(0)}%',
                subtitle: 'Approx. 3 days left',
                icon: Icons.set_meal_outlined,
                iconColor: AppColors.primary,
                iconBackground: AppColors.primaryLight,
                trailing: _buildLevelBar(
                    status.foodLevelPct / 100, AppColors.primary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatusCard(
                title: 'Water Level',
                value: '${status.waterLevelPct.toStringAsFixed(0)}%',
                subtitle: 'Refill recommended',
                icon: Icons.water_drop_outlined,
                iconColor: const Color(0xFF38BDF8),
                iconBackground: const Color(0xFFE0F5FE),
                trailing: _buildLevelBar(
                    status.waterLevelPct / 100, const Color(0xFF38BDF8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildLastFeedingCard(catId),
        const SizedBox(height: AppSpacing.md),
        StatusCard(
          title: 'Raspberry Pi',
          value: status.piOnline ? 'Connected' : 'Disconnected',
          subtitle: 'Last synced ${_formatRelativeTime(status.lastUpdated)}'
              '${status.ipAddress != null ? '  •  IP: ${status.ipAddress}' : ''}',
          icon: Icons.developer_board_outlined,
          iconColor: status.piOnline ? AppColors.success : AppColors.error,
          iconBackground:
              status.piOnline ? AppColors.successLight : AppColors.errorLight,
          trailing: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: status.piOnline ? AppColors.online : AppColors.error,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLastFeedingCard(String catId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firebaseService.watchLatestFeedings(catId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('watchLatestFeedings error: ${snapshot.error}');
          return const StatusCard(
            title: 'Last Feeding',
            value: 'Error loading',
            subtitle: 'Check the debug console for details',
            icon: Icons.error_outline,
            iconColor: AppColors.error,
            iconBackground: AppColors.errorLight,
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const StatusCard(
            title: 'Last Feeding',
            value: 'No feedings yet',
            subtitle: 'Waiting for the first feeding',
            icon: Icons.history_outlined,
            iconColor: AppColors.textHint,
            iconBackground: AppColors.surfaceVariant,
          );
        }

        final data = docs.first.data();
        final authorized = data['authorized'] == true;
        final portion = data['portion_g'] ?? 0;
        final timestamp = _parseFeedingTimestamp(data['timestamp']);

        return StatusCard(
          title: 'Last Feeding',
          value: '${_formatClockTime(timestamp)} — ${portion}g',
          subtitle: authorized
              ? 'Successful  •  Cat detected and authorized'
              : 'Failed  •  Access denied',
          icon: Icons.history_outlined,
          iconColor: authorized ? AppColors.success : AppColors.error,
          iconBackground:
              authorized ? AppColors.successLight : AppColors.errorLight,
        );
      },
    );
  }

  DateTime _parseFeedingTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return value.toDate();
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatClockTime(DateTime time) {
    final h = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final m = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Widget _buildLevelBar(double value, Color color) {
    return SizedBox(
      height: 36,
      width: 8,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(100),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                heightFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            label: 'Schedule',
            icon: Icons.calendar_today_outlined,
            color: AppColors.warning,
            background: AppColors.warningLight,
            onTap: () => onNavigate?.call(1),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickActionButton(
            label: 'Logs',
            icon: Icons.list_alt_outlined,
            color: AppColors.success,
            background: AppColors.successLight,
            onTap: () => onNavigate?.call(2),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityPreview(String catId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firebaseService.watchLatestFeedings(catId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Most commonly a missing Firestore composite index (this query
          // filters by cat_id AND orders by timestamp). Check the debug
          // console — Firestore's error includes a direct link to create it.
          debugPrint('watchLatestFeedings error: ${snapshot.error}');
          return Text(
            'Could not load activity. Check the debug console for a '
            'Firestore index link.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Text('No recent activity yet.',
              style: AppTextStyles.bodyMedium);
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final authorized = data['authorized'] == true;
            final catName = data['cat_name'] ?? 'Unknown Cat';
            final portion = data['portion_g'] ?? 0;

            final item = _ActivityItem(
              icon: authorized
                  ? Icons.restaurant_outlined
                  : Icons.cancel_outlined,
              title: authorized ? 'Feeding Completed' : 'Feeding Failed',
              subtitle: authorized
                  ? '$portion g dispensed for $catName'
                  : 'Access denied for $catName',
              color: authorized ? AppColors.success : AppColors.error,
              bg: authorized ? AppColors.successLight : AppColors.errorLight,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildActivityTile(item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildActivityTile(_ActivityItem item) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.bg,
              borderRadius: BorderRadius.circular(AppSpacing.iconRadius),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppTextStyles.titleSmall),
                const SizedBox(height: 2),
                Text(item.subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.cardBorder, width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppSpacing.iconRadius),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NextFeeding {
  final DateTime time;
  final FeedingSchedule schedule;

  const _NextFeeding({required this.time, required this.schedule});
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bg;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bg,
  });
}
