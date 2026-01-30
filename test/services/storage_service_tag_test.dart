import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

// Subclass to mock Hive storage
class TestStorageService extends StorageService {
  Map<String, List<String>> _mockTagsMap = {};
  List<Map<String, dynamic>> logs = [];

  // Reset state for tests
  void reset() {
    _mockTagsMap = {};
    logs = [];
  }

  @override
  Map<String, List<String>> getChatTagsMap() {
    return _mockTagsMap;
  }

  @override
  Future<void> saveChatTagsMap(Map<String, List<String>> map) async {
    _mockTagsMap = map;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    logs.add({'action': action, 'details': details});
  }
}

void main() {
  group('StorageService Tag Management', () {
    late TestStorageService storage;

    setUp(() {
      storage = TestStorageService();
      storage.reset();
    });

    test('addTagToChat adds a tag and persists it', () async {
      const chatId = 'chat-1';
      const tag = 'Work';

      await storage.addTagToChat(chatId, tag);

      final tags = storage.getTagsForChat(chatId);
      expect(tags, contains(tag));
      expect(storage.logs.last['action'], 'Tag Added');
    });

    test('addTagToChat does not duplicate tags', () async {
      const chatId = 'chat-1';
      const tag = 'Work';

      await storage.addTagToChat(chatId, tag);
      await storage.addTagToChat(chatId, tag);

      final tags = storage.getTagsForChat(chatId);
      expect(tags.length, 1);
    });

    test('removeTagFromChat removes tag', () async {
      const chatId = 'chat-1';
      const tag = 'Work';

      await storage.addTagToChat(chatId, tag);
      await storage.removeTagFromChat(chatId, tag);

      final tags = storage.getTagsForChat(chatId);
      expect(tags, isEmpty);
      expect(storage.logs.last['action'], 'Tag Removed');
    });

    test('renameTag updates tag across multiple chats', () async {
      const chatId1 = 'chat-1';
      const chatId2 = 'chat-2';
      const oldTag = 'wrk';
      const newTag = 'Work';

      await storage.addTagToChat(chatId1, oldTag);
      await storage.addTagToChat(chatId2, oldTag);
      await storage.addTagToChat(chatId1, 'Other');

      await storage.renameTag(oldTag, newTag);

      // Check Chat 1
      final tags1 = storage.getTagsForChat(chatId1);
      expect(tags1, contains(newTag));
      expect(tags1, isNot(contains(oldTag)));
      expect(tags1, contains('Other'));

      // Check Chat 2
      final tags2 = storage.getTagsForChat(chatId2);
      expect(tags2, contains(newTag));
      expect(tags2, isNot(contains(oldTag)));

      expect(storage.logs.last['action'], 'Tag Renamed');
    });

    test('deleteTag removes tag from all chats', () async {
      const chatId1 = 'chat-1';
      const chatId2 = 'chat-2';
      const tag = 'Work';

      await storage.addTagToChat(chatId1, tag);
      await storage.addTagToChat(chatId1, 'Important');
      await storage.addTagToChat(chatId2, tag);

      await storage.deleteTag(tag);

      // Check Chat 1
      final tags1 = storage.getTagsForChat(chatId1);
      expect(tags1, isNot(contains(tag)));
      expect(tags1, contains('Important'));

      // Check Chat 2
      final tags2 = storage.getTagsForChat(chatId2);
      expect(tags2, isEmpty);

      expect(storage.logs.last['action'], 'Tag Deleted');
    });

    test('getChatCountForTag returns correct count', () async {
      const tag = 'Work';
      await storage.addTagToChat('chat-1', tag);
      await storage.addTagToChat('chat-2', tag);
      await storage.addTagToChat('chat-3', 'Other');

      final count = storage.getChatCountForTag(tag);
      expect(count, 2);
    });
  });
}
