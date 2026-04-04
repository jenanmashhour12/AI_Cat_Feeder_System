class FeedingSchedule {
  final String id;
  final String label;
  final int hour;
  final int minute;
  final double portionGrams;
  final bool isEnabled;
  final List<bool> activeDays;

  const FeedingSchedule({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    required this.portionGrams,
    required this.isEnabled,
    required this.activeDays,
  });

  String get formattedTime {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String get activeDaysLabel {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final selected = <String>[];
    for (int i = 0; i < 7; i++) {
      if (activeDays[i]) selected.add(names[i]);
    }
    if (selected.length == 7) return 'Every day';
    if (selected.length == 5 && !activeDays[5] && !activeDays[6]) {
      return 'Weekdays';
    }
    if (selected.length == 2 && activeDays[5] && activeDays[6]) {
      return 'Weekends';
    }
    if (selected.isEmpty) return 'No days selected';
    return selected.join(', ');
  }

  FeedingSchedule copyWith({
    String? id,
    String? label,
    int? hour,
    int? minute,
    double? portionGrams,
    bool? isEnabled,
    List<bool>? activeDays,
  }) {
    return FeedingSchedule(
      id: id ?? this.id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      portionGrams: portionGrams ?? this.portionGrams,
      isEnabled: isEnabled ?? this.isEnabled,
      activeDays: activeDays ?? this.activeDays,
    );
  }
}
