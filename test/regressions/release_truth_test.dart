import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v1.0.36 release metadata and documentation agree', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final readme = File('README.md').readAsStringSync();
    final releaseNotes = File('RELEASE_NOTES.md').readAsStringSync();
    final changelog = File('CHANGELOG.md').readAsStringSync();

    expect(pubspec, contains('version: 1.0.36+36'));
    expect(readme, contains('version-1.0.36'));
    expect(releaseNotes, contains('v1.0.36'));
    expect(changelog, contains('## [1.0.36] - 2026-08-25'));

    if (!File('LICENSE').existsSync()) {
      expect(readme, isNot(contains('MIT License')));
    }
  });

  test('shipping Dart source excludes known false-success fixtures', () {
    final forbidden = <String>[
      'invoice #1029',
      'PocketLLM Native Core',
      'Result: Recursion in Dart is a technique where a function calls itself',
      'This app is designed to run completely offline',
      '100% offline. Fits completely in sandboxed memory',
      'No data leaves your device',
      'GoogleFonts.',
    ];
    final violations = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      final content = file.readAsStringSync();
      for (final phrase in forbidden) {
        if (content.toLowerCase().contains(phrase.toLowerCase())) {
          violations.add('${file.path}: $phrase');
        }
      }
    }

    expect(violations, isEmpty);
  });
}
