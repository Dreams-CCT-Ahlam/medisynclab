import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/share_models.dart';

/// ShareService manages "Share with Doctor" grants entirely on-device.
///
/// Shares are persisted to shared_preferences as JSON. There is intentionally
/// NO Claude/AI involvement anywhere in this class — creating, listing,
/// revoking, and looking up shares are all plain local operations. The heavy
/// data (the record snapshot) is captured by the caller and simply stored.
class ShareService extends ChangeNotifier {
  ShareService({SharedPreferences? prefs}) : _prefs = prefs;

  static const String _storageKey = 'medisync_shares';
  static const _uuid = Uuid();

  SharedPreferences? _prefs;

  /// In-memory cache of all shares, newest first. Populated by [load].
  List<HealthShare> _shares = [];
  List<HealthShare> get shares => List.unmodifiable(_shares);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Load all shares from local storage into memory.
  Future<void> load() async {
    final prefs = await _store;
    final raw = prefs.getString(_storageKey);
    _shares = _decode(raw);
    _sort();
    _loaded = true;
    notifyListeners();
  }

  /// All shares that are still active (not revoked, not expired).
  List<HealthShare> activeShares([DateTime? now]) =>
      _shares.where((s) => s.isActive(now)).toList();

  /// Create a new share, persist it, and return it.
  ///
  /// [records] is the snapshot of the selected data captured by the caller.
  /// No network call and no AI — a UUID token is generated locally.
  Future<HealthShare> createShare({
    required String recipientEmail,
    required ShareDuration duration,
    required List<SharedRecord> records,
    DateTime? now,
  }) async {
    final created = now ?? DateTime.now();
    final share = HealthShare(
      token: _uuid.v4(),
      recipientEmail: recipientEmail.trim(),
      createdAt: created,
      expiresAt: created.add(duration.duration),
      records: records,
    );

    _shares.insert(0, share);
    await _persist();
    notifyListeners();
    return share;
  }

  /// Revoke a share by token (keeps it in history, marked revoked).
  Future<void> revoke(String token) async {
    for (final s in _shares) {
      if (s.token == token) s.revoked = true;
    }
    await _persist();
    notifyListeners();
  }

  /// Permanently remove a share from history.
  Future<void> delete(String token) async {
    _shares.removeWhere((s) => s.token == token);
    await _persist();
    notifyListeners();
  }

  /// Look up a single share by token — used by the recipient view.
  ///
  /// Reads straight from storage so it works even if [load] hasn't run in this
  /// part of the app (e.g. a freshly-opened recipient link). Returns null if
  /// the token is unknown.
  Future<HealthShare?> findByToken(String token) async {
    if (_loaded) {
      for (final s in _shares) {
        if (s.token == token) return s;
      }
      return null;
    }
    final prefs = await _store;
    final all = _decode(prefs.getString(_storageKey));
    for (final s in all) {
      if (s.token == token) return s;
    }
    return null;
  }

  // ── internals ─────────────────────────────────────────────────────────────

  List<HealthShare> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => HealthShare.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      // Corrupt/legacy data shouldn't crash the app — start fresh.
      return [];
    }
  }

  Future<void> _persist() async {
    _sort();
    final prefs = await _store;
    final encoded = jsonEncode(_shares.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  void _sort() {
    _shares.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
