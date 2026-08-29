import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../services/model_storage_service.dart';
import '../domain/model_store_model.dart';

final modelStoreCatalogProvider = FutureProvider<List<ModelStoreModel>>((ref) {
  return ref.watch(modelStoreServiceProvider).fetchCatalog();
});

final installedStoreModelIdsProvider = FutureProvider<Set<String>>((ref) async {
  final root = await ModelStorageService.instance.getModelDirectory();
  final ids = <String>{};
  await for (final entity in root.list(followLinks: false)) {
    if (entity is! Directory ||
        entity.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .last
            .startsWith(
              '.',
            )) {
      continue;
    }
    final modelFiles = await entity
        .list(recursive: true, followLinks: false)
        .where(
          (item) => item is File && item.path.toLowerCase().endsWith('.gguf'),
        )
        .cast<File>()
        .toList();
    final valid = modelFiles.isNotEmpty &&
        (await Future.wait(
          modelFiles.map(
            (file) => ModelStorageService.instance.isValidGGUFFile(file.path),
          ),
        ))
            .every((result) => result);
    if (valid) {
      ids.add(entity.uri.pathSegments.where((e) => e.isNotEmpty).last);
    }
  }
  return ids;
});
