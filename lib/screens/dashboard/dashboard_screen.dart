import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/status_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/info_chip.dart';
import '../../models/system_status.dart';
import '../../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  static final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SystemStatus>(
      stream: _firebaseService.watchSystemStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final status = snapshot.data!;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  _buildHeader(),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildSystemStatusBanner(status),
                  const SizedBox(height: AppSpacing.xxl),
                  SectionHeader(
                    title: 'System Status',
                    actionLabel:
                        snapshot.connectionState == ConnectionState.waiting
                            ? 'Loading'
                            : 'Live',
                    onAction: () {},
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildStatusGrid(status),
                  const SizedBox(height: AppSpacing.xxl),
                  const SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: AppSpacing.md),
                  _buildQuickActions(context),
                  const SizedBox(height: AppSpacing.xxl),
                  SectionHeader(
                    title: 'Latest Activity',
                    actionLabel: 'View All',
                    onAction: () {},
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildActivityPreview(),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good Morning,', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 2),
            Text('Cat Feeder', style: AppTextStyles.displayMedium),
          ],
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.iconRadius),
            border: Border.all(color: AppColors.cardBorder, width: 1),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textPrimary,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemStatusBanner(SystemStatus status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F6EF7), Color(0xFF7B93F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: status.piOnline ? AppColors.online : AppColors.error,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.online.withOpacity(0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                status.piOnline ? 'Feeder Online' : 'Feeder Offline',
                style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Feeding',
                    style:
                        AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '6:00 PM',
                    style: AppTextStyles.displayMedium
                        .copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'In 3 hours 24 minutes',
                    style:
                        AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  InfoChip(
                    label: 'Cat Detected',
                    backgroundColor: Colors.white.withOpacity(0.2),
                    textColor: Colors.white,
                    icon: Icons.pets,
                  ),
                  const SizedBox(height: 8),
                  InfoChip(
                    label: 'Authorized',
                    backgroundColor: AppColors.success.withOpacity(0.25),
                    textColor: Colors.white,
                    icon: Icons.verified_outlined,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGrid(SystemStatus status) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatusCard(
                title: 'Food Level',
                value: '${status.foodLevelPct.toStringAsFixed(0)}%',
                subtitle: 'Approx. 3 days left',
                icon: Icons.set_meal_outlined,
                iconColor: AppColors.primary,
                iconBackground: AppColors.primaryLight,
                trailing: _buildLevelBar(
                    status.foodLevelPct / 100, AppColors.primary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatusCard(
                title: 'Water Level',
                value: '${status.waterLevelPct.toStringAsFixed(0)}%',
                subtitle: 'Refill recommended',
                icon: Icons.water_drop_outlined,
                iconColor: const Color(0xFF38BDF8),
                iconBackground: const Color(0xFFE0F5FE),
                trailing: _buildLevelBar(
                    status.waterLevelPct / 100, const Color(0xFF38BDF8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const StatusCard(
          title: 'Last Feeding',
          value: '9:00 AM — 30g',
          subtitle: 'Successful  •  Cat detected and authorized',
          icon: Icons.history_outlined,
          iconColor: AppColors.success,
          iconBackground: AppColors.successLight,
        ),
        const SizedBox(height: AppSpacing.md),
        StatusCard(
          title: 'Raspberry Pi',
          value: status.piOnline ? 'Connected' : 'Disconnected',
          subtitle: 'Signal: Strong  •  Latency: 12ms',
          icon: Icons.developer_board_outlined,
          iconColor: AppColors.success,
          iconBackground: AppColors.successLight,
          trailing: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: status.piOnline ? AppColors.online : AppColors.error,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelBar(double value, Color color) {
    return SizedBox(
      height: 36,
      width: 8,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(100),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                heightFactor: value,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            label: 'Feed Now',
            icon: Icons.play_circle_outline,
            color: AppColors.primary,
            background: AppColors.primaryLight,
            onTap: () => _showFeedConfirmation(context),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickActionButton(
            label: 'Schedule',
            icon: Icons.calendar_today_outlined,
            color: AppColors.warning,
            background: AppColors.warningLight,
            onTap: () {},
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _QuickActionButton(
            label: 'Logs',
            icon: Icons.list_alt_outlined,
            color: AppColors.success,
            background: AppColors.successLight,
            onTap: () {},
          ),
        ),
      ],
    );
  }

  void _showFeedConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        title: Text('Manual Feeding', style: AppTextStyles.headlineMedium),
        content: Text(
          'Dispense food now? This will trigger an immediate feeding cycle.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Feed Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPreview() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firebaseService.watchLatestFeedings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Text('No recent activity yet.',
              style: AppTextStyles.bodyMedium);
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final authorized = data['authorized'] == true;
            final catName = data['cat_name'] ?? 'Unknown Cat';
            final portion = data['portion_g'] ?? 0;

            final item = _ActivityItem(
              icon: authorized
                  ? Icons.restaurant_outlined
                  : Icons.cancel_outlined,
              title: authorized ? 'Feeding Completed' : 'Feeding Failed',
              subtitle: authorized
                  ? '$portion g dispensed for $catName'
                  : 'Access denied for $catName',
              color: authorized ? AppColors.success : AppColors.error,
              bg: authorized ? AppColors.successLight : AppColors.errorLight,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildActivityTile(item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildActivityTile(_ActivityItem item) {
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.bg,
              borderRadius: BorderRadius.circular(AppSpacing.iconRadius),
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppTextStyles.titleSmall),
                const SizedBox(height: 2),
                Text(item.subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.cardBorder, width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppSpacing.iconRadius),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bg;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bg,
  });
}
