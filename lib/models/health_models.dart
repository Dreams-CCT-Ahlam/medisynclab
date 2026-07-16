import 'package:flutter/material.dart';

/// A single day's worth of health data, aggregated from one or more Pod files.
///
/// Charts and the health score are built entirely from a list of these.
class HealthPoint {
  HealthPoint({
    required this.date,
    this.sleepHours,
    this.steps,
  });

  /// The day this point represents (time-of-day is ignored / normalized away).
  final DateTime date;

  /// Hours slept, if recorded.
  final double? sleepHours;

  /// Step count, if recorded.
  final int? steps;

  /// Short weekday label for chart axes, e.g. "Mon".
  String get weekdayLabel {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(date.weekday - 1).clamp(0, 6)];
  }
}

/// Status buckets used for color-coded badges and score bands.
enum HealthLevel { excellent, good, needsAttention }

extension HealthLevelStyle on HealthLevel {
  Color get color {
    switch (this) {
      case HealthLevel.excellent:
        return const Color(0xFF10B981); // green
      case HealthLevel.good:
        return const Color(0xFFF59E0B); // yellow
      case HealthLevel.needsAttention:
        return const Color(0xFFEF4444); // red
    }
  }

  String get icon {
    switch (this) {
      case HealthLevel.excellent:
        return '✓';
      case HealthLevel.good:
        return '⚠️';
      case HealthLevel.needsAttention:
        return '❌';
    }
  }

  String get label {
    switch (this) {
      case HealthLevel.excellent:
        return 'EXCELLENT';
      case HealthLevel.good:
        return 'GOOD';
      case HealthLevel.needsAttention:
        return 'NEEDS ATTENTION';
    }
  }
}

/// The direction health metrics are trending over the available window.
enum HealthTrend { improving, declining, stable }

extension HealthTrendStyle on HealthTrend {
  String get arrow {
    switch (this) {
      case HealthTrend.improving:
        return '↗️';
      case HealthTrend.declining:
        return '↘️';
      case HealthTrend.stable:
        return '→';
    }
  }

  String get label {
    switch (this) {
      case HealthTrend.improving:
        return 'Improving';
      case HealthTrend.declining:
        return 'Declining';
      case HealthTrend.stable:
        return 'Stable';
    }
  }
}

/// An overall 0–100 health score, its component sub-scores, and presentation
/// helpers (10-point scale, star rating, trend).
class HealthScore {
  HealthScore({
    required this.sleepScore,
    required this.stepsScore,
    required this.consistencyScore,
    required this.trend,
  });

  final double sleepScore; // 0–100
  final double stepsScore; // 0–100
  final double consistencyScore; // 0–100
  final HealthTrend trend;

  /// Overall score on a 0–100 scale.
  double get overall =>
      ((sleepScore + stepsScore + consistencyScore) / 3).clamp(0, 100);

  /// Overall score on a 0–10 scale, e.g. 8.5.
  double get outOfTen => overall / 10;

  /// Whole-star rating out of 5.
  int get stars => (overall / 20).round().clamp(0, 5);

  HealthLevel get level {
    if (overall >= 75) return HealthLevel.excellent;
    if (overall >= 50) return HealthLevel.good;
    return HealthLevel.needsAttention;
  }
}
