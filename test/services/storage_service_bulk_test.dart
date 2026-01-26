import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final List<Map<String, dynamic>> logs = [];
  Map<String, dynamic> settings = {};

  @override
  Future<void> logActivity(String action, String details) async {
    logs.add({'action': action, 'details': details});
  }

  @override
  List<ChatSession> getChatSessions() => [];

  @override
  List<SystemPrompt> getSystemPrompts() => [];

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return settings[key] ?? defaultValue;
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    settings[key] = value;
  }
}

void main() {
  group('StorageService Bulk Operations', () {
    late MockStorageService storage;

    setUp(() {
      storage = MockStorageService();
      // Initialize with empty lists
      storage.settings[AppConstants.archivedChatsKey] = <String>[];
      storage.settings[AppConstants.pinnedChatsKey] = <String>[];
      storage.settings[AppConstants.chatTagsKey] = <dynamic, dynamic>{};
    });

    test('bulkArchiveChats archives chats and unpins them', () async {
      storage.settings[AppConstants.pinnedChatsKey] = ['chat1', 'chat3'];

      await storage.bulkArchiveChats(['chat1', 'chat2']);

      final archived = storage.settings[AppConstants.archivedChatsKey] as List<String>;
      final pinned = storage.settings[AppConstants.pinnedChatsKey] as List<String>;

      expect(archived, contains('chat1'));
      expect(archived, contains('chat2'));
      expect(archived.length, 2);

      expect(pinned, isNot(contains('chat1'))); // Unpinned
      expect(pinned, contains('chat3')); // Kept
      expect(pinned.length, 1);

      expect(storage.logs.last['action'], 'Bulk Archive');
    });

    test('bulkAddTag adds tag to chats', () async {
      storage.settings[AppConstants.chatTagsKey] = {
        'chat1': ['existing'],
      };

      await storage.bulkAddTag(['chat1', 'chat2'], 'new_tag');

      // The map stored back in settings is the one modified by StorageService
      final tags = storage.settings[AppConstants.chatTagsKey] as Map;

      expect(tags['chat1'], contains('existing'));
      expect(tags['chat1'], contains('new_tag'));
      expect(tags['chat2'], contains('new_tag'));

      expect(storage.logs.last['action'], 'Bulk Tag');
    });

    test('bulkArchiveChats does nothing if empty list', () async {
      await storage.bulkArchiveChats([]);
      expect(storage.logs, isEmpty);
    });

    test('bulkAddTag does nothing if empty list', () async {
      await storage.bulkAddTag([], 'tag');
      expect(storage.logs, isEmpty);
    });
  });
}
