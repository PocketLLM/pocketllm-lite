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

  test('shipping source has no invented catalog or duplicate tool paths', () {
    final modelManager =
        File('lib/providers/model_manager_provider.dart').readAsStringSync();
    expect(modelManager, isNot(contains('MMLU')));
    expect(modelManager, isNot(contains('GSM8K')));
    expect(modelManager, isNot(contains('CactusLM')));
    expect(modelManager, isNot(contains('.getModels()')));
    expect(File('lib/services/typed_tool_calling_service.dart').existsSync(),
        isFalse);
    expect(File('lib/services/document_workspace_service.dart').existsSync(),
        isFalse);
    expect(
        File('lib/services/model_profile_registry.dart').existsSync(), isFalse);
    expect(File('lib/services/task_router_service.dart').existsSync(), isFalse);
  });
}
