import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:pocketllm_lite/services/model_download_service.dart';
import 'package:pocketllm_lite/services/model_storage_service.dart';

void main() {
  test('restarts safely when a resumed bundle receives HTTP 200', () async {
    final root = await Directory.systemTemp.createTemp('pocketllm_download_');
    addTearDown(() => root.delete(recursive: true));
    final archive = Archive()
      ..addFile(ArchiveFile('fixture/model.gguf', 8, const [
        0x47,
        0x47,
        0x55,
        0x46,
        1,
        2,
        3,
        4,
      ]));
    final bundle = ZipEncoder().encode(archive);
    final adapter = _RangeIgnoringAdapter(bundle);
    final dio = Dio()..httpClientAdapter = adapter;
    final storage = _FakeStorage(root);
    final models = await storage.getModelDirectory();
    final partial = File(
      path.join(models.path, '.downloads', 'fixture.zip.part'),
    );
    await partial.parent.create(recursive: true);
    await partial.writeAsBytes(bundle.take(7).toList());

    final installed = await ModelDownloadService(
      dio: dio,
      storage: storage,
    ).downloadManagedBundle(
      modelId: 'fixture',
      modelName: 'Fixture',
      url: 'https://example.test/fixture.zip',
      archiveFilename: 'fixture.zip',
      catalogSizeMb: 1,
    );

    expect(adapter.rangedGets, 1);
    expect(adapter.fullGets, 1);
    expect(await partial.exists(), isFalse);
    expect(
      await storage.isValidGGUFFile(
        path.join(installed, 'model.gguf'),
      ),
      isTrue,
    );
  });
}

class _FakeStorage extends ModelStorageService {
  final Directory root;

  _FakeStorage(this.root);

  @override
  Future<Directory> getModelDirectory() async {
    final directory = Directory(path.join(root.path, 'models'));
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<int> getAvailableDiskSpace() async => 4 * 1024 * 1024 * 1024;
}

class _RangeIgnoringAdapter implements HttpClientAdapter {
  final List<int> bundle;
  int rangedGets = 0;
  int fullGets = 0;

  _RangeIgnoringAdapter(this.bundle);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final headers = {
      'accept-ranges': ['bytes'],
      'etag': ['"fixture-v1"'],
      Headers.contentLengthHeader: ['${bundle.length}'],
    };
    if (options.method == 'HEAD') {
      return ResponseBody.fromBytes(const [], 200, headers: headers);
    }
    if (options.headers.keys.any((key) => key.toLowerCase() == 'range')) {
      rangedGets++;
      // Intentionally ignore Range and return the complete body with 200.
    } else {
      fullGets++;
    }
    return ResponseBody.fromBytes(bundle, 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}
