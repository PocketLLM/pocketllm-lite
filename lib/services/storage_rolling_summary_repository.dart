import 'generation_pipeline.dart';
import '../core/constants/app_constants.dart';
import 'storage_service.dart';

class StorageRollingSummaryRepository implements RollingSummaryRepository {
  final StorageService _storage;

  const StorageRollingSummaryRepository(this._storage);

  @override
  Future<String?> load(String conversationId) async {
    final value = _storage.getSetting(
      '${AppConstants.rollingSummaryPrefixKey}$conversationId',
    );
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  @override
  Future<void> save(String conversationId, String summary) {
    return _storage.saveSetting(
      '${AppConstants.rollingSummaryPrefixKey}$conversationId',
      summary,
    );
  }
}
