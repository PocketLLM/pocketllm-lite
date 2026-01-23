import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/file_service.dart';

// Manual mock
class MockFilePickerWrapper extends FilePickerWrapper {
  FilePickerResult? resultToReturn;

  @override
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    bool allowMultiple = false,
    bool withData = false,
  }) async {
    return resultToReturn;
  }
}

class MockFile extends Fake implements File {
  @override
  final String path;
  MockFile(this.path);

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async {
    return 'mock content';
  }
}

void main() {
  group('FileService', () {
    late MockFilePickerWrapper mockFilePicker;
    late FileService fileService;

    setUp(() {
      mockFilePicker = MockFilePickerWrapper();
      fileService = FileService(mockFilePicker);
    });

    test('pickAndReadFile returns null when cancelled', () async {
      mockFilePicker.resultToReturn = null;

      final result = await fileService.pickAndReadFile();
      expect(result, isNull);
    });

    test('pickAndReadFile throws when file is too large', () async {
      final largeFile = PlatformFile(
        name: 'large.txt',
        size: 50000, // > 30KB
        path: '/tmp/large.txt',
        bytes: null,
        readStream: null,
      );
      mockFilePicker.resultToReturn = FilePickerResult([largeFile]);

      expect(
        () => fileService.pickAndReadFile(),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('pickAndReadFile reads file content successfully', () async {
      final validFile = PlatformFile(
        name: 'test.txt',
        size: 100,
        path: '/tmp/test.txt',
        bytes: null,
        readStream: null,
      );
      mockFilePicker.resultToReturn = FilePickerResult([validFile]);

      await IOOverrides.runZoned(
        () async {
           final fileResult = await fileService.pickAndReadFile();
           expect(fileResult, isNotNull);
           expect(fileResult!.name, 'test.txt');
           expect(fileResult.content, 'mock content');
        },
        createFile: (path) => MockFile(path),
      );
    });
  });
}
