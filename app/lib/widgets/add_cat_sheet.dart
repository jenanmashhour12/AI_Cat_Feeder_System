import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/constants/app_text_styles.dart';
import '../screens/enrollment/enrollment_screen.dart';
import '../services/firebase_service.dart';

/// Entry point for the add-cat flow. Shows a brief explanation and a
/// "Start Enrollment" button. Does NOT collect cat info yet — that
/// happens in [CatInfoForm] after the Raspberry Pi successfully
/// recognizes the cat's face.
class AddCatForm extends StatefulWidget {
  final FirebaseService firebaseService;
  final ValueChanged<String>? onCreated;
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
  bool _isStarting = false;
  String? _error;

  Future<void> _startEnrollment() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });

    try {
      await widget.firebaseService.startEnrollment();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EnrollmentScreen(
            firebaseService: widget.firebaseService,
            onCreated: widget.onCreated,
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Could not start enrollment: $e');
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: const Icon(
            Icons.camera_alt_outlined,
            color: AppColors.primary,
            size: 28,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Recognize your cat first',
          style: AppTextStyles.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Place your cat in front of the feeder camera. '
          'The feeder will capture their face and recognize them. '
          'You can give them a name once they are recognized.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Make sure the feeder is powered on and the '
                  'camera has a clear view.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
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
        Row(
          children: [
            if (widget.onCancel != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isStarting ? null : widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _isStarting ? null : _startEnrollment,
                child: _isStarting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Start Enrollment'),
              ),
            ),
          ],
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
