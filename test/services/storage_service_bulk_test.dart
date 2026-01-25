import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  final Map<String, dynamic> _settings = {};
  final List<Map<String, dynamic>> _logs = [];

  @override
  Future<void> logActivity(String action, String details) async {
    _logs.add({'action': action, 'details': details});
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settings[key] ?? defaultValue;
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    _settings[key] = value;
  }

  // Helper to inspect internal state
  List<Map<String, dynamic>> get logs => _logs;
  Map<String, dynamic> get settings => _settings;
}

void main() {
  group('StorageService Bulk Operations', () {
    late TestStorageService storage;

    setUp(() {
      storage = TestStorageService();
    });

    test('bulkArchiveChats archives multiple chats and unpins them', () async {
      // Setup
      final chatIds = ['chat1', 'chat2', 'chat3'];
      await storage.saveSetting(AppConstants.pinnedChatsKey, ['chat2']); // chat2 is pinned

      // Execute
      await storage.bulkArchiveChats(chatIds);

      // Verify Archived
      final archived = storage.getArchivedChatIds();
      expect(archived.length, 3);
      expect(archived, containsAll(chatIds));

      // Verify Pinned (chat2 should be removed)
      final pinned = storage.getPinnedChatIds();
      expect(pinned.contains('chat2'), false);

      // Verify Log
      expect(storage.logs.last['action'], 'Bulk Archive');
    });

    test('bulkAddTagsToChats adds tags to multiple chats', () async {
      // Setup
      final chatIds = ['chat1', 'chat2'];
      // chat1 already has "work"
      await storage.saveSetting(AppConstants.chatTagsKey, {
        'chat1': ['work']
      });

      // Execute: Add "important" to both
      await storage.bulkAddTagsToChats(chatIds, ['important']);

      // Verify
      final tags1 = storage.getTagsForChat('chat1');
      expect(tags1, containsAll(['work', 'important']));

      final tags2 = storage.getTagsForChat('chat2');
      expect(tags2, contains('important'));

      // Verify Log
      expect(storage.logs.last['action'], 'Bulk Tagging');
    });
  });
}
