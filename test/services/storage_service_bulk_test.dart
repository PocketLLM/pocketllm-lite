import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final Map<String, dynamic> settings = {};
  final List<Map<String, dynamic>> logs = [];

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return settings[key] ?? defaultValue;
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    settings[key] = value;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    logs.add({'action': action, 'details': details});
  }
}

void main() {
  group('StorageService Bulk Operations', () {
    late MockStorageService storage;

    setUp(() {
      storage = MockStorageService();
    });

    test('bulkArchiveChats adds chats to archive list', () async {
      storage.settings[AppConstants.archivedChatsKey] = <String>['old-1'];
      storage.settings[AppConstants.pinnedChatsKey] = <String>['chat-1']; // Pinned should be unpinned

      await storage.bulkArchiveChats(['chat-1', 'chat-2']);

      final archived = storage.settings[AppConstants.archivedChatsKey] as List<String>;
      final pinned = storage.settings[AppConstants.pinnedChatsKey] as List<String>;

      expect(archived, containsAll(['old-1', 'chat-1', 'chat-2']));
      expect(pinned, isEmpty); // chat-1 should be unpinned
      expect(storage.logs.any((l) => l['action'] == 'Bulk Archive'), true);
    });

    test('bulkUnarchiveChats removes chats from archive list', () async {
      storage.settings[AppConstants.archivedChatsKey] = <String>['chat-1', 'chat-2', 'chat-3'];

      await storage.bulkUnarchiveChats(['chat-1', 'chat-3']);

      final archived = storage.settings[AppConstants.archivedChatsKey] as List<String>;
      expect(archived, equals(['chat-2']));
      expect(storage.logs.any((l) => l['action'] == 'Bulk Unarchive'), true);
    });

    test('bulkAddTagsToChats adds tags to multiple chats', () async {
      // Setup existing tags
      storage.settings[AppConstants.chatTagsKey] = {
        'chat-1': ['tag1'],
        'chat-2': ['tag2'],
      };

      await storage.bulkAddTagsToChats(['chat-1', 'chat-2', 'chat-3'], ['new-tag']);

      final tagsMap = storage.settings[AppConstants.chatTagsKey] as Map;

      expect((tagsMap['chat-1'] as List).contains('tag1'), true);
      expect((tagsMap['chat-1'] as List).contains('new-tag'), true);

      expect((tagsMap['chat-2'] as List).contains('tag2'), true);
      expect((tagsMap['chat-2'] as List).contains('new-tag'), true);

      expect((tagsMap['chat-3'] as List).contains('new-tag'), true);

      expect(storage.logs.any((l) => l['action'] == 'Bulk Tag'), true);
    });
  });
}
