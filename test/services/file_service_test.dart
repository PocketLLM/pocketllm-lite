import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/file_service.dart';

// Manual Mock
class MockFilePickerWrapper implements FilePickerWrapper {
  FilePickerResult? mockResult;

  @override
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    return mockResult;
  }
}

void main() {
  late FileService fileService;
  late MockFilePickerWrapper mockFilePicker;

  setUp(() {
    mockFilePicker = MockFilePickerWrapper();
    fileService = FileService(filePicker: mockFilePicker);
  });

  group('FileService', () {
    test('pickTextFiles returns list of files when picker returns results', () async {
      final file = PlatformFile(
        name: 'test.txt',
        size: 100,
        path: '/tmp/test.txt',
      );
      mockFilePicker.mockResult = FilePickerResult([file]);

      final files = await fileService.pickTextFiles();

      expect(files.length, 1);
      expect(files.first.name, 'test.txt');
    });

    test('pickTextFiles returns empty list when picker returns null', () async {
      mockFilePicker.mockResult = null;

      final files = await fileService.pickTextFiles();

      expect(files, isEmpty);
    });

    test('pickTextFiles filters out large files', () async {
      final smallFile = PlatformFile(name: 'small.txt', size: 100);
      final largeFile = PlatformFile(name: 'large.txt', size: AppConstants.maxFileSize + 1);
      mockFilePicker.mockResult = FilePickerResult([smallFile, largeFile]);

      final files = await fileService.pickTextFiles();

      expect(files.length, 1);
      expect(files.first.name, 'small.txt');
    });
  });
}
