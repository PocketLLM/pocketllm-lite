import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pocketllm_lite/services/file_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class MockFilePickerWrapper extends FilePickerWrapper {
  FilePickerResult? resultToReturn;

  @override
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    return resultToReturn;
  }
}

void main() {
  group('FileService', () {
    late FileService fileService;
    late MockFilePickerWrapper mockFilePicker;

    setUp(() {
      mockFilePicker = MockFilePickerWrapper();
      fileService = FileService(filePicker: mockFilePicker);
    });

    test('pickFiles returns list of files when files are picked', () async {
      final platformFiles = [
        PlatformFile(name: 'test.txt', size: 10, bytes: Uint8List.fromList(utf8.encode('content'))),
      ];
      mockFilePicker.resultToReturn = FilePickerResult(platformFiles);

      final files = await fileService.pickFiles();

      expect(files, hasLength(1));
      expect(files.first.name, 'test.txt');
    });

    test('pickFiles returns empty list when no files picked', () async {
      mockFilePicker.resultToReturn = null;

      final files = await fileService.pickFiles();

      expect(files, isEmpty);
    });

    test('readFileContent returns content from bytes', () async {
      final bytes = Uint8List.fromList(utf8.encode('Hello World'));
      final file = PlatformFile(name: 'test.txt', size: bytes.length, bytes: bytes);

      final content = await fileService.readFileContent(file);

      expect(content, 'Hello World');
    });
  });
}
