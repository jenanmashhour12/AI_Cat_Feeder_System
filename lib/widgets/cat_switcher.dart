import 'package:flutter/material.dart';
import '../core/cat_session.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/constants/app_text_styles.dart';
import '../models/cat_profile.dart';
import '../services/firebase_service.dart';
import 'add_cat_sheet.dart';

/// Small chip shown on the dashboard header. Tapping it opens a bottom
/// sheet listing every registered cat (tap to switch) plus an "Add New Cat"
/// action — all without leaving the app.
class CatSwitcher extends StatelessWidget {
  final FirebaseService firebaseService;

  const CatSwitcher({super.key, required this.firebaseService});

  /// Can be called from anywhere (e.g. Settings screen) to open the same
  /// switch/add sheet.
  static void open(BuildContext context, FirebaseService firebaseService) {
    final session = CatSessionScope.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StreamBuilder<List<CatProfile>>(
        stream: firebaseService.watchCats(),
        builder: (context, snapshot) {
          final cats = snapshot.data ?? [];

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Switch Cat', style: AppTextStyles.headlineMedium),
                const SizedBox(height: AppSpacing.md),
                ...cats.map((cat) {
                  final isSelected = session.currentCatId == cat.id;
                  return GestureDetector(
                    onTap: () {
                      session.selectCat(cat);
                      Navigator.of(sheetContext).pop();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryLight
                            : AppColors.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.cardRadius),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.cardBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              cat.name.isNotEmpty
                                  ? cat.name[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.titleSmall
                                  .copyWith(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(cat.name,
                                style: AppTextStyles.titleSmall),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    AddCatSheet.show(
                      context,
                      firebaseService: firebaseService,
                      onCreated: (id) {},
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                      border: Border.all(
                        color: AppColors.cardBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          'Add New Cat',
                          style: AppTextStyles.titleSmall
                              .copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = CatSessionScope.of(context);
    final cat = session.currentCat;

    return GestureDetector(
      onTap: () => CatSwitcher.open(context, firebaseService),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(color: AppColors.cardBorder, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pets, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              cat?.name ?? 'Select Cat',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more,
                color: AppColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
