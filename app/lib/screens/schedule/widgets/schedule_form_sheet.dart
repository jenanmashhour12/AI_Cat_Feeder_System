import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/feeding_schedule.dart';

class ScheduleFormSheet extends StatefulWidget {
  final FeedingSchedule? existing;
  final void Function(FeedingSchedule) onSave;

  const ScheduleFormSheet({
    super.key,
    this.existing,
    required this.onSave,
  });

  @override
  State<ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends State<ScheduleFormSheet> {
  late final TextEditingController _labelController;
  late TimeOfDay _selectedTime;
  late double _portionGrams;
  late List<bool> _activeDays;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelController = TextEditingController(text: e?.label ?? '');
    _selectedTime =
        e != null ? TimeOfDay(hour: e.hour, minute: e.minute) : TimeOfDay.now();
    _portionGrams = e?.portionGrams ?? 30;
    _activeDays = e?.activeDays.toList() ?? List.generate(7, (_) => true);
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String _formattedTime() {
    final h = _selectedTime.hour % 12 == 0 ? 12 : _selectedTime.hour % 12;
    final m = _selectedTime.minute.toString().padLeft(2, '0');
    final period = _selectedTime.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _autoLabel() {
    final h = _selectedTime.hour;
    if (h < 12) return 'Morning Feeding';
    if (h < 17) return 'Afternoon Feeding';
    return 'Evening Feeding';
  }

  void _save() {
    final label = _labelController.text.trim().isEmpty
        ? _autoLabel()
        : _labelController.text.trim();

    final schedule = FeedingSchedule(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      portionGrams: _portionGrams,
      isEnabled: widget.existing?.isEnabled ?? true,
      activeDays: List.from(_activeDays),
    );

    widget.onSave(schedule);
    Navigator.of(context).pop();
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
            _buildHandle(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _isEditing ? 'Edit Schedule' : 'New Schedule',
              style: AppTextStyles.displayMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildTimePicker(),
            const SizedBox(height: AppSpacing.xl),
            _buildLabelField(),
            const SizedBox(height: AppSpacing.xl),
            _buildPortionSlider(),
            const SizedBox(height: AppSpacing.xl),
            _buildDaySelector(),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(_isEditing ? 'Save Changes' : 'Add Schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Feeding Time', style: AppTextStyles.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: _pickTime,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: AppSpacing.md),
                Text(
                  _formattedTime(),
                  style: AppTextStyles.displayMedium
                      .copyWith(color: AppColors.primary),
                ),
                const Spacer(),
                Text(
                  'Tap to change',
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Label (optional)', style: AppTextStyles.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _labelController,
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Morning Feeding',
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
      ],
    );
  }

  Widget _buildPortionSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Portion Size', style: AppTextStyles.titleSmall),
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
                '${_portionGrams.toStringAsFixed(0)}g',
                style:
                    AppTextStyles.titleSmall.copyWith(color: AppColors.primary),
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
            value: _portionGrams,
            min: 10,
            max: 100,
            divisions: 18,
            onChanged: (v) => setState(() => _portionGrams = v),
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
    );
  }

  Widget _buildDaySelector() {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Repeat On', style: AppTextStyles.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final active = _activeDays[i];
            return GestureDetector(
              onTap: () => setState(() => _activeDays[i] = !_activeDays[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: active ? AppColors.primary : AppColors.cardBorder,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  dayLabels[i].substring(0, 1),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: active ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
