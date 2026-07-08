import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/firebase_service.dart';
import '../../widgets/add_cat_sheet.dart';

/// Forced onboarding screen shown by [CatGate] when there are no cats
/// registered yet. Once a cat is added, the `cats` stream emits and the
/// app automatically swaps this screen out for [MainShell].
class AddCatScreen extends StatelessWidget {
  final FirebaseService firebaseService;

  const AddCatScreen({super.key, required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: const Icon(
                  Icons.pets,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Welcome to AI Cat Feeder',
                style: AppTextStyles.displayMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Let\'s set up your first cat. '
                'The feeder camera will recognize your cat\'s face '
                'before you give them a name.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AddCatForm(firebaseService: firebaseService),
            ],
          ),
        ),
      ),
    );
  }
}
