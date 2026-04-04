import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/feeding_schedule.dart';
import 'widgets/schedule_card.dart';
import 'widgets/schedule_form_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final List<FeedingSchedule> _schedules = [
    FeedingSchedule(
      id: '1',
      label: 'Morning Feeding',
      hour: 7,
      minute: 0,
      portionGrams: 40,
      isEnabled: true,
      activeDays: [true, true, true, true, true, true, true],
    ),
    FeedingSchedule(
      id: '2',
      label: 'Afternoon Feeding',
      hour: 13,
      minute: 0,
      portionGrams: 30,
      isEnabled: true,
      activeDays: [true, true, true, true, true, false, false],
    ),
    FeedingSchedule(
      id: '3',
      label: 'Evening Feeding',
      hour: 18,
      minute: 0,
      portionGrams: 40,
      isEnabled: false,
      activeDays: [true, true, true, true, true, true, true],
    ),
  ];

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFormSheet(
        onSave: (schedule) => setState(() => _schedules.add(schedule)),
      ),
    );
  }

  void _openEditSheet(FeedingSchedule schedule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFormSheet(
        existing: schedule,
        onSave: (updated) {
          setState(() {
            final index = _schedules.indexWhere((s) => s.id == schedule.id);
            if (index != -1) _schedules[index] = updated;
          });
        },
      ),
    );
  }

  void _toggleSchedule(FeedingSchedule schedule) {
    setState(() {
      final index = _schedules.indexWhere((s) => s.id == schedule.id);
      if (index != -1) {
        _schedules[index] = schedule.copyWith(isEnabled: !schedule.isEnabled);
      }
    });
  }

  void _deleteSchedule(FeedingSchedule schedule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        title: Text('Delete Schedule', style: AppTextStyles.headlineMedium),
        content: Text(
          'Remove "${schedule.label}"? This cannot be undone.',
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
              setState(
                  () => _schedules.removeWhere((s) => s.id == schedule.id));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _schedules.where((s) => s.isEnabled).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Feeding Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddSheet,
            tooltip: 'Add Schedule',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryBanner(enabledCount),
          Expanded(
            child: _schedules.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: _schedules.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final schedule = _schedules[index];
                      return ScheduleCard(
                        schedule: schedule,
                        onToggle: () => _toggleSchedule(schedule),
                        onEdit: () => _openEditSheet(schedule),
                        onDelete: () => _deleteSchedule(schedule),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Schedule'),
      ),
    );
  }

  Widget _buildSummaryBanner(int enabled) {
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
          const Icon(Icons.schedule, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$enabled of ${_schedules.length} schedules active',
              style:
                  AppTextStyles.titleSmall.copyWith(color: AppColors.primary),
            ),
          ),
          Text(
            'Total: ${_schedules.length} schedules',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.primaryDark),
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
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('No Schedules Yet', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap the button below to add a feeding schedule.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
