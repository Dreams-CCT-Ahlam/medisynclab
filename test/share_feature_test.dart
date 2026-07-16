// Tests for the "Share with Doctor" feature.
//
// These exercise the real ShareService (backed by mocked SharedPreferences),
// the HealthShare model, and the RecipientView / ShareHistory screens — no
// network and no AI. This is the observable verification of the feature that
// can run headlessly in CI.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medisync/models/share_models.dart';
import 'package:medisync/services/share_service.dart';
import 'package:medisync/screens/recipient_view_screen.dart';
import 'package:medisync/screens/share_history_screen.dart';

SharedRecord _sampleRecord() => SharedRecord(
      fileName: 'daily_log.ttl',
      fields: const {'sleepHours': '7.5', 'steps': '8200'},
      raw: '<> a ex:HealthData ; ex:steps 8200 .',
    );

void main() {
  setUp(() {
    // Fresh, empty local storage for every test.
    SharedPreferences.setMockInitialValues({});
  });

  group('HealthShare model', () {
    test('JSON round-trip preserves all fields', () {
      final created = DateTime(2026, 7, 15, 10);
      final original = HealthShare(
        token: 'tok-123',
        recipientEmail: 'doc@clinic.com',
        createdAt: created,
        expiresAt: created.add(const Duration(days: 1)),
        records: [_sampleRecord()],
      );

      final restored = HealthShare.fromJson(original.toJson());

      expect(restored.token, 'tok-123');
      expect(restored.recipientEmail, 'doc@clinic.com');
      expect(restored.createdAt, created);
      expect(restored.records.single.fileName, 'daily_log.ttl');
      expect(restored.records.single.fields['steps'], '8200');
      expect(restored.revoked, isFalse);
    });

    test('active / expired / revoked states are correct', () {
      final now = DateTime(2026, 7, 15, 12);
      final live = HealthShare(
        token: 't',
        recipientEmail: 'a@b.com',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        records: const [],
      );
      expect(live.isActive(now), isTrue);
      expect(live.isExpired(now), isFalse);
      expect(live.remaining(now), const Duration(hours: 1));

      final expired = HealthShare(
        token: 't2',
        recipientEmail: 'a@b.com',
        createdAt: now.subtract(const Duration(days: 2)),
        expiresAt: now.subtract(const Duration(days: 1)),
        records: const [],
      );
      expect(expired.isExpired(now), isTrue);
      expect(expired.isActive(now), isFalse);
      expect(expired.remaining(now), Duration.zero);

      live.revoked = true;
      expect(live.isActive(now), isFalse);
    });

    test('formatRemaining renders human strings', () {
      expect(formatRemaining(Duration.zero), 'Expired');
      expect(formatRemaining(const Duration(minutes: 45, seconds: 12)),
          '45m 12s');
      expect(
          formatRemaining(const Duration(days: 2, hours: 3, minutes: 30)),
          '2d 3h');
      expect(formatRemaining(const Duration(seconds: 5)), '5s');
    });

    test('ShareDuration maps to the right windows', () {
      expect(ShareDuration.oneHour.duration, const Duration(hours: 1));
      expect(ShareDuration.oneDay.duration, const Duration(days: 1));
      expect(ShareDuration.oneWeek.duration, const Duration(days: 7));
    });
  });

  group('ShareService', () {
    test('create persists a share with a unique token and expiry', () async {
      final service = ShareService();
      await service.load();
      final now = DateTime(2026, 7, 15, 9);

      final share = await service.createShare(
        recipientEmail: 'doc@clinic.com',
        duration: ShareDuration.oneDay,
        records: [_sampleRecord()],
        now: now,
      );

      expect(share.token, isNotEmpty);
      expect(share.expiresAt, now.add(const Duration(days: 1)));
      expect(service.shares, hasLength(1));

      // A second service instance sees the persisted share (storage works).
      final reopened = ShareService();
      await reopened.load();
      expect(reopened.shares, hasLength(1));
      expect(reopened.shares.single.recipientEmail, 'doc@clinic.com');
    });

    test('findByToken works before load() (fresh recipient link)', () async {
      final writer = ShareService();
      await writer.load();
      final share = await writer.createShare(
        recipientEmail: 'doc@clinic.com',
        duration: ShareDuration.oneHour,
        records: [_sampleRecord()],
      );

      // Simulate a recipient who never called load().
      final recipientService = ShareService();
      final found = await recipientService.findByToken(share.token);
      expect(found, isNotNull);
      expect(found!.recipientEmail, 'doc@clinic.com');

      final missing = await recipientService.findByToken('nope');
      expect(missing, isNull);
    });

    test('revoke deactivates but keeps history; delete removes it', () async {
      final service = ShareService();
      await service.load();
      final share = await service.createShare(
        recipientEmail: 'doc@clinic.com',
        duration: ShareDuration.oneWeek,
        records: [_sampleRecord()],
      );

      await service.revoke(share.token);
      expect(service.shares.single.revoked, isTrue);
      expect(service.activeShares(), isEmpty);

      await service.delete(share.token);
      expect(service.shares, isEmpty);
    });
  });

  Widget wrap(ShareService service, Widget child) {
    return ChangeNotifierProvider<ShareService>.value(
      value: service,
      child: MaterialApp(home: child),
    );
  }

  group('RecipientViewScreen', () {
    testWidgets('shows shared data and expiry for a valid link',
        (tester) async {
      final service = ShareService();
      await service.load();
      final share = await service.createShare(
        recipientEmail: 'doc@clinic.com',
        duration: ShareDuration.oneDay,
        records: [_sampleRecord()],
      );

      await tester.pumpWidget(wrap(service, RecipientViewScreen(token: share.token)));
      await tester.pump(); // resolve findByToken future

      expect(find.text('Shared health records'), findsOneWidget);
      expect(find.textContaining('Access expires in'), findsOneWidget);
      expect(find.text('daily_log.ttl'), findsOneWidget);
      expect(find.text('sleepHours'), findsOneWidget);
      expect(find.text('7.5'), findsOneWidget);
    });

    testWidgets('denies an unknown token', (tester) async {
      final service = ShareService();
      await service.load();

      await tester.pumpWidget(
          wrap(service, const RecipientViewScreen(token: 'does-not-exist')));
      await tester.pump();

      expect(find.text('Link not found'), findsOneWidget);
      expect(find.text('Shared health records'), findsNothing);
    });

    testWidgets('denies a revoked link', (tester) async {
      final service = ShareService();
      await service.load();
      final share = await service.createShare(
        recipientEmail: 'doc@clinic.com',
        duration: ShareDuration.oneDay,
        records: [_sampleRecord()],
      );
      await service.revoke(share.token);

      await tester.pumpWidget(
          wrap(service, RecipientViewScreen(token: share.token)));
      await tester.pump();

      expect(find.text('Access revoked'), findsOneWidget);
    });
  });

  group('ShareHistoryScreen', () {
    testWidgets('lists an active share with countdown', (tester) async {
      final service = ShareService();
      await service.load();
      await service.createShare(
        recipientEmail: 'doc@clinic.com',
        duration: ShareDuration.oneDay,
        records: [_sampleRecord()],
      );

      await tester.pumpWidget(wrap(service, const ShareHistoryScreen()));
      await tester.pump();

      expect(find.text('doc@clinic.com'), findsOneWidget);
      expect(find.textContaining('Expires in'), findsOneWidget);
      expect(find.text('Revoke'), findsOneWidget);
    });
  });
}
