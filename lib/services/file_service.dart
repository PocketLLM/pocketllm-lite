import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';

// Wrapper for FilePicker to enable unit testing
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

  // Pick text-based files
  Future<List<PlatformFile>> pickTextFiles() async {
    try {
      final result = await _filePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.supportedTextExtensions,
        allowMultiple: true,
      );

      if (result != null) {
        // Filter by size
        return result.files.where((file) {
          return file.size <= AppConstants.maxFileSize;
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error picking files: $e');
      return [];
    }
  }

  // Read file content as string (handling Web and Native)
  Future<String> readFileContent(PlatformFile file) async {
    try {
      if (kIsWeb) {
        // Web: content is in bytes
        if (file.bytes != null) {
          return utf8.decode(file.bytes!);
        }
        throw Exception('File bytes are null on Web');
      } else {
        // Native: content is in path
        if (file.path != null) {
          final ioFile = File(file.path!);
          return await ioFile.readAsString();
        }
        throw Exception('File path is null on Native');
      }
    } catch (e) {
      debugPrint('Error reading file ${file.name}: $e');
      return 'Error reading file: ${e.toString()}';
    }
  }
}

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});
