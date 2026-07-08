import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/firebase_service.dart';
import 'cat_info_form.dart';

/// Shows real-time enrollment progress while the Raspberry Pi captures
/// the cat's face. Transitions to [CatInfoForm] on success, or shows
/// an error with a retry option on failure.
class EnrollmentScreen extends StatefulWidget {
  final FirebaseService firebaseService;
  final ValueChanged<String>? onCreated;
  final VoidCallback? onCancel;

  const EnrollmentScreen({
    super.key,
    required this.firebaseService,
    this.onCreated,
    this.onCancel,
  });

  @override
  State<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends State<EnrollmentScreen> {
  bool _isCancelling = false;
  bool _hasNavigatedToInfoForm = false;
  String? _currentCatId;

  Future<void> _cancel() async {
    setState(() => _isCancelling = true);
    try {
      await widget.firebaseService.cancelEnrollment(catId: _currentCatId);
    } finally {
      if (mounted) {
        widget.onCancel?.call();
      }
    }
  }

  Future<void> _retry() async {
    await widget.firebaseService.startEnrollment();
  }

  void _goToInfoForm(BuildContext context, String catId) {
    if (_hasNavigatedToInfoForm) return;
    _hasNavigatedToInfoForm = true;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CatInfoForm(
          firebaseService: widget.firebaseService,
          catId: catId,
          onCreated: widget.onCreated,
          onCancel: widget.onCancel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: _isCancelling ? null : _cancel,
        ),
        title: Text('Add New Cat', style: AppTextStyles.titleMedium),
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: widget.firebaseService.watchEnrollment(),
        builder: (context, snapshot) {
          final data = snapshot.data ?? {};
          final status = data['status'] as String? ?? 'pending';
          final framesDone = (data['frames_done'] as num?)?.toInt() ?? 0;
          final framesNeeded = (data['frames_needed'] as num?)?.toInt() ?? 40;
          final instruction = data['instruction'] as String? ??
              'Bring your cat to the feeder camera';
          final reason = data['reason'] as String? ?? 'Unknown error';
          final catId = data['cat_id'] as String?;

          if (catId != null && catId != _currentCatId) {
            _currentCatId = catId;
          }

          if (status == 'done' && catId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _goToInfoForm(context, catId);
            });
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: status == 'failed'
                  ? _buildFailureState(context, reason)
                  : _buildProgressState(
                      context,
                      status: status,
                      framesDone: framesDone,
                      framesNeeded: framesNeeded,
                      instruction: instruction,
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressState(
    BuildContext context, {
    required String status,
    required int framesDone,
    required int framesNeeded,
    required String instruction,
  }) {
    final progress = framesNeeded > 0 ? framesDone / framesNeeded : 0.0;
    final isPending = status == 'pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: isPending
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary,
                    size: 36,
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          isPending ? 'Waiting for the feeder...' : 'Recognizing your cat',
          style: AppTextStyles.displayMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          isPending
              ? 'The feeder is getting ready. This usually takes a few seconds.'
              : 'Keep your cat in front of the camera.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        if (!isPending) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progress', style: AppTextStyles.titleSmall),
              Text(
                '$framesDone / $framesNeeded frames',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.primaryLight,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.cardBorder, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.tips_and_updates_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  instruction,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isCancelling ? null : _cancel,
            child: _isCancelling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  Widget _buildFailureState(BuildContext context, String reason) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Could not recognize your cat',
          style: AppTextStyles.displayMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(reason, style: AppTextStyles.bodyMedium),
        const SizedBox(height: AppSpacing.xxl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tips', style: AppTextStyles.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              _buildTip('Make sure the area is well lit'),
              _buildTip('Hold your cat still for a few seconds'),
              _buildTip('Make sure your cat faces the camera directly'),
              _buildTip('Clear any obstacles in front of the camera'),
            ],
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _cancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton(
                onPressed: _retry,
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.textSecondary)),
          Expanded(
            child: Text(text, style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}
