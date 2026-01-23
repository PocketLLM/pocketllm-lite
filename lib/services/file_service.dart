import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Wrapper for testability
class FilePickerWrapper {
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    bool allowMultiple = false,
    bool withData = false,
  }) {
    return FilePicker.platform.pickFiles(
      type: type,
      allowMultiple: allowMultiple,
      withData: withData,
    );
  }
}

final fileServiceProvider =
    Provider<FileService>((ref) => FileService(FilePickerWrapper()));

class FileResult {
  final String name;
  final String content;
  final String extension;

  FileResult({
    required this.name,
    required this.content,
    required this.extension,
  });
}

class FileService {
  final FilePickerWrapper _filePicker;

  FileService(this._filePicker);

  Future<FileResult?> pickAndReadFile({int maxSize = 30 * 1024}) async {
    try {
      final result = await _filePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: kIsWeb, // Force loading bytes on Web
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.single;

      // Size check
      if (file.size > maxSize) {
        throw FileSystemException(
          'File too large. Max size is ${maxSize ~/ 1024}KB.',
          file.name,
        );
      }

      String content;

      if (kIsWeb) {
        if (file.bytes != null) {
          content = utf8.decode(file.bytes!);
        } else {
          throw const FileSystemException('No data found in file.');
        }
      } else {
        if (file.path != null) {
          final ioFile = File(file.path!);
          content = await ioFile.readAsString();
        } else {
          throw const FileSystemException('File path is null.');
        }
      }

      return FileResult(
        name: file.name,
        content: content,
        extension: file.extension ?? 'txt',
      );
    } catch (e) {
      if (e is FileSystemException) rethrow;
      // Handle FormatException from utf8.decode
      if (e is FormatException) {
        throw const FileSystemException('Binary files are not supported.');
      }
      throw FileSystemException('Error reading file: $e');
    }
  }
}
