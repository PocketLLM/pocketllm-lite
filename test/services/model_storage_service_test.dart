import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/model_storage_service.dart';

void main() {
  late Directory appDirectory;
  late Directory outsideDirectory;
  late ModelStorageService service;

  setUp(() async {
    appDirectory = await Directory.systemTemp.createTemp('pocketllm-models-');
    outsideDirectory = await Directory.systemTemp.createTemp('outside-model-');
    service = ModelStorageService(directoryProvider: () async => appDirectory);
  });

  tearDown(() async {
    if (await appDirectory.exists()) {
      await appDirectory.delete(recursive: true);
    }
    if (await outsideDirectory.exists()) {
      await outsideDirectory.delete(recursive: true);
    }
  });

  test('imports a verified GGUF atomically into its own model directory',
      () async {
    final source = File('${outsideDirectory.path}/My Model.gguf');
    await source.writeAsBytes([0x47, 0x47, 0x55, 0x46, 1, 2, 3]);

    final imported = await service.importExternalGGUF(
      FilePickerResult([
        PlatformFile(
          name: 'My Model.gguf',
          path: source.path,
          size: await source.length(),
        ),
      ]),
    );

    expect(imported, isNotNull);
    expect(await imported!.exists(), isTrue);
    expect(imported.path, contains('my-model'));
    expect(await service.isValidGGUFFile(imported.path), isTrue);
    expect(await File('${imported.path}.partial').exists(), isFalse);
  });

  test('refuses to delete any file outside app model storage', () async {
    final outside = File('${outsideDirectory.path}/keep.gguf');
    await outside.writeAsBytes([0x47, 0x47, 0x55, 0x46]);

    expect(
      () => service.deleteRegisteredModel(outside.path),
      throwsException,
    );
    expect(await outside.exists(), isTrue);
  });
}
