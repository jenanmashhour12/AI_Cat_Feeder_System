import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/constants/app_text_styles.dart';
import '../services/firebase_service.dart';

/// Form for creating a new cat. Reused both by the forced first-run
/// onboarding screen and by the "Add New Cat" option in [CatSwitcher].
class AddCatForm extends StatefulWidget {
  final FirebaseService firebaseService;

  /// Called with the new cat's id once it has been created.
  final ValueChanged<String>? onCreated;

  /// If provided, a Cancel button is shown next to Add Cat.
  final VoidCallback? onCancel;

  const AddCatForm({
    super.key,
    required this.firebaseService,
    this.onCreated,
    this.onCancel,
  });

  @override
  State<AddCatForm> createState() => _AddCatFormState();
}

class _AddCatFormState extends State<AddCatForm> {
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

  Future<void> _submit() async {
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
        name: name,
        portionG: _portionG,
        waterG: _waterG,
      );
      widget.onCreated?.call(cat.id);
    } catch (e) {
      setState(() => _error = 'Could not add cat: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cat Name', style: AppTextStyles.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Nana',
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
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
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
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            if (widget.onCancel != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add Cat'),
              ),
            ),
          ],
        ),
      ],
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
                style: AppTextStyles.titleSmall
                    .copyWith(color: AppColors.primary),
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

/// Bottom sheet wrapper around [AddCatForm], used from [CatSwitcher].
class AddCatSheet extends StatelessWidget {
  final FirebaseService firebaseService;
  final ValueChanged<String>? onCreated;

  const AddCatSheet({
    super.key,
    required this.firebaseService,
    this.onCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required FirebaseService firebaseService,
    ValueChanged<String>? onCreated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCatSheet(
        firebaseService: firebaseService,
        onCreated: onCreated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + bottomPadding,
      ),
      child: SingleChildScrollView(
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
            Text('Add a New Cat', style: AppTextStyles.displayMedium),
            const SizedBox(height: AppSpacing.xl),
            AddCatForm(
              firebaseService: firebaseService,
              onCancel: () => Navigator.of(context).pop(),
              onCreated: (id) {
                Navigator.of(context).pop();
                onCreated?.call(id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
