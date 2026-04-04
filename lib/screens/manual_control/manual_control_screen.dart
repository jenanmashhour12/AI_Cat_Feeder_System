import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import 'models/action_result.dart';
import 'widgets/action_result_banner.dart';
import 'widgets/portion_selector.dart';

class ManualControlScreen extends StatefulWidget {
  const ManualControlScreen({super.key});

  @override
  State<ManualControlScreen> createState() => _ManualControlScreenState();
}

class _ManualControlScreenState extends State<ManualControlScreen> {
  double _selectedPortion = 30;
  ActionResult? _lastResult;
  bool _isFeeding = false;
  bool _isRefilling = false;

  Future<void> _triggerFeed() async {
    final confirmed = await _showConfirmation(
      title: 'Confirm Manual Feeding',
      message: 'Dispense ${_selectedPortion.toStringAsFixed(0)}g of food now? '
          'This triggers an immediate feeding cycle.',
      confirmLabel: 'Feed Now',
      confirmColor: AppColors.primary,
    );
    if (!confirmed) return;

    setState(() {
      _isFeeding = true;
      _lastResult = null;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isFeeding = false;
      _lastResult = ActionResult(
        success: true,
        message:
            '${_selectedPortion.toStringAsFixed(0)}g dispensed successfully.',
        time: _formattedNow(),
        icon: Icons.check_circle_outline,
        color: AppColors.success,
        bg: AppColors.successLight,
      );
    });
  }

  Future<void> _triggerRefill() async {
    final confirmed = await _showConfirmation(
      title: 'Confirm Water Refill',
      message: 'Activate the water refill pump now?',
      confirmLabel: 'Refill',
      confirmColor: const Color(0xFF38BDF8),
    );
    if (!confirmed) return;

    setState(() {
      _isRefilling = true;
      _lastResult = null;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isRefilling = false;
      _lastResult = ActionResult(
        success: true,
        message: 'Water refill cycle completed.',
        time: _formattedNow(),
        icon: Icons.water_drop_outlined,
        color: const Color(0xFF38BDF8),
        bg: const Color(0xFFE0F5FE),
      );
    });
  }

  Future<bool> _showConfirmation({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        title: Text(title, style: AppTextStyles.headlineMedium),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _formattedNow() {
    final now = DateTime.now();
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    final period = now.hour < 12 ? 'AM' : 'PM';
    return 'Today at $h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Manual Control')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_lastResult != null) ...[
              ActionResultBanner(result: _lastResult!),
              const SizedBox(height: AppSpacing.lg),
            ],
            _buildStatusRow(),
            const SizedBox(height: AppSpacing.lg),
            _buildFeedCard(),
            const SizedBox(height: AppSpacing.lg),
            _buildWaterCard(),
            const SizedBox(height: AppSpacing.xxl),
            _buildSafetyNote(),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        _StatusPill(
          label: 'Feeder Online',
          icon: Icons.developer_board_outlined,
          color: AppColors.success,
          bg: AppColors.successLight,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatusPill(
          label: 'Food: 72%',
          icon: Icons.set_meal_outlined,
          color: AppColors.primary,
          bg: AppColors.primaryLight,
        ),
        const SizedBox(width: AppSpacing.sm),
        _StatusPill(
          label: 'Water: 45%',
          icon: Icons.water_drop_outlined,
          color: const Color(0xFF38BDF8),
          bg: const Color(0xFFE0F5FE),
        ),
      ],
    );
  }

  Widget _buildFeedCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppSpacing.iconRadius),
                  ),
                  child: const Icon(
                    Icons.set_meal_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manual Feed', style: AppTextStyles.headlineMedium),
                    Text(
                      'Dispenses food immediately',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Portion', style: AppTextStyles.titleSmall),
                const SizedBox(height: AppSpacing.md),
                PortionSelector(
                  selected: _selectedPortion,
                  onChanged: (v) => setState(() => _selectedPortion = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isFeeding ? null : _triggerFeed,
                    icon: _isFeeding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(_isFeeding ? 'Dispensing...' : 'Feed Now'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F5FE),
              borderRadius: BorderRadius.circular(AppSpacing.iconRadius),
            ),
            child: const Icon(
              Icons.water_drop_outlined,
              color: Color(0xFF38BDF8),
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Water Refill', style: AppTextStyles.headlineMedium),
                Text(
                  'Current level: 45%  •  Refill recommended',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ElevatedButton(
            onPressed: _isRefilling ? null : _triggerRefill,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
            ),
            child: _isRefilling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Refill'),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyNote() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Manual actions override the schedule. Scheduled feedings '
              'will still run as configured unless manually skipped.',
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF7A5500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;

  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
