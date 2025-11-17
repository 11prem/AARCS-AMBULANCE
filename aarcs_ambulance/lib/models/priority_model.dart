// lib/models/priority_model.dart

import 'package:flutter/material.dart';

enum EmergencyPriority {
  critical,  // Priority 1 - Red
  high,      // Priority 2 - Orange
  moderate,  // Priority 3 - Yellow
  low,       // Priority 4 - Green
}

class PriorityConfig {
  final EmergencyPriority priority;
  final String label;
  final String description;
  final Color color;
  final Color backgroundColor;
  final IconData icon;
  final int responseTimeMinutes;

  const PriorityConfig({
    required this.priority,
    required this.label,
    required this.description,
    required this.color,
    required this.backgroundColor,
    required this.icon,
    required this.responseTimeMinutes,
  });

  static PriorityConfig fromPriority(EmergencyPriority priority) {
    switch (priority) {
      case EmergencyPriority.critical:
        return PriorityConfig(
          priority: EmergencyPriority.critical,
          label: 'CRITICAL',
          description: 'Life-threatening emergency',
          color: const Color(0xFFD32F2F),
          backgroundColor: const Color(0xFFFFEBEE),
          icon: Icons.local_fire_department,
          responseTimeMinutes: 5,
        );
      case EmergencyPriority.high:
        return PriorityConfig(
          priority: EmergencyPriority.high,
          label: 'HIGH',
          description: 'Serious injury or illness',
          color: const Color(0xFFFF6F00),
          backgroundColor: const Color(0xFFFFF3E0),
          icon: Icons.warning,
          responseTimeMinutes: 10,
        );
      case EmergencyPriority.moderate:
        return PriorityConfig(
          priority: EmergencyPriority.moderate,
          label: 'MODERATE',
          description: 'Urgent medical attention needed',
          color: const Color(0xFFF9A825),
          backgroundColor: const Color(0xFFFFFDE7),
          icon: Icons.priority_high,
          responseTimeMinutes: 15,
        );
      case EmergencyPriority.low:
        return PriorityConfig(
          priority: EmergencyPriority.low,
          label: 'LOW',
          description: 'Non-urgent medical transport',
          color: const Color(0xFF388E3C),
          backgroundColor: const Color(0xFFE8F5E9),
          icon: Icons.info_outline,
          responseTimeMinutes: 30,
        );
    }
  }

  // Get priority level as integer (0 = highest, 3 = lowest)
  int get level => priority.index;

  // Helper to compare priorities
  bool isHigherThan(EmergencyPriority other) {
    return priority.index < other.index;
  }

  bool isLowerThan(EmergencyPriority other) {
    return priority.index > other.index;
  }
}
