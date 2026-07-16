// Regression test for the AI Coach insight-card layout bug.
//
// The insight card puts a full-height accent bar (CrossAxisAlignment.stretch)
// next to a text column inside a SingleChildScrollView. Without an
// IntrinsicHeight wrapper the Row was given unbounded height and Flutter threw
// "BoxConstraints forces an infinite height". This test renders the REAL
// AiCoachScreen and fails if that assertion returns.
//
// A fake SolidService supplies a cached insight, so NO Claude API call is made.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medisync/services/solid_service.dart';
import 'package:medisync/screens/ai_coach_screen.dart';

/// A SolidService that returns canned data and a pre-cached insight, so the
/// coach screen never touches the network or the AI service.
class _FakeSolidService extends SolidService {
  @override
  Future<List<String>> listHealthData() async => ['entry.ttl'];

  @override
  Future<Map<String, dynamic>?> readHealthData(String fileName) async => {
        'sleepHours': '7.5',
        'steps': '8200',
        '_raw': '<> a ex:HealthData ; ex:steps 8200 .',
      };

  @override
  Future<Map<String, dynamic>?> getCachedInsight(String fileName) async => {
        'insight': 'Great work — your sleep and steps are trending well!',
        'timestamp': '2026-07-15T10:00:00.000',
      };
}

void main() {
  testWidgets('AI Coach insight card lays out without infinite-height error',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fake = _FakeSolidService();

    await tester.pumpWidget(
      ChangeNotifierProvider<SolidService>.value(
        value: fake,
        child: const MaterialApp(home: AiCoachScreen()),
      ),
    );
    // Resolve the FutureBuilder (listHealthData -> readHealthData -> cache).
    await tester.pumpAndSettle();

    // The card rendered with the shared insight, and no exception was thrown
    // during layout (tester surfaces any layout assertion as a test failure).
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('your sleep and steps are trending well'),
      findsOneWidget,
    );
    // Metric chips from the same card confirm the full-height Row laid out.
    expect(find.textContaining('7.5 h sleep'), findsOneWidget);
    expect(find.textContaining('8200 steps'), findsOneWidget);
  });
}
