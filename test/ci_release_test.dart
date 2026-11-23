// Guards for the GitHub Actions release pipeline (.github/workflows/release.yml) and the owner
// guide docs/ci-release.md: tag filter, early version check, safe key.properties and the
// data-safety notes before uninstalling.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

/// Decodes a single-line java.util.Properties value (what Gradle sees in key.properties).
String _decodePropertiesValue(String raw) {
  var i = 0;
  // Properties.load drops leading blanks of a value.
  while (i < raw.length && (raw[i] == ' ' || raw[i] == '\t' || raw[i] == '\f')) {
    i++;
  }
  final out = StringBuffer();
  while (i < raw.length) {
    final c = raw[i++];
    if (c != r'\') {
      out.write(c);
      continue;
    }
    final e = raw[i++];
    switch (e) {
      case 't':
        out.write('\t');
      case 'n':
        out.write('\n');
      case 'r':
        out.write('\r');
      case 'f':
        out.write('\f');
      case 'u':
        out.writeCharCode(int.parse(raw.substring(i, i + 4), radix: 16));
        i += 4;
      default:
        out.write(e);
    }
  }
  return out.toString();
}

/// Runs .github/scripts/write_key_properties.py, or returns null when no Python is installed.
Future<Map<String, String>?> _writeKeyProperties(Map<String, String> env) async {
  final dir = Directory.systemTemp.createTempSync('strive_keyprops');
  addTearDown(() => dir.deleteSync(recursive: true));
  final out = '${dir.path}${Platform.pathSeparator}key.properties';
  for (final python in ['python3', 'python']) {
    final ProcessResult result;
    try {
      result = await Process.run(python, ['-I', '.github/scripts/write_key_properties.py', out], environment: env);
    } on ProcessException {
      continue;
    }
    // The Windows "python3" app-execution alias exists without Python and fails.
    if (result.exitCode != 0 || !File(out).existsSync()) continue;
    final bytes = File(out).readAsBytesSync();
    expect(bytes.every((b) => b < 0x80), isTrue, reason: 'key.properties must be pure ASCII (read as ISO-8859-1)');
    final values = <String, String>{};
    for (final line in String.fromCharCodes(bytes).split('\n').where((l) => l.isNotEmpty)) {
      final eq = line.indexOf('=');
      values[line.substring(0, eq)] = _decodePropertiesValue(line.substring(eq + 1));
    }
    return values;
  }
  return null;
}

void main() {
  final release = _read('.github/workflows/release.yml');
  final docs = _read('docs/ci-release.md');

  test('release workflow only starts for version-like tags', () {
    expect(release, contains("tags: ['v[0-9]*']"));
    expect(release, isNot(contains("tags: ['v*']")));
  });

  test('a wrong tag fails in the version job before the CI checks', () {
    final versionJob = release.indexOf('\n  version:\n');
    final checksJob = release.indexOf('\n  checks:\n');
    final buildJob = release.indexOf('\n  build:\n');
    expect(versionJob, greaterThan(0));
    expect(checksJob, greaterThan(versionJob));
    expect(buildJob, greaterThan(checksJob));
    final versionBody = release.substring(versionJob, checksJob);
    expect(versionBody, contains('does not match pubspec.yaml version'));
    expect(versionBody, isNot(contains('flutter')), reason: 'the version job must stay fast (no Flutter setup)');
    final checksBody = release.substring(checksJob, buildJob);
    expect(checksBody, contains('needs: version'));
    final buildHeader = release.substring(buildJob, release.indexOf('steps:', buildJob));
    expect(buildHeader, contains('needs: [version, checks]'));
    expect(buildHeader, contains("needs.version.result == 'success'"));
    // Version values come from the version job everywhere.
    expect(release, isNot(contains('needs.build.outputs.tag')));
    expect(release.substring(buildJob), isNot(contains('steps.version.outputs.')));
  });

  test('signing checks the key password and never echoes raw passwords into key.properties', () {
    expect(release, contains('java .github/scripts/CheckKey.java android/app/upload-keystore.jks'));
    expect(release, contains('python3 .github/scripts/write_key_properties.py android/key.properties'));
    expect(release, isNot(contains(r'echo "storePassword=')));
    expect(release, isNot(contains(r'echo "keyPassword=')));
    final checkKey = _read('.github/scripts/CheckKey.java');
    expect(checkKey, contains('keyStore.getKey(alias, keyPassword)'));
    expect(checkKey, contains('KEY_PASSWORD'));
  });

  test('key.properties values survive any password characters', () async {
    const store =
        r' a\b=c:d#e!f'
        '\tgä€😀 ';
    const key = r'Ax\\';
    const alias = 'up load';
    final values = await _writeKeyProperties({'KEYSTORE_PASSWORD': store, 'KEY_PASSWORD': key, 'KEY_ALIAS': alias});
    if (values == null) {
      markTestSkipped('no Python interpreter available');
      return;
    }
    expect(values, {'storePassword': store, 'keyPassword': key, 'keyAlias': alias, 'storeFile': 'upload-keystore.jks'});
  });

  test('guide warns before uninstalling instead of promising that data survives', () {
    expect(docs, isNot(contains('Cloud-Daten bleiben\n  erhalten')));
    expect(docs, isNot(contains('Cloud-Daten bleiben erhalten')));
    expect(docs, contains('### Vor dem Deinstallieren'));
    expect(docs, contains('Gastkonto sichern'));
    expect(docs, contains('Online sein'));
    expect(docs, contains('Erinnerungen'));
    // Both uninstall notes link to the checklist.
    expect('(#vor-dem-deinstallieren)'.allMatches(docs).length, greaterThanOrEqualTo(2));
    // Google sign-in does not work in unsigned-debug builds -> e-mail.
    expect(docs, contains('per **E-Mail** anmelden'));
  });

  test('guide explains local build numbers versus CI versionCodes', () {
    expect(docs, contains('--build-number='));
    expect(docs, contains('Downgrade'));
  });
}
