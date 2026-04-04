import 'package:flutter/material.dart';

class ActionResult {
  final bool success;
  final String message;
  final String time;
  final IconData icon;
  final Color color;
  final Color bg;

  const ActionResult({
    required this.success,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
    required this.bg,
  });
}
