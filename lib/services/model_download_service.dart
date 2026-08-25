import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'network_policy_service.dart';
import 'network_gateway.dart';
import 'model_storage_service.dart';

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
  final Dio _dio;
  final NetworkPolicyService _networkPolicy;

  ModelDownloadService({Dio? dio, NetworkPolicyService? networkPolicy})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 100),
                receiveTimeout: const Duration(minutes: 120),
              ),
            ),
        _networkPolicy = networkPolicy ?? NetworkPolicyService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final decision = _networkPolicy.evaluateConnection(
            uri: options.uri,
            purpose: ConnectionPurpose.modelDownload,
            trigger: 'model_download_transport',
            infoSent: 'Requested model file path; no user content',
          );
          if (!decision.allowed) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: NetworkPolicyError(
                  decision.reason ?? 'Model download blocked.',
                ),
              ),
            );
            return;
          }
          handler.next(options);
        },
      ),
    );
  }

  Future<String> getModelsDirectory() async {
    return (await ModelStorageService.instance.getModelDirectory()).path;
  }

  /// Downloads a GGUF model and shows a UI dialog with progress.
  /// Returns the path to the downloaded file, or null if canceled/failed.
  Future<String?> downloadModelWithDialog(
    BuildContext context, {
    required String modelName,
    required String url,
    required String expectedFilename,
    required int expectedSizeBytes,
    String? expectedSha256,
    Map<String, String>? headers,
  }) async {
    final targetFilePath =
        await ModelStorageService.instance.targetPathFor(expectedFilename);
    await File(targetFilePath).parent.create(recursive: true);

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
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
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
      final freeBytes =
          await ModelStorageService.instance.getAvailableDiskSpace();
      if (expectedSizeBytes > 0 && freeBytes < expectedSizeBytes * 1.15) {
        throw StateError(
          'Not enough free storage for this model and verification copy.',
        );
      }
      final downloadUri = Uri.parse(url);
      final policy = _networkPolicy.evaluateConnection(
        uri: downloadUri,
        purpose: ConnectionPurpose.modelDownload,
        trigger: 'model_download_dialog',
        infoSent: 'Requested model file path; no user content',
      );
      if (!policy.allowed) {
        throw NetworkPolicyError(policy.reason ?? 'Model download blocked.');
      }
      final partialPath = '$targetFilePath.partial';
      final partialFile = File(partialPath);
      if (await partialFile.exists()) await partialFile.delete();
      final response = await _dio.download(
        url,
        partialPath,
        cancelToken: cancelToken,
        options: Options(headers: headers),
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
        if (expectedSizeBytes > 0 &&
            await partialFile.length() != expectedSizeBytes) {
          throw StateError('Downloaded file size does not match Hub metadata.');
        }
        if (expectedSha256?.trim().isNotEmpty == true) {
          final digest = await sha256.bind(partialFile.openRead()).first;
          if (digest.toString().toLowerCase() !=
              expectedSha256!.trim().toLowerCase()) {
            throw StateError('Downloaded file checksum verification failed.');
          }
        }
        if (!await ModelStorageService.instance.isValidGGUFFile(partialPath)) {
          throw StateError('Downloaded file is not a valid GGUF model.');
        }
        final target = File(targetFilePath);
        if (await target.exists()) await target.delete();
        await partialFile.rename(targetFilePath);
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
      for (final path in [targetFilePath, '$targetFilePath.partial']) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Model download failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return null;
    }
  }
}
