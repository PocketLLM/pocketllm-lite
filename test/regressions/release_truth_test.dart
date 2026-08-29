import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v1.0.38 release metadata and documentation agree', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final readme = File('README.md').readAsStringSync();
    final releaseNotes = File('RELEASE_NOTES.md').readAsStringSync();
    final changelog = File('CHANGELOG.md').readAsStringSync();

    expect(pubspec, contains('version: 1.0.38+38'));
    expect(readme, contains('version-1.0.38'));
    expect(releaseNotes, contains('v1.0.38'));
    expect(changelog, contains('## [1.0.38] - 2026-08-29'));
    expect(File('LICENSE').readAsStringSync(), startsWith('MIT License'));
    expect(File('CONTRIBUTING.md').existsSync(), isTrue);
    expect(File('CODE_OF_CONDUCT.md').existsSync(), isTrue);
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

  test('public product copy excludes disproven privacy and support claims', () {
    final surfaces = <File>[
      File('index.html'),
      File('pocketllm-website/privacy.html'),
      File('docs/pr_submissions/PR_awesome_ollama.md'),
      File('docs/pr_submissions/PR_awesome_local_ai.md'),
    ];
    final forbidden = <String>[
      'Version 1.0.13 Available',
      'complete privacy',
      'your data never leaves your device',
      'may display advertisements',
      'offline knowledge searches',
      'Offline STT & TTS',
    ];
    final violations = <String>[];

    for (final file in surfaces) {
      final content = file.readAsStringSync().toLowerCase();
      for (final phrase in forbidden) {
        if (content.contains(phrase.toLowerCase())) {
          violations.add('${file.path}: $phrase');
        }
      }
    }

    expect(violations, isEmpty);
  });

  test('HTTP links cannot bypass the external-navigation policy service', () {
    final directLaunchFiles = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))) {
      final normalized = file.path.replaceAll('\\', '/');
      if (normalized.endsWith(
            'lib/services/external_navigation_service.dart',
          ) ||
          normalized.endsWith('lib/services/device_tool_action_service.dart')) {
        continue;
      }
      final content = file.readAsStringSync();
      if (content.contains('launchUrl(') || content.contains('canLaunchUrl(')) {
        directLaunchFiles.add(file.path);
      }
    }

    final deviceActions = File(
      'lib/services/device_tool_action_service.dart',
    ).readAsStringSync();
    expect(directLaunchFiles, isEmpty);
    expect(RegExp(r'launchUrl\(').allMatches(deviceActions), hasLength(1));
    expect(deviceActions, contains("Uri.parse('mailto:"));
  });
}
