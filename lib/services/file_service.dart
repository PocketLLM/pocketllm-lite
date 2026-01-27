import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class FileService {
  // 1MB limit for text files to prevent context overflow and performance issues
  static const int maxFileSize = 1024 * 1024;

  static const List<String> allowedExtensions = [
    'txt', 'md', 'json', 'dart', 'js', 'ts', 'py', 'java', 'c', 'cpp', 'h',
    'html', 'css', 'xml', 'yaml', 'yml', 'sh', 'bat', 'ps1', 'sql', 'rb', 'go', 'rs', 'php'
  ];

  Future<PlatformFile?> pickTextFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: true, // Critical for cross-platform support (especially Web)
        allowMultiple: false, // Start with single file support
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files.first;
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Error picking file: $e');
      return null;
    }
  }

  Future<String> readTextFile(PlatformFile file) async {
    if (file.size > maxFileSize) {
      throw Exception('File too large. Maximum size is 1MB.');
    }

    try {
      Uint8List? bytes = file.bytes;

      // On mobile, bytes might be null even with withData: true if the file is large,
      // but we filtered size. However, to be safe and strictly follow the memory guideline
      // "FileService reads file content using PlatformFile.bytes... strictly avoiding dart:io File",
      // we rely on bytes.
      // If bytes is null, it might be a path issue on non-web platforms.
      // But adhering to the memory, we assume bytes are present or we fail gracefully.

      if (bytes == null) {
        throw Exception('Could not read file data.');
      }

      return utf8.decode(bytes);
    } catch (e) {
      throw Exception('Failed to read file: $e');
    }
  }
}
