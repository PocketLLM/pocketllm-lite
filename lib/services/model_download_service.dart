import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'network_policy_service.dart';
import 'network_gateway.dart';
import 'model_storage_service.dart';
import '../core/domain/background_task.dart';
import 'background_task_service.dart';

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
  final BackgroundTaskService? _tasks;
  final Map<String, CancelToken> _managedTokens = {};

  ModelDownloadService({
    Dio? dio,
    NetworkPolicyService? networkPolicy,
    BackgroundTaskService? tasks,
  })  : _tasks = tasks,
        _dio = dio ??
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

  Future<String> downloadManagedBundle({
    required String modelId,
    required String modelName,
    required String url,
    required String archiveFilename,
    required int catalogSizeMb,
  }) async {
    final modelsRoot = await ModelStorageService.instance.getModelDirectory();
    final finalDirectory = Directory(p.join(modelsRoot.path, modelId));
    if (await finalDirectory.exists() && !await finalDirectory.list().isEmpty) {
      return finalDirectory.path;
    }
    final task = await _tasks?.create(
      type: BackgroundTaskType.modelDownload,
      title: 'Download $modelName',
      phase: 'Checking storage and server',
      source: url,
      destination: finalDirectory.path,
      metadata: {
        'modelId': modelId,
        'archiveFilename': archiveFilename,
        'catalogSizeMb': catalogSizeMb,
        'managedBundle': true,
      },
    );
    final taskId = task?.id ?? 'managed-$modelId';
    final cancelToken = CancelToken();
    _managedTokens[taskId] = cancelToken;
    final downloadDirectory = Directory(p.join(modelsRoot.path, '.downloads'));
    final stagingDirectory =
        Directory(p.join(modelsRoot.path, '.stage-$modelId'));
    final partialFile =
        File(p.join(downloadDirectory.path, '$modelId.zip.part'));
    try {
      await downloadDirectory.create(recursive: true);
      if (task != null) {
        await _tasks!.start(task.id, phase: 'Checking storage and server');
      }
      final estimatedBytes = catalogSizeMb * 1024 * 1024;
      final freeBytes =
          await ModelStorageService.instance.getAvailableDiskSpace();
      if (freeBytes < estimatedBytes * 2) {
        throw StateError(
          'Not enough free storage to download and extract this model.',
        );
      }
      final uri = Uri.parse(url);
      final policy = _networkPolicy.evaluateConnection(
        uri: uri,
        purpose: ConnectionPurpose.modelDownload,
        trigger: 'managed_model_bundle_download',
        infoSent: 'Requested catalog model bundle; no user content',
      );
      if (!policy.allowed) {
        throw NetworkPolicyError(policy.reason ?? 'Model download blocked.');
      }
      var supportsResume = false;
      String? validator;
      try {
        final head = await _dio.head<void>(url);
        validator =
            head.headers.value('etag') ?? head.headers.value('last-modified');
        supportsResume =
            head.headers.value('accept-ranges')?.contains('bytes') == true &&
                validator != null;
      } catch (_) {}
      var existing =
          await partialFile.exists() ? await partialFile.length() : 0;
      if (existing > 0 && !supportsResume) {
        await partialFile.delete();
        existing = 0;
      }
      final requestHeaders = <String, String>{};
      if (existing > 0) {
        requestHeaders['Range'] = 'bytes=$existing-';
        requestHeaders['If-Range'] = validator!;
      }
      if (task != null) {
        await _tasks!.report(
          task.id,
          phase: existing > 0 ? 'Resuming bundle' : 'Downloading bundle',
          completedUnits: existing,
          metadata: {
            'partialPath': partialFile.path,
            'resumeSupported': supportsResume,
            if (validator != null) 'validator': validator,
          },
        );
      }
      await _dio.download(
        url,
        partialFile.path,
        cancelToken: cancelToken,
        options: Options(headers: requestHeaders),
        fileAccessMode:
            existing > 0 ? FileAccessMode.append : FileAccessMode.write,
        onReceiveProgress: (received, total) {
          if (task == null) return;
          final downloaded = existing + received;
          final effectiveTotal = total > 0 ? existing + total : 0;
          unawaited(
            _tasks!.report(
              task.id,
              phase: existing > 0 ? 'Resuming bundle' : 'Downloading bundle',
              completedUnits: downloaded,
              totalUnits: effectiveTotal > 0 ? effectiveTotal : null,
              progress: effectiveTotal > 0 ? downloaded / effectiveTotal : null,
            ),
          );
        },
      );
      if (task != null) {
        await _tasks!.report(task.id, phase: 'Verifying and extracting bundle');
      }
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
      await stagingDirectory.create(recursive: true);
      await _extractBundleSafely(partialFile, stagingDirectory);
      final ggufFiles = await stagingDirectory
          .list(recursive: true, followLinks: false)
          .where(
            (entity) =>
                entity is File && entity.path.toLowerCase().endsWith('.gguf'),
          )
          .toList();
      if (ggufFiles.isEmpty) {
        throw StateError('The downloaded bundle contains no GGUF model file.');
      }
      if (await finalDirectory.exists()) {
        await finalDirectory.delete(recursive: true);
      }
      await stagingDirectory.rename(finalDirectory.path);
      await partialFile.delete();
      if (task != null) {
        await _tasks!.complete(
          task.id,
          phase: 'Downloaded, extracted, and verified',
          destination: finalDirectory.path,
        );
      }
      return finalDirectory.path;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        if (task != null) await _tasks!.cancel(task.id);
        rethrow;
      }
      if (task != null) {
        await _tasks!.fail(
          task.id,
          message: 'The model bundle did not finish downloading.',
          action: 'Retry to resume when the catalog server supports ranges.',
          details: error.toString(),
        );
      }
      rethrow;
    } catch (error) {
      if (task != null) {
        await _tasks!.fail(
          task.id,
          message: 'The model bundle could not be installed.',
          action:
              'Check storage, network policy, and the catalog file, then retry.',
          details: error.toString(),
        );
      }
      rethrow;
    } finally {
      _managedTokens.remove(taskId);
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> cancelManagedDownload(String taskId) async {
    _managedTokens[taskId]?.cancel('User cancelled model download');
    final task = _tasks?.find(taskId);
    if (task != null && !task.isTerminal) await _tasks!.cancel(taskId);
  }

  Future<void> _extractBundleSafely(
    File archiveFile,
    Directory destination,
  ) async {
    final input = InputFileStream(archiveFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input, verify: true);
      final names = archive
          .map((entry) => entry.name.replaceAll('\\', '/'))
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      final firstParts = names
          .map((name) => name.split('/').first)
          .where((part) => part.isNotEmpty)
          .toSet();
      final sharedRoot = firstParts.length == 1 ? firstParts.single : null;
      final root = p.canonicalize(destination.path);
      for (final entry in archive) {
        if (entry.isSymbolicLink) continue;
        var relative = entry.name.replaceAll('\\', '/');
        if (sharedRoot != null && relative.startsWith('$sharedRoot/')) {
          relative = relative.substring(sharedRoot.length + 1);
        }
        if (relative.isEmpty) continue;
        final target = p.normalize(p.join(destination.path, relative));
        if (!p.isWithin(root, p.canonicalize(target))) {
          throw const FormatException('Model bundle contains an unsafe path.');
        }
        if (entry.isFile) {
          await File(target).parent.create(recursive: true);
          final output = OutputFileStream(target);
          entry.writeContent(output);
          output.closeSync();
        } else {
          await Directory(target).create(recursive: true);
        }
      }
    } finally {
      input.closeSync();
    }
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

    final task = await _tasks?.create(
      type: BackgroundTaskType.modelDownload,
      title: 'Download $modelName',
      phase: 'Checking remote file',
      source: url,
      destination: targetFilePath,
      metadata: {
        'expectedFilename': expectedFilename,
        'expectedSizeBytes': expectedSizeBytes,
        if (expectedSha256 != null) 'expectedSha256': expectedSha256,
      },
    );

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
              if (task != null) unawaited(_tasks!.cancel(task.id));
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    try {
      if (task != null) {
        await _tasks!.start(task.id, phase: 'Checking storage and server');
      }
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
      final remoteHeaders = <String, String>{...?headers};
      var supportsResume = false;
      String? validator;
      try {
        final head = await _dio.head<void>(
          url,
          options: Options(headers: headers),
        );
        final acceptRanges = head.headers.value('accept-ranges');
        validator =
            head.headers.value('etag') ?? head.headers.value('last-modified');
        supportsResume =
            acceptRanges?.toLowerCase().contains('bytes') == true &&
                validator != null;
      } catch (_) {
        // A missing HEAD response means resumption cannot be promised. The
        // normal GET may still succeed from byte zero.
      }
      var existingBytes =
          await partialFile.exists() ? await partialFile.length() : 0;
      if (existingBytes > 0 &&
          (!supportsResume ||
              (expectedSizeBytes > 0 && existingBytes >= expectedSizeBytes))) {
        await partialFile.delete();
        existingBytes = 0;
      }
      if (existingBytes > 0) {
        remoteHeaders['Range'] = 'bytes=$existingBytes-';
        remoteHeaders['If-Range'] = validator!;
      }
      lastUpdateBytes = existingBytes;
      if (task != null) {
        await _tasks!.report(
          task.id,
          phase: existingBytes > 0 ? 'Resuming download' : 'Downloading',
          completedUnits: existingBytes,
          totalUnits: expectedSizeBytes > 0 ? expectedSizeBytes : null,
          progress:
              expectedSizeBytes > 0 ? existingBytes / expectedSizeBytes : null,
          metadata: {
            'partialPath': partialPath,
            'resumeSupported': supportsResume,
            if (validator != null) 'validator': validator,
          },
        );
      }
      final response = await _dio.download(
        url,
        partialPath,
        cancelToken: cancelToken,
        options: Options(headers: remoteHeaders),
        fileAccessMode:
            existingBytes > 0 ? FileAccessMode.append : FileAccessMode.write,
        onReceiveProgress: (received, total) {
          final downloaded = existingBytes + received;
          final effectiveTotal = expectedSizeBytes > 0
              ? expectedSizeBytes
              : (total > 0 ? existingBytes + total : 0);
          final now = DateTime.now().millisecondsSinceEpoch;
          final elapsed = now - lastUpdateTime;
          if (elapsed > 500) {
            final progress = effectiveTotal > 0
                ? (downloaded / effectiveTotal).clamp(0.0, 1.0)
                : 0.0;
            final bytesDiff = downloaded - lastUpdateBytes;
            final speed = (bytesDiff / 1024 / 1024) / (elapsed / 1000); // MB/s

            final bytesRemaining = effectiveTotal - downloaded;
            final timeRemainingSecs =
                speed > 0 ? (bytesRemaining / 1024 / 1024) / speed : 0.0;

            progressNotifier.value = ModelDownloadProgress(
              progress: progress,
              networkSpeed: speed,
              timeRemaining: Duration(seconds: timeRemainingSecs.round()),
              totalBytes: effectiveTotal,
              downloadedBytes: downloaded,
            );

            if (task != null) {
              unawaited(
                _tasks!.report(
                  task.id,
                  phase:
                      existingBytes > 0 ? 'Resuming download' : 'Downloading',
                  completedUnits: downloaded,
                  totalUnits: effectiveTotal > 0 ? effectiveTotal : null,
                  progress: effectiveTotal > 0 ? progress : null,
                ),
              );
            }

            lastUpdateTime = now;
            lastUpdateBytes = downloaded;
          }
        },
      );

      // Close progress dialog
      if (context.mounted &&
          Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (response.statusCode == 200 || response.statusCode == 206) {
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
        if (task != null) {
          await _tasks!.complete(
            task.id,
            phase: 'Downloaded and verified',
            destination: targetFilePath,
          );
        }
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

      final partialFile = File('$targetFilePath.partial');
      if (await partialFile.exists() &&
          expectedSizeBytes > 0 &&
          await partialFile.length() > expectedSizeBytes) {
        await partialFile.delete();
      }
      if (task != null &&
          _tasks?.find(task.id)?.state != BackgroundTaskState.cancelled) {
        await _tasks!.fail(
          task.id,
          message: 'The model download did not finish.',
          action:
              'Retry from Model Store. Safe partial data is kept only when resumption is supported.',
          details: e.toString(),
        );
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
