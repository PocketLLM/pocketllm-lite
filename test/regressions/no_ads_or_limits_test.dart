import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application source does not contain ad or usage-limit gates', () {
    final forbiddenPatterns = <String>[
      'google_mobile_ads',
      'AdService',
      'RewardedAd',
      'BannerAd',
      'AdWidget',
      'Watch Ad',
      'ADMOB_',
      'freeChatsAllowed',
      'freeEnhancementsPerDay',
      'tokensPerAdWatch',
      'usageLimitsProvider',
    ];

    final sourceFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final violations = <String>[];
    for (final file in sourceFiles) {
      final content = file.readAsStringSync();
      for (final pattern in forbiddenPatterns) {
        if (content.contains(pattern)) {
          violations.add('${file.path}: $pattern');
        }
      }
    }

    expect(violations, isEmpty);
  });
}
