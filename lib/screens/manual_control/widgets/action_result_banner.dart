import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../models/action_result.dart';

class ActionResultBanner extends StatelessWidget {
  final ActionResult result;

  const ActionResultBanner({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: result.bg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: result.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: result.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppSpacing.iconRadius - 2),
            ),
            child: Icon(result.icon, color: result.color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.success ? 'Action Successful' : 'Action Failed',
                  style: AppTextStyles.titleSmall.copyWith(color: result.color),
                ),
                const SizedBox(height: 2),
                Text(result.message, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(result.time, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}
