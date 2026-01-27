import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/file_service.dart';

void main() {
  group('FileService', () {
    late FileService fileService;

    setUp(() {
      fileService = FileService();
    });

    test('readTextFile returns decoded string for valid file', () async {
      final content = 'Hello, World!';
      final bytes = utf8.encode(content);
      final file = PlatformFile(
        name: 'test.txt',
        size: bytes.length,
        bytes: Uint8List.fromList(bytes),
      );

      final result = await fileService.readTextFile(file);

      expect(result, equals(content));
    });

    test('readTextFile throws exception if file is too large', () async {
      final largeSize = FileService.maxFileSize + 1;
      final file = PlatformFile(
        name: 'large.txt',
        size: largeSize,
        bytes: Uint8List(0), // Bytes don't matter for size check
      );

      expect(
        () => fileService.readTextFile(file),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('File too large'),
        )),
      );
    });

    test('readTextFile throws exception if bytes are null', () async {
      final file = PlatformFile(
        name: 'test.txt',
        size: 100,
        bytes: null,
      );

      expect(
        () => fileService.readTextFile(file),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Could not read file data'),
        )),
      );
    });
  });
}
