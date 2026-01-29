import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final Map<String, dynamic> settings = {};
  final List<Map<String, dynamic>> logs = [];
  final List<ChatSession> mockSessions = [];

  MockStorageService() {
    // Initialize default values
    settings[AppConstants.pinnedChatsKey] = <String>[];
    settings[AppConstants.archivedChatsKey] = <String>[];
    settings[AppConstants.chatTagsKey] = <dynamic, dynamic>{};
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    settings[key] = value;
  }

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return settings[key] ?? defaultValue;
  }

  @override
  Future<void> logActivity(String action, String details) async {
    logs.add({'action': action, 'details': details});
  }

  @override
  List<ChatSession> getChatSessions() => mockSessions;

  @override
  List<SystemPrompt> getSystemPrompts() => [];
}

void main() {
  group('StorageService Bulk Operations', () {
    late MockStorageService storage;

    setUp(() {
      storage = MockStorageService();
    });

    test('pinChats pins multiple chats', () async {
      final ids = ['1', '2'];
      await storage.pinChats(ids);

      final pinned = storage.getPinnedChatIds();
      expect(pinned, containsAll(['1', '2']));
      expect(storage.logs.last['action'], 'Chats Pinned');
    });

    test('pinChats ignores already pinned', () async {
      storage.settings[AppConstants.pinnedChatsKey] = ['1'];
      await storage.pinChats(['1', '2']);

      final pinned = storage.getPinnedChatIds();
      expect(pinned.length, 2);
      expect(pinned, containsAll(['1', '2']));
    });

    test('unpinChats unpins multiple chats', () async {
      storage.settings[AppConstants.pinnedChatsKey] = ['1', '2', '3'];
      await storage.unpinChats(['1', '2']);

      final pinned = storage.getPinnedChatIds();
      expect(pinned.length, 1);
      expect(pinned.first, '3');
      expect(storage.logs.last['action'], 'Chats Unpinned');
    });

    test('archiveChats archives multiple chats and unpins them', () async {
      storage.settings[AppConstants.pinnedChatsKey] = ['1'];
      await storage.archiveChats(['1', '2']);

      final archived = storage.getArchivedChatIds();
      expect(archived, containsAll(['1', '2']));

      final pinned = storage.getPinnedChatIds();
      expect(pinned, isEmpty); // '1' should be unpinned

      expect(storage.logs.last['action'], 'Chats Archived');
    });

    test('unarchiveChats unarchives multiple chats', () async {
      storage.settings[AppConstants.archivedChatsKey] = ['1', '2', '3'];
      await storage.unarchiveChats(['1', '2']);

      final archived = storage.getArchivedChatIds();
      expect(archived.length, 1);
      expect(archived.first, '3');
      expect(storage.logs.last['action'], 'Chats Unarchived');
    });

    test('addTagToChats adds tag to multiple chats', () async {
      await storage.addTagToChats(['1', '2'], 'Work');

      final tags1 = storage.getTagsForChat('1');
      final tags2 = storage.getTagsForChat('2');

      expect(tags1, contains('Work'));
      expect(tags2, contains('Work'));
      expect(storage.logs.last['action'], 'Tag Added');
    });

    test('addTagToChats avoids duplicates', () async {
      // Setup initial tag for '1' using addTagToChats (or manually setting settings)
      // Manually setting settings is safer given _getChatTagsMap behavior
      storage.settings[AppConstants.chatTagsKey] = {
        '1': ['Work']
      };

      await storage.addTagToChats(['1', '2'], 'Work');

      final tags1 = storage.getTagsForChat('1');
      expect(tags1.length, 1); // Should still be 1
      expect(tags1.first, 'Work');
    });

    test('removeTagFromChats removes tag from multiple chats', () async {
      storage.settings[AppConstants.chatTagsKey] = {
        '1': ['Work', 'Important'],
        '2': ['Work']
      };

      await storage.removeTagFromChats(['1', '2'], 'Work');

      final tags1 = storage.getTagsForChat('1');
      final tags2 = storage.getTagsForChat('2');

      expect(tags1, isNot(contains('Work')));
      expect(tags1, contains('Important'));
      expect(tags2, isEmpty);
      expect(storage.logs.last['action'], 'Tag Removed');
    });
  });
}
