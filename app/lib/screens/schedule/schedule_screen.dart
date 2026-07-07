import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/cat_session.dart';
import '../../models/feeding_schedule.dart';
import '../../services/firebase_service.dart';
import 'widgets/schedule_card.dart';
import 'widgets/schedule_form_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  void _openAddSheet(String catId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFormSheet(
        onSave: (schedule) async {
          final scheduleWithCat = schedule.copyWith(catId: catId);
          await _firebaseService.saveSchedule(scheduleWithCat);
        },
      ),
    );
  }

  void _openEditSheet(FeedingSchedule schedule, String catId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFormSheet(
        existing: schedule,
        onSave: (updated) async {
          final updatedWithCat = updated.copyWith(catId: catId);
          await _firebaseService.saveSchedule(updatedWithCat);
        },
      ),
    );
  }

  Future<void> _toggleSchedule(FeedingSchedule schedule, String catId) async {
    final updated = schedule.copyWith(
      isEnabled: !schedule.isEnabled,
      catId: catId,
    );

    await _firebaseService.saveSchedule(updated);
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
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _firebaseService.deleteSchedule(schedule.id);
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
    final session = CatSessionScope.of(context);
    final catId = session.currentCatId;

    if (catId == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<List<FeedingSchedule>>(
      stream: _firebaseService.watchSchedules(catId),
      builder: (context, snapshot) {
        final schedules = snapshot.data ?? [];
        final enabledCount = schedules.where((s) => s.isEnabled).length;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Feeding Schedule'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _openAddSheet(catId),
                tooltip: 'Add Schedule',
              ),
            ],
          ),
          body: Column(
            children: [
              _buildSummaryBanner(enabledCount, schedules.length),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : schedules.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: schedules.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.md),
                            itemBuilder: (context, index) {
                              final schedule = schedules[index];

                              return ScheduleCard(
                                schedule: schedule,
                                onToggle: () =>
                                    _toggleSchedule(schedule, catId),
                                onEdit: () =>
                                    _openEditSheet(schedule, catId),
                                onDelete: () => _deleteSchedule(schedule),
                              );
                            },
                          ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAddSheet(catId),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Schedule'),
          ),
        );
      },
    );
  }

  Widget _buildSummaryBanner(int enabled, int total) {
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
              '$enabled of $total schedules active',
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          Text(
            'Total: $total schedules',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.primaryDark,
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
