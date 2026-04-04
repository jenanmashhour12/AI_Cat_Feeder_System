import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/activity_log.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  ActivityLogType? _selectedFilter;

  final List<ActivityLog> _logs = [
    ActivityLog(
      id: '1',
      type: ActivityLogType.feedingCompleted,
      title: 'Feeding Completed',
      detail: '30g dispensed successfully',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isSuccess: true,
    ),
    ActivityLog(
      id: '2',
      type: ActivityLogType.catDetected,
      title: 'Cat Detected — Authorized',
      detail: 'Whiskers recognized via AI model',
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 2)),
      isSuccess: true,
    ),
    ActivityLog(
      id: '3',
      type: ActivityLogType.lowWater,
      title: 'Low Water Level',
      detail: 'Water dropped below 40% threshold',
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
      isSuccess: false,
    ),
    ActivityLog(
      id: '4',
      type: ActivityLogType.manualFeed,
      title: 'Manual Feed Triggered',
      detail: '20g dispensed by user',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      isSuccess: true,
    ),
    ActivityLog(
      id: '5',
      type: ActivityLogType.unknownAnimal,
      title: 'Unrecognized Animal',
      detail: 'Access denied — unknown animal detected',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      isSuccess: false,
    ),
    ActivityLog(
      id: '6',
      type: ActivityLogType.feedingCompleted,
      title: 'Feeding Completed',
      detail: '30g dispensed successfully',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      isSuccess: true,
    ),
    ActivityLog(
      id: '7',
      type: ActivityLogType.waterRefill,
      title: 'Water Refill Completed',
      detail: 'Water tank refilled manually',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
      isSuccess: true,
    ),
    ActivityLog(
      id: '8',
      type: ActivityLogType.deviceConnected,
      title: 'Device Connected',
      detail: 'Raspberry Pi reconnected to Firebase',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isSuccess: true,
    ),
    ActivityLog(
      id: '9',
      type: ActivityLogType.feedingFailed,
      title: 'Feeding Failed',
      detail: 'Motor error — food not dispensed',
      timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
      isSuccess: false,
    ),
    ActivityLog(
      id: '10',
      type: ActivityLogType.lowFood,
      title: 'Low Food Level',
      detail: 'Food dropped below 30% threshold',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      isSuccess: false,
    ),
  ];

  List<ActivityLog> get _filteredLogs {
    if (_selectedFilter == null) return _logs;
    return _logs.where((l) => l.type == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          _buildSummaryRow(),
          Expanded(
            child: _filteredLogs.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: _filteredLogs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      return _LogTile(log: _filteredLogs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final total = _logs.length;
    final success = _logs.where((l) => l.isSuccess).length;
    final failed = total - success;

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
      _FilterOption(
          type: ActivityLogType.feedingCompleted, label: 'Feeding Completed'),
      _FilterOption(
          type: ActivityLogType.feedingFailed, label: 'Feeding Failed'),
      _FilterOption(type: ActivityLogType.catDetected, label: 'Cat Detected'),
      _FilterOption(
          type: ActivityLogType.unknownAnimal, label: 'Unknown Animal'),
      _FilterOption(type: ActivityLogType.lowFood, label: 'Low Food'),
      _FilterOption(type: ActivityLogType.lowWater, label: 'Low Water'),
      _FilterOption(type: ActivityLogType.waterRefill, label: 'Water Refill'),
      _FilterOption(type: ActivityLogType.manualFeed, label: 'Manual Feed'),
      _FilterOption(
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
