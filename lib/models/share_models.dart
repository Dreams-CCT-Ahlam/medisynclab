/// Models for the "Share with Doctor" feature.
///
/// A [HealthShare] is a time-limited, read-only grant of some of the user's
/// health records. Everything here is plain data — there is deliberately NO AI
/// analysis, no insight generation, and no network call. Shares are stored
/// locally (shared_preferences) and each one carries a *snapshot* of the shared
/// records so a recipient can view them without any Pod access.
library;

/// How long a share stays valid after it's created.
enum ShareDuration { oneHour, oneDay, oneWeek }

extension ShareDurationX on ShareDuration {
  /// The actual time window this option represents.
  Duration get duration {
    switch (this) {
      case ShareDuration.oneHour:
        return const Duration(hours: 1);
      case ShareDuration.oneDay:
        return const Duration(days: 1);
      case ShareDuration.oneWeek:
        return const Duration(days: 7);
    }
  }

  /// Short human label for the selector.
  String get label {
    switch (this) {
      case ShareDuration.oneHour:
        return '1 hour';
      case ShareDuration.oneDay:
        return '1 day';
      case ShareDuration.oneWeek:
        return '1 week';
    }
  }

  /// Stable key persisted in storage (so labels can change without breaking
  /// saved shares).
  String get storageKey => name;

  static ShareDuration fromStorageKey(String key) {
    return ShareDuration.values.firstWhere(
      (d) => d.name == key,
      orElse: () => ShareDuration.oneDay,
    );
  }
}

/// A single health record captured at share time.
///
/// We store the display fields and the raw Turtle so the recipient view can
/// render exactly what was shared, with no live Pod read.
class SharedRecord {
  SharedRecord({
    required this.fileName,
    required this.fields,
    required this.raw,
  });

  /// The Pod file name, e.g. `daily_log_2026_07_14.ttl`.
  final String fileName;

  /// Human-readable key/value fields (underscore-prefixed internals removed).
  final Map<String, String> fields;

  /// The raw Turtle body, shown in a read-only code block.
  final String raw;

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'fields': fields,
        'raw': raw,
      };

  factory SharedRecord.fromJson(Map<String, dynamic> json) {
    final rawFields = (json['fields'] as Map?) ?? const {};
    return SharedRecord(
      fileName: (json['fileName'] ?? '') as String,
      fields: rawFields.map((k, v) => MapEntry('$k', '$v')),
      raw: (json['raw'] ?? '') as String,
    );
  }
}

/// A time-limited, read-only share of health records with one recipient.
class HealthShare {
  HealthShare({
    required this.token,
    required this.recipientEmail,
    required this.createdAt,
    required this.expiresAt,
    required this.records,
    this.revoked = false,
  });

  /// Unique, unguessable identifier (UUID v4) — used in the shareable link.
  final String token;

  final String recipientEmail;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Snapshot of the shared records at creation time.
  final List<SharedRecord> records;

  /// Whether the sharer has manually revoked access early.
  bool revoked;

  /// True once the expiration time has passed (evaluated against [now]).
  bool isExpired([DateTime? now]) =>
      (now ?? DateTime.now()).isAfter(expiresAt);

  /// A share is usable only while it is neither revoked nor expired.
  bool isActive([DateTime? now]) => !revoked && !isExpired(now);

  /// Time left before expiry; clamped to zero once past.
  Duration remaining([DateTime? now]) {
    final diff = expiresAt.difference(now ?? DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'recipientEmail': recipientEmail,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'records': records.map((r) => r.toJson()).toList(),
        'revoked': revoked,
      };

  factory HealthShare.fromJson(Map<String, dynamic> json) {
    final rawRecords = (json['records'] as List?) ?? const [];
    return HealthShare(
      token: (json['token'] ?? '') as String,
      recipientEmail: (json['recipientEmail'] ?? '') as String,
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      expiresAt: DateTime.tryParse('${json['expiresAt']}') ?? DateTime.now(),
      records: rawRecords
          .whereType<Map>()
          .map((r) => SharedRecord.fromJson(r.cast<String, dynamic>()))
          .toList(),
      revoked: (json['revoked'] ?? false) as bool,
    );
  }
}

/// Format a [Duration] as a compact human string, e.g. "2d 3h 15m" or
/// "45m 12s". Used by countdown displays. No AI, just arithmetic.
String formatRemaining(Duration d) {
  if (d <= Duration.zero) return 'Expired';

  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;

  final parts = <String>[];
  if (days > 0) parts.add('${days}d');
  if (hours > 0) parts.add('${hours}h');
  // Show minutes unless we're already measuring in days.
  if (days == 0 && minutes > 0) parts.add('${minutes}m');
  // Only surface seconds when the whole thing is under an hour.
  if (days == 0 && hours == 0) parts.add('${seconds}s');

  return parts.join(' ');
}
