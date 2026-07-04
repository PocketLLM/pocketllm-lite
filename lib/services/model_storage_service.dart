import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class ModelStorageService {
  ModelStorageService._internal();
  static final ModelStorageService instance = ModelStorageService._internal();

  static const MethodChannel _storageChannel =
      MethodChannel('pocketllm_lite/storage');

  /// Gets the safest, non-cache system directory for multi-gigabyte models.
  /// Unifies storage under applicationDocuments/models where Cactus looks.
  Future<Directory> getModelDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory(p.join(appDir.path, 'models'));
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// Natively extracts free disk space in bytes before starting a download task.
  Future<int> getAvailableDiskSpace() async {
    try {
      final int freeBytes =
          await _storageChannel.invokeMethod('getFreeDiskSpace');
      return freeBytes;
    } catch (_) {
      // Fallback estimate: return 8GB if the platform channel isn't registered yet or not supported
      return 8 * 1024 * 1024 * 1024;
    }
  }

  /// Validates GGUF magic header (0x46554747 in little endian or 'GGUF' in ASCII)
  Future<bool> isValidGGUFFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    try {
      final accessFile = await file.open(mode: FileMode.read);
      final headerBytes = await accessFile.read(4);
      await accessFile.close();

      if (headerBytes.length < 4) return false;

      // Check for 'G' 'G' 'U' 'F'
      return headerBytes[0] == 0x47 &&
          headerBytes[1] == 0x47 &&
          headerBytes[2] == 0x55 &&
          headerBytes[3] == 0x46;
    } catch (e) {
      return false;
    }
  }

  /// Resolves selected file picker path, validates GGUF, and safely imports/registers it
  Future<File?> importExternalGGUF(FilePickerResult result) async {
    if (result.files.isEmpty) return null;

    final pickedFile = result.files.first;
    final sourcePath = pickedFile.path;

    if (sourcePath == null) {
      // Handle scoped URI fallback on Android/iOS if direct path is missing
      final bytes = pickedFile.bytes;
      if (bytes != null) {
        // Validate in-memory GGUF bytes first
        if (bytes.length < 4 ||
            bytes[0] != 0x47 ||
            bytes[1] != 0x47 ||
            bytes[2] != 0x55 ||
            bytes[3] != 0x46) {
          throw Exception('Selected file is not a valid GGUF model.');
        }

        final modelDir = await getModelDirectory();
        final finalPath = p.join(modelDir.path, pickedFile.name);
        final importedFile = File(finalPath);
        await importedFile.writeAsBytes(bytes);
        return importedFile;
      }
      throw Exception('Could not resolve physical file path.');
    }

    // Validate the physical GGUF file
    final isValid = await isValidGGUFFile(sourcePath);
    if (!isValid) {
      throw Exception('Selected file is not a valid GGUF model.');
    }

    final modelDir = await getModelDirectory();
    final finalPath = p.join(modelDir.path, pickedFile.name);

    // If file is already inside the model directory (e.g. copied/selected there), return it directly
    if (p.canonicalize(sourcePath) == p.canonicalize(finalPath)) {
      return File(sourcePath);
    }

    // Copy file to app sandbox to prevent security tokens from expiring
    final sourceFile = File(sourcePath);
    final copiedFile = await sourceFile.copy(finalPath);
    return copiedFile;
  }

  /// Erases physical items and handles cleaning up of temporary fragments
  Future<void> deleteModel(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }

      // Cleanup any stranded .tmp fragments with the same name
      final basePath = p.withoutExtension(localPath);
      final tmpFile = File('$basePath.tmp');
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
    } catch (e) {
      throw Exception('Error deleting local model file: $e');
    }
  }
}
