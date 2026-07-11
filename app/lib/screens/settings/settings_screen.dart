import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/cat_session.dart';
import '../../models/cat_profile.dart';
import '../../models/system_status.dart';
import '../../services/firebase_service.dart';
import '../../widgets/cat_switcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _lowFoodAlert = true;
  bool _lowWaterAlert = true;
  bool _feedingCompleteAlert = true;
  bool _unrecognizedAnimalAlert = true;
  bool _deviceOfflineAlert = true;
  double _defaultPortion = 30;
  String? _callSoundUrl;
  bool _isUploadingSound = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseService _firebaseService = FirebaseService();

  String? _catId;

  /// Re-loads settings whenever the selected cat changes (this also fires
  /// once right after initState with the initial selection).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = CatSessionScope.of(context);
    final newCatId = session.currentCatId;

    if (newCatId != _catId) {
      _catId = newCatId;
      if (_catId != null) _loadSettings(_catId!);
    }
  }

  Future<void> _loadSettings(String catId) async {
    final doc =
        await FirebaseFirestore.instance.collection('settings').doc(catId).get();

    if (!doc.exists) return;
    if (!mounted || _catId != catId) return;

    final data = doc.data()!;

    setState(() {
      _notificationsEnabled = data['notifications_enabled'] ?? true;
      _lowFoodAlert = data['low_food_alert'] ?? true;
      _lowWaterAlert = data['low_water_alert'] ?? true;
      _feedingCompleteAlert = data['feeding_complete_alert'] ?? true;
      _unrecognizedAnimalAlert = data['unrecognized_animal_alert'] ?? true;
      _deviceOfflineAlert = data['device_offline_alert'] ?? true;
      _defaultPortion = (data['default_portion'] ?? 30).toDouble();
      _callSoundUrl = data['call_sound_url'];
    });
  }

  Future<void> _saveSettings() async {
    final catId = _catId;
    if (catId == null) return;

    await _firebaseService.updateCatSettings(catId, {
      'notifications_enabled': _notificationsEnabled,
      'low_food_alert': _lowFoodAlert,
      'low_water_alert': _lowWaterAlert,
      'feeding_complete_alert': _feedingCompleteAlert,
      'unrecognized_animal_alert': _unrecognizedAnimalAlert,
      'device_offline_alert': _deviceOfflineAlert,
      'default_portion': _defaultPortion,
      'call_sound_url': _callSoundUrl,
    });
  }

  Future<void> _uploadCallSound() async {
    final catId = _catId;
    if (catId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result == null) return;

    setState(() => _isUploadingSound = true);

    try {
      final file = File(result.files.single.path!);

      final ref =
          FirebaseStorage.instance.ref().child('cat_sounds/$catId.mp3');

      await ref.putFile(file);

      final url = await ref.getDownloadURL();

      await _firebaseService.updateCatSettings(catId, {
        'call_sound_url': url,
      });

      if (!mounted) return;
      setState(() {
        _callSoundUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sound uploaded successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
        ),
      );
    }

    if (mounted) setState(() => _isUploadingSound = false);
  }

  Future<void> _previewSound() async {
    if (_callSoundUrl == null) return;

    await _audioPlayer.setUrl(_callSoundUrl!);
    await _audioPlayer.play();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Device',
              children: [
                _buildPiStatusTile(),
                const _SettingsTile(
                  icon: Icons.cloud_sync_outlined,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primaryLight,
                  title: 'Firebase Sync',
                  subtitle: 'Realtime sync active',
                  trailing: SizedBox.shrink(),
                ),
                _buildNetworkTile(),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildSection(
              title: 'Notifications',
              children: [
                _SwitchTile(
                  icon: Icons.notifications_outlined,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primaryLight,
                  title: 'Push Notifications',
                  subtitle: 'Enable all alerts',
                  value: _notificationsEnabled,
                  onChanged: (v) {
                    setState(() => _notificationsEnabled = v);
                    _saveSettings();
                  },
                ),
                _SwitchTile(
                  icon: Icons.set_meal_outlined,
                  iconColor: AppColors.warning,
                  iconBg: AppColors.warningLight,
                  title: 'Low Food Alert',
                  subtitle: 'Notify when food is below 30%',
                  value: _lowFoodAlert,
                  onChanged: _notificationsEnabled
                      ? (v) {
                          setState(() => _lowFoodAlert = v);
                          _saveSettings();
                        }
                      : null,
                ),
                _SwitchTile(
                  icon: Icons.water_drop_outlined,
                  iconColor: const Color(0xFF38BDF8),
                  iconBg: const Color(0xFFE0F5FE),
                  title: 'Low Water Alert',
                  subtitle: 'Notify when water is below 40%',
                  value: _lowWaterAlert,
                  onChanged: _notificationsEnabled
                      ? (v) {
                          setState(() => _lowWaterAlert = v);
                          _saveSettings();
                        }
                      : null,
                ),
                _SwitchTile(
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.success,
                  iconBg: AppColors.successLight,
                  title: 'Feeding Complete',
                  subtitle: 'Notify after each feeding',
                  value: _feedingCompleteAlert,
                  onChanged: _notificationsEnabled
                      ? (v) {
                          setState(() => _feedingCompleteAlert = v);
                          _saveSettings();
                        }
                      : null,
                ),
                _SwitchTile(
                  icon: Icons.pets,
                  iconColor: AppColors.error,
                  iconBg: AppColors.errorLight,
                  title: 'Unrecognized Animal',
                  subtitle: 'Alert on unknown animal detection',
                  value: _unrecognizedAnimalAlert,
                  onChanged: _notificationsEnabled
                      ? (v) {
                          setState(() => _unrecognizedAnimalAlert = v);
                          _saveSettings();
                        }
                      : null,
                ),
                _SwitchTile(
                  icon: Icons.wifi_off_outlined,
                  iconColor: AppColors.error,
                  iconBg: AppColors.errorLight,
                  title: 'Device Offline',
                  subtitle: 'Alert when feeder disconnects',
                  value: _deviceOfflineAlert,
                  onChanged: _notificationsEnabled
                      ? (v) {
                          setState(() => _deviceOfflineAlert = v);
                          _saveSettings();
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildSection(
              title: 'Feeding Preferences',
              children: [
                _buildPortionTile(),
                _buildCallSoundTile(),
                _buildRegisteredCatsTile(),
                const _SettingsTile(
                  icon: Icons.history_outlined,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primaryLight,
                  title: 'Log Retention',
                  subtitle: 'Keep logs for 30 days',
                  trailing: Icon(Icons.chevron_right,
                      color: AppColors.textHint, size: 20),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildSection(
              title: 'About',
              children: [
                const _SettingsTile(
                  icon: Icons.info_outline,
                  iconColor: AppColors.textSecondary,
                  iconBg: AppColors.surfaceVariant,
                  title: 'App Version',
                  subtitle: '1.0.0 (Build 1)',
                  trailing: SizedBox.shrink(),
                ),
                const _SettingsTile(
                  icon: Icons.memory_outlined,
                  iconColor: AppColors.textSecondary,
                  iconBg: AppColors.surfaceVariant,
                  title: 'Firmware Version',
                  subtitle: 'Pi v0.9.1',
                  trailing: SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Widget _buildPiStatusTile() {
    final catId = _catId;
    if (catId == null) return const SizedBox.shrink();

    return StreamBuilder<SystemStatus>(
      stream: _firebaseService.watchSystemStatus(catId),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final online = status?.piOnline ?? false;

        final subtitle = status == null
            ? 'Loading...'
            : online
                ? (status.ipAddress != null
                    ? 'Connected  •  IP: ${status.ipAddress}'
                    : 'Connected  •  IP not reported by device')
                : 'Disconnected';

        return GestureDetector(
          onTap: status == null ? null : () => _showDeviceDetails(status),
          child: _SettingsTile(
            icon: Icons.developer_board_outlined,
            iconColor: online ? AppColors.success : AppColors.error,
            iconBg: online ? AppColors.successLight : AppColors.errorLight,
            title: 'Raspberry Pi Status',
            subtitle: subtitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: online ? AppColors.online : AppColors.offline,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.chevron_right,
                    color: AppColors.textHint, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNetworkTile() {
    final catId = _catId;
    if (catId == null) return const SizedBox.shrink();

    return StreamBuilder<SystemStatus>(
      stream: _firebaseService.watchSystemStatus(catId),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final online = status?.piOnline ?? false;

        final subtitle = status == null
            ? 'Loading...'
            : '${online ? 'Connected' : 'Disconnected'}  •  '
                'Last synced ${_formatRelativeTime(status.lastUpdated)}';

        return GestureDetector(
          onTap: status == null ? null : () => _showDeviceDetails(status),
          child: _SettingsTile(
            icon: Icons.wifi_outlined,
            iconColor: online ? AppColors.success : AppColors.error,
            iconBg: online ? AppColors.successLight : AppColors.errorLight,
            title: 'Network',
            subtitle: subtitle,
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.textHint, size: 20),
          ),
        );
      },
    );
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showDeviceDetails(SystemStatus status) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        title: Text('Device Status', style: AppTextStyles.headlineMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              'Status',
              status.piOnline ? 'Connected' : 'Disconnected',
            ),
            _buildDetailRow(
              'IP Address',
              status.ipAddress ?? 'Not reported by device',
            ),
            _buildDetailRow(
              'Last synced',
              _formatRelativeTime(status.lastUpdated),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          const SizedBox(width: AppSpacing.lg),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.titleSmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisteredCatsTile() {
    return StreamBuilder<List<CatProfile>>(
      stream: _firebaseService.watchCats(),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;

        return GestureDetector(
          onTap: () => CatSwitcher.open(context, _firebaseService),
          child: _SettingsTile(
            icon: Icons.pets,
            iconColor: AppColors.primary,
            iconBg: AppColors.primaryLight,
            title: 'Registered Cats',
            subtitle: count == 1 ? '1 cat registered' : '$count cats registered',
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.textHint, size: 20),
          ),
        );
      },
    );
  }

  Widget _buildCallSoundTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppSpacing.iconRadius - 2),
            ),
            child: const Icon(
              Icons.volume_up_outlined,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cat Call Sound',
                  style: AppTextStyles.titleSmall,
                ),
                Text(
                  _callSoundUrl == null
                      ? 'No sound uploaded'
                      : 'Custom sound uploaded',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          if (_callSoundUrl != null)
            IconButton(
              onPressed: _previewSound,
              icon: const Icon(Icons.play_arrow),
            ),
          TextButton(
            onPressed: _isUploadingSound ? null : _uploadCallSound,
            child: Text(
              _isUploadingSound ? 'Uploading...' : 'Upload',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortionTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.iconRadius - 2),
                ),
                child: const Icon(Icons.scale_outlined,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Default Portion Size',
                        style: AppTextStyles.titleSmall),
                    Text(
                      '${_defaultPortion.toStringAsFixed(0)}g per feeding',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
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
                  '${_defaultPortion.toStringAsFixed(0)}g',
                  style: AppTextStyles.titleSmall
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
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
              value: _defaultPortion,
              min: 10,
              max: 100,
              divisions: 18,
              onChanged: (v) {
                setState(() => _defaultPortion = v);
                _saveSettings();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10g', style: AppTextStyles.labelSmall),
              Text('100g', style: AppTextStyles.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.md,
          ),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.cardBorder, width: 1),
          ),
          child: Column(
            children: List.generate(children.length, (index) {
              final isLast = index == children.length - 1;
              return Column(
                children: [
                  children[index],
                  if (!isLast)
                    const Divider(height: 1, indent: 56, endIndent: 0),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppSpacing.iconRadius - 2),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onChanged == null;

    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppSpacing.iconRadius - 2),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleSmall),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primaryLight,
            ),
          ],
        ),
      ),
    );
  }
}
