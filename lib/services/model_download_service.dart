import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

class ModelDownloadProgress {
  final double progress;
  final double networkSpeed; // MB/s
  final Duration timeRemaining;
  final int totalBytes;
  final int downloadedBytes;

  const ModelDownloadProgress({
    required this.progress,
    required this.networkSpeed,
    required this.timeRemaining,
    required this.totalBytes,
    required this.downloadedBytes,
  });
}

class ModelDownloadService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 100),
      receiveTimeout: const Duration(minutes: 120),
    ),
  );

  Future<String> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  /// Downloads a GGUF model and shows a UI dialog with progress.
  /// Returns the path to the downloaded file, or null if canceled/failed.
  Future<String?> downloadModelWithDialog(
    BuildContext context, {
    required String modelName,
    required String url,
    required String expectedFilename,
    required int expectedSizeBytes,
  }) async {
    final modelsDir = await getModelsDirectory();
    final targetFilePath = '$modelsDir/$expectedFilename';

    // Show consent dialog
    if (!context.mounted) return null;
    final consent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Download Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📦 $modelName'),
            const SizedBox(height: 8),
            Text(
              'Size: ${(expectedSizeBytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB',
            ),
            const SizedBox(height: 16),
            const Text('📁 Storage Location:'),
            Text(
              targetFilePath,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (consent != true) {
      return null;
    }

    final cancelToken = CancelToken();
    final progressNotifier = ValueNotifier<ModelDownloadProgress>(
      const ModelDownloadProgress(
        progress: 0,
        networkSpeed: 0,
        timeRemaining: Duration.zero,
        totalBytes: 0,
        downloadedBytes: 0,
      ),
    );

    int lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
    int lastUpdateBytes = 0;

    if (!context.mounted) return null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Downloading $modelName'),
        content: ValueListenableBuilder<ModelDownloadProgress>(
          valueListenable: progressNotifier,
          builder: (context, value, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value.progress),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(value.progress * 100).toStringAsFixed(1)}%'),
                    Text('${(value.networkSpeed).toStringAsFixed(1)} MB/s'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${(value.downloadedBytes / 1024 / 1024).toStringAsFixed(1)} / ${(expectedSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'ETA: ${value.timeRemaining.inMinutes}m ${value.timeRemaining.inSeconds % 60}s',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelToken.cancel('User canceled download');
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    try {
      final response = await _dio.download(
        url,
        targetFilePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final elapsed = now - lastUpdateTime;
          if (elapsed > 500) {
            final progress = total > 0 ? (received / total) : 0.0;
            final bytesDiff = received - lastUpdateBytes;
            final speed = (bytesDiff / 1024 / 1024) / (elapsed / 1000); // MB/s

            final bytesRemaining =
                (total > 0 ? total : expectedSizeBytes) - received;
            final timeRemainingSecs =
                speed > 0 ? (bytesRemaining / 1024 / 1024) / speed : 0.0;

            progressNotifier.value = ModelDownloadProgress(
              progress: progress,
              networkSpeed: speed,
              timeRemaining: Duration(seconds: timeRemainingSecs.round()),
              totalBytes: total > 0 ? total : expectedSizeBytes,
              downloadedBytes: received,
            );

            lastUpdateTime = now;
            lastUpdateBytes = received;
          }
        },
      );

      // Close progress dialog
      if (context.mounted &&
          Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (response.statusCode == 200) {
        return targetFilePath;
      } else {
        throw Exception('Download failed status: ${response.statusCode}');
      }
    } catch (e) {
      // Close progress dialog on error
      if (context.mounted &&
          Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Cleanup partial file
      final file = File(targetFilePath);
      if (await file.exists()) {
        await file.delete();
      }
      return null;
    }
  }
}
