import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/firebase_service.dart';

/// Shown after the Raspberry Pi successfully recognizes a cat's face.
/// Collects the cat's name, portion size, and water amount, then saves
/// the cat to Firestore using [catId] — the ID the Pi assigned during
/// enrollment. This ID links the face gallery on the Pi to the cat
/// profile in Firebase.
class CatInfoForm extends StatefulWidget {
  final FirebaseService firebaseService;

  /// The cat ID assigned by the Raspberry Pi during enrollment.
  /// Must be used as the Firestore document ID so it matches the
  /// gallery file on the Pi.
  final String catId;

  final ValueChanged<String>? onCreated;
  final VoidCallback? onCancel;

  const CatInfoForm({
    super.key,
    required this.firebaseService,
    required this.catId,
    this.onCreated,
    this.onCancel,
  });

  @override
  State<CatInfoForm> createState() => _CatInfoFormState();
}

class _CatInfoFormState extends State<CatInfoForm> {
  final _nameController = TextEditingController();
  double _portionG = 30;
  double _waterG = 150;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _cancelEnrollment() async {
    try {
      await widget.firebaseService.cancelEnrollment(catId: widget.catId);
    } catch (_) {
      // Ignore cancellation write failures and still close the form.
    }

    if (mounted) {
      widget.onCancel?.call();
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name for your cat.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final cat = await widget.firebaseService.addCat(
        catId: widget.catId,
        name: name,
        portionG: _portionG,
        waterG: _waterG,
      );

      await widget.firebaseService.cancelEnrollment();

      if (mounted) {
        widget.onCreated?.call(cat.id);
      }
    } catch (e) {
      setState(() => _error = 'Could not save cat: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _isSaving ? null : _cancelEnrollment,
        ),
        title: Text('Name Your Cat', style: AppTextStyles.titleMedium),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your cat was recognized!',
                            style: AppTextStyles.titleSmall.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Now give them a name and set their portions.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Cat Name', style: AppTextStyles.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Mimi',
                  hintStyle: AppTextStyles.bodyMedium,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildSlider(
                label: 'Default Portion',
                value: _portionG,
                min: 10,
                max: 100,
                unit: 'g',
                onChanged: (v) => setState(() => _portionG = v),
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildSlider(
                label: 'Water Bowl Capacity',
                value: _waterG,
                min: 50,
                max: 300,
                unit: 'g',
                onChanged: (v) => setState(() => _waterG = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Cat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.titleSmall),
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
                '${value.toStringAsFixed(0)}$unit',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.primaryLight,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.12),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) / 5).round(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
