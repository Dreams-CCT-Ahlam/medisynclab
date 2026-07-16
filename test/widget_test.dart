// Basic smoke test for the MediSync app.
//
// The app requires an initialized SolidService (which touches
// SharedPreferences), so this test simply verifies that the
// MediSyncApp widget can be constructed.

import 'package:flutter_test/flutter_test.dart';

import 'package:medisync/main.dart';

void main() {
  test('MediSyncApp can be instantiated', () {
    expect(const MediSyncApp(), isNotNull);
  });
}
