import 'dart:convert';
import 'package:file_picker/file_picker.dart';

class FileService {
  // 1MB limit for text files to prevent token overflow/performance issues
  static const int maxFileSize = 1024 * 1024;

  Future<String> readTextFile(PlatformFile file) async {
    if (file.size > maxFileSize) {
      throw Exception('File too large (max 1MB)');
    }

    if (file.bytes == null) {
      // We rely on withData: true being passed to FilePicker
      throw Exception('File content not loaded (bytes is null)');
    }

    try {
      // Decode bytes as UTF-8. allowMalformed: true replaces invalid sequences instead of throwing
      final content = utf8.decode(file.bytes!, allowMalformed: true);
      return _formatContent(file.name, content);
    } catch (e) {
      throw Exception('Failed to read file: $e');
    }
  }

  String _formatContent(String fileName, String content) {
    String ext = '';
    if (fileName.contains('.')) {
      ext = fileName.split('.').last.toLowerCase();
    }

    return '\n\n[Attached File: $fileName]\n```$ext\n$content\n```\n';
  }
}
