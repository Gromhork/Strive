import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strive/features/shell/reminder_sync.dart';

void main() {
  test('no hydration reminder is scheduled anywhere in the app', () {
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      if (f.path.contains('${Platform.pathSeparator}gen${Platform.pathSeparator}')) continue;
      final src = f.readAsStringSync();
      expect(src.contains('scheduleHydration'), isFalse, reason: f.path);
      expect(RegExp(r"_details\('hydration'").hasMatch(src), isFalse, reason: f.path);
    }
  });

  test('upgrade: old hydration reminders are cancelled once and their settings dropped', () async {
    SharedPreferences.setMockInitialValues({'hydration': true, 'hydrationInterval': 2, 'vibrate': true});
    final prefs = await SharedPreferences.getInstance();
    var cancels = 0;
    Future<void> cancel() async => cancels++;
    expect(await clearLegacyHydration(prefs, cancel), isTrue);
    expect(cancels, 1);
    expect(prefs.containsKey('hydration'), isFalse);
    expect(prefs.containsKey('hydrationInterval'), isFalse);
    expect(prefs.getBool('vibrate'), isTrue);
    // Next sync: nothing left to do.
    expect(await clearLegacyHydration(prefs, cancel), isFalse);
    expect(cancels, 1);
  });

  test('fresh install: nothing to cancel', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var cancels = 0;
    expect(await clearLegacyHydration(prefs, () async => cancels++), isFalse);
    expect(cancels, 0);
  });
}
