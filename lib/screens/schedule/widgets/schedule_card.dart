import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/feeding_schedule.dart';

class ScheduleCard extends StatelessWidget {
  final FeedingSchedule schedule;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = schedule.isEnabled;

    return AnimatedOpacity(
      opacity: isEnabled ? 1.0 : 0.55,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: isEnabled
                ? AppColors.primary.withOpacity(0.25)
                : AppColors.cardBorder,
            width: isEnabled ? 1.5 : 1,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimeBlock(isEnabled),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _buildDetails()),
                  _buildActions(),
                ],
              ),
            ),
            _buildDayRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBlock(bool isEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isEnabled ? AppColors.primaryLight : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Text(
        schedule.formattedTime,
        style: AppTextStyles.headlineMedium.copyWith(
          color: isEnabled ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(schedule.label, style: AppTextStyles.titleMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.set_meal_outlined,
                size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              '${schedule.portionGrams.toStringAsFixed(0)}g portion',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.repeat, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                schedule.activeDaysLabel,
                style: AppTextStyles.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Switch.adaptive(
          value: schedule.isEnabled,
          onChanged: (_) => onToggle(),
          activeColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined,
                    size: 16, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 16, color: AppColors.error),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayRow() {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final active = schedule.activeDays[i];
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: active
                  ? (schedule.isEnabled
                      ? AppColors.primary
                      : AppColors.textSecondary)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(100),
            ),
            alignment: Alignment.center,
            child: Text(
              dayLabels[i],
              style: AppTextStyles.labelSmall.copyWith(
                color: active ? Colors.white : AppColors.textHint,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }),
      ),
    );
  }
}
