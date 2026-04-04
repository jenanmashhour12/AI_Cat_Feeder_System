import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';

class PortionSelector extends StatelessWidget {
  final double selected;
  final ValueChanged<double> onChanged;

  static const List<double> _presets = [10, 20, 30, 40, 50];

  const PortionSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: _presets.map((g) {
            final isSelected = selected == g;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(
                    right: g == _presets.last ? 0 : AppSpacing.sm,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.cardRadius - 4),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.primary : AppColors.cardBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${g.toStringAsFixed(0)}g',
                    style: AppTextStyles.titleSmall.copyWith(
                      color:
                          isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Custom amount', style: AppTextStyles.titleSmall),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
              ),
              child: Text(
                '${selected.toStringAsFixed(0)}g',
                style:
                    AppTextStyles.titleSmall.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.primaryLight,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withOpacity(0.12),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: selected,
            min: 10,
            max: 100,
            divisions: 18,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('10g', style: AppTextStyles.labelSmall),
            Text('100g', style: AppTextStyles.labelSmall),
          ],
        ),
      ],
    );
  }
}
