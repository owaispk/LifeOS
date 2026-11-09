// Runs before every test file (Flutter's test config hook).
//
// The test device's region is pinned so fixtures are stable: a Pakistani
// phone in English → "Rs", Monday weeks, "9 Nov" (PBI-035). Tests that
// cover other regions pass their own locale to `resolveRegion`.
import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_app/core/region.dart';

const testDeviceLocale = Locale('en', 'PK');

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppRegion.deviceLocale = testDeviceLocale;
  // Every test starts from the phone's defaults, whatever the last one set.
  setUp(() => AppRegion.current = resolveRegion(testDeviceLocale));
  await testMain();
}
