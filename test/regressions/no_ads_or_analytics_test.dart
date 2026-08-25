import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'project dependencies and configuration do not contain advertising or analytics trackers',
      () {
    final exactForbiddenPatterns = <String>[
      'google_mobile_ads',
      'firebase_analytics',
      'firebase_crashlytics',
      'appsflyer_sdk',
      'appsflyer',
      'mixpanel_flutter',
      'mixpanel',
      'posthog_flutter',
      'posthog',
      'facebook_app_id',
      'com.google.android.gms.ads',
      'com.adjust.sdk',
      'com.amplitude',
    ];

    final regexForbiddenPatterns = <RegExp>[
      RegExp(
          r'package:(adjust_sdk|amplitude_flutter|mixpanel_flutter|posthog_flutter|appsflyer_sdk)'),
      RegExp(
          r'import\s+.*(adjust|amplitude|mixpanel|posthog|appsflyer|firebase_analytics)'),
    ];

    final targetPaths = <String>['lib', 'android', 'ios', 'pubspec.yaml'];
    final filesToScan = <File>[];

    for (final path in targetPaths) {
      final entityType = FileSystemEntity.typeSync(path);
      if (entityType == FileSystemEntityType.file) {
        filesToScan.add(File(path));
      } else if (entityType == FileSystemEntityType.directory) {
        final dirFiles = Directory(path)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) =>
                !f.path.contains('.git') &&
                !f.path.contains('build') &&
                !f.path.contains('.dart_tool'));
        filesToScan.addAll(dirFiles);
      }
    }

    final violations = <String>[];
    for (final file in filesToScan) {
      try {
        final content = file.readAsStringSync();
        for (final pattern in exactForbiddenPatterns) {
          if (content.contains(pattern)) {
            violations.add('${file.path}: contains "$pattern"');
          }
        }
        for (final regex in regexForbiddenPatterns) {
          if (regex.hasMatch(content)) {
            violations.add('${file.path}: matches pattern ${regex.pattern}');
          }
        }
      } catch (_) {
        // Skip binary or unreadable files
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Advertising or analytics tracker patterns found in project sources: ${violations.join(', ')}',
    );
  });
}
