import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/cat_session.dart';
import '../../models/activity_log.dart';
import '../../services/firebase_service.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  ActivityLogType? _selectedFilter;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    final session = CatSessionScope.of(context);
    final catId = session.currentCatId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Activity Logs'),
        actions: [
          if (_selectedFilter != null)
            TextButton(
              onPressed: () => setState(() => _selectedFilter = null),
              child: Text(
                'Clear',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.primary),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: _showFilterSheet,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: catId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<ActivityLog>>(
              stream: _firebaseService.watchFeedings(catId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final logs = snapshot.data!;

                final filteredLogs = _selectedFilter == null
                    ? logs
                    : logs.where((l) => l.type == _selectedFilter).toList();

                final total = logs.length;
                final success = logs.where((l) => l.isSuccess).length;
                final failed = total - success;

                return Column(
                  children: [
                    _buildSummaryRow(total, success, failed),
                    Expanded(
                      child: filteredLogs.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              itemCount: filteredLogs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) {
                                return _LogTile(
                                  log: filteredLogs[index],
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSummaryRow(
    int total,
    int success,
    int failed,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Row(
        children: [
          _SummaryChip(
            label: '$total Total',
            color: AppColors.primary,
            bg: AppColors.primaryLight,
          ),
          const SizedBox(width: AppSpacing.sm),
          _SummaryChip(
            label: '$success Success',
            color: AppColors.success,
            bg: AppColors.successLight,
          ),
          const SizedBox(width: AppSpacing.sm),
          _SummaryChip(
            label: '$failed Failed',
            color: AppColors.error,
            bg: AppColors.errorLight,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: const Icon(
              Icons.list_alt_outlined,
              color: AppColors.textHint,
              size: 30,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('No logs found', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No events match the selected filter.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    final filters = [
      const _FilterOption(
          type: ActivityLogType.feedingCompleted, label: 'Feeding Completed'),
      const _FilterOption(
          type: ActivityLogType.feedingFailed, label: 'Feeding Failed'),
      const _FilterOption(
          type: ActivityLogType.catDetected, label: 'Cat Detected'),
      const _FilterOption(
          type: ActivityLogType.unknownAnimal, label: 'Unknown Animal'),
      const _FilterOption(type: ActivityLogType.lowFood, label: 'Low Food'),
      const _FilterOption(type: ActivityLogType.lowWater, label: 'Low Water'),
      const _FilterOption(
          type: ActivityLogType.waterRefill, label: 'Water Refill'),
      const _FilterOption(
          type: ActivityLogType.manualFeed, label: 'Manual Feed'),
      const _FilterOption(
          type: ActivityLogType.deviceConnected, label: 'Device Connected'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            Text('Filter by Type', style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: filters.map((f) {
                final isSelected = _selectedFilter == f.type;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = f.type);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.chipRadius),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.cardBorder,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      f.label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final ActivityLog log;

  const _LogTile({required this.log});

  Color get _iconColor {
    switch (log.type) {
      case ActivityLogType.feedingCompleted:
      case ActivityLogType.waterRefill:
      case ActivityLogType.deviceConnected:
      case ActivityLogType.manualFeed:
        return AppColors.success;
      case ActivityLogType.catDetected:
        return AppColors.primary;
      case ActivityLogType.lowFood:
      case ActivityLogType.lowWater:
        return AppColors.warning;
      case ActivityLogType.feedingFailed:
      case ActivityLogType.unknownAnimal:
      case ActivityLogType.deviceDisconnected:
        return AppColors.error;
    }
  }

  Color get _iconBg {
    switch (log.type) {
      case ActivityLogType.feedingCompleted:
      case ActivityLogType.waterRefill:
      case ActivityLogType.deviceConnected:
      case ActivityLogType.manualFeed:
        return AppColors.successLight;
      case ActivityLogType.catDetected:
        return AppColors.primaryLight;
      case ActivityLogType.lowFood:
      case ActivityLogType.lowWater:
        return AppColors.warningLight;
      case ActivityLogType.feedingFailed:
      case ActivityLogType.unknownAnimal:
      case ActivityLogType.deviceDisconnected:
        return AppColors.errorLight;
    }
  }

  IconData get _icon {
    switch (log.type) {
      case ActivityLogType.feedingCompleted:
        return Icons.restaurant_outlined;
      case ActivityLogType.feedingFailed:
        return Icons.cancel_outlined;
      case ActivityLogType.catDetected:
        return Icons.pets;
      case ActivityLogType.unknownAnimal:
        return Icons.block_outlined;
      case ActivityLogType.lowFood:
        return Icons.set_meal_outlined;
      case ActivityLogType.lowWater:
        return Icons.water_drop_outlined;
      case ActivityLogType.waterRefill:
        return Icons.water_drop_outlined;
      case ActivityLogType.deviceConnected:
        return Icons.developer_board_outlined;
      case ActivityLogType.deviceDisconnected:
        return Icons.developer_board_off_outlined;
      case ActivityLogType.manualFeed:
        return Icons.touch_app_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _iconBg,
              borderRadius: BorderRadius.circular(AppSpacing.iconRadius),
            ),
            child: Icon(_icon, color: _iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.title, style: AppTextStyles.titleSmall),
                const SizedBox(height: 2),
                Text(log.detail, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(log.formattedTime, style: AppTextStyles.labelSmall),
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: log.isSuccess ? AppColors.success : AppColors.error,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _SummaryChip({
    required this.label,
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
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FilterOption {
  final ActivityLogType type;
  final String label;

  const _FilterOption({required this.type, required this.label});
}
