import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pocketllm-notes-');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('tool-created notes persist and are included in encrypted backup data',
      () async {
    final first = StorageService();
    await first.init(testPath: directory.path);
    final note = await first.createLocalNote(
      title: 'Release',
      content: 'Verify production signing.',
    );
    final backup = first.exportBackupData();
    expect(
      (backup['settings'] as Map)[AppConstants.localNotesKey],
      isA<List>(),
    );

    await Hive.close();
    final reopened = StorageService();
    await reopened.init(testPath: directory.path);
    expect(reopened.getLocalNotes().single['id'], note['id']);
    expect(
      reopened.getLocalNotes().single['content'],
      'Verify production signing.',
    );
  });
}
