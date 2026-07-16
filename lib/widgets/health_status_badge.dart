import 'package:flutter/material.dart';

import '../models/health_models.dart';

/// A color-coded status pill, e.g. "Sleep: 7.5 hours ✓ EXCELLENT".
///
/// Color alone is never the only signal — every badge also carries an icon
/// glyph and a text label so it stays readable for color-blind users.
class HealthStatusBadge extends StatelessWidget {
  const HealthStatusBadge({
    super.key,
    required this.metricLabel,
    required this.valueLabel,
    required this.level,
  });

  final String metricLabel; // e.g. "Sleep"
  final String valueLabel; // e.g. "7.5 hours"
  final HealthLevel level;

  /// Classify sleep hours into a status band.
  static HealthLevel levelForSleep(double hours) {
    if (hours >= 7) return HealthLevel.excellent;
    if (hours >= 5) return HealthLevel.good;
    return HealthLevel.needsAttention;
  }

  /// Classify a step count into a status band.
  static HealthLevel levelForSteps(int steps) {
    if (steps >= 8000) return HealthLevel.excellent;
    if (steps >= 5000) return HealthLevel.good;
    return HealthLevel.needsAttention;
  }

  @override
  Widget build(BuildContext context) {
    final color = level.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$metricLabel: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFA0AEC0),
                ),
          ),
          Text(
            valueLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFE2E8F0),
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Text(level.icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            level.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }
}
