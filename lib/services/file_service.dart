import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

// Wrapper for mocking
class FilePickerWrapper {
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) {
    return FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
    );
  }
}

class FileService {
  final FilePickerWrapper _filePicker;

  FileService({FilePickerWrapper? filePicker})
      : _filePicker = filePicker ?? FilePickerWrapper();

  Future<List<PlatformFile>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    final result = await _filePicker.pickFiles(
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
    );
    return result?.files ?? [];
  }

  Future<String> readFileContent(PlatformFile file) async {
    try {
      if (file.path != null) {
        final f = File(file.path!);
        return await f.readAsString();
      }
      // Fallback for bytes (e.g. web or cached)
      if (file.bytes != null) {
        return utf8.decode(file.bytes!);
      }
      throw Exception('File path not available and no bytes provided');
    } catch (e) {
      throw Exception('Failed to read file ${file.name}: $e');
    }
  }
}
