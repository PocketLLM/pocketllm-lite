import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/domain/models/system_prompt.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final Map<String, dynamic> settings = {};
  final List<Map<String, dynamic>> logs = [];

  // Override abstract or Hive-dependent methods
  @override
  Future<void> init() async {}

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

  // Necessary overrides to prevent crashes
  @override
  List<ChatSession> getChatSessions() => [];
  @override
  List<SystemPrompt> getSystemPrompts() => [];
}

void main() {
  group('StorageService Bulk Tagging', () {
    late MockStorageService storage;

    setUp(() {
      storage = MockStorageService();
      // Initialize with empty tags map
      storage.settings[AppConstants.chatTagsKey] = <String, List<String>>{};
    });

    test('bulkAddTagToChats adds tag to multiple chats', () async {
      final chatIds = ['chat1', 'chat2', 'chat3'];
      const tag = 'Work';

      await storage.bulkAddTagToChats(chatIds, tag);

      final tagsMap = storage.getChatTagsMap();

      expect(tagsMap['chat1'], contains(tag));
      expect(tagsMap['chat2'], contains(tag));
      expect(tagsMap['chat3'], contains(tag));

      // Verify log
      expect(storage.logs.length, 1);
      expect(storage.logs.first['action'], 'Bulk Tagging');
      expect(storage.logs.first['details'], contains('3 chats'));
    });

    test('bulkAddTagToChats ignores duplicates', () async {
      final chatIds = ['chat1'];
      const tag = 'Important';

      // First add
      await storage.bulkAddTagToChats(chatIds, tag);
      // Second add
      await storage.bulkAddTagToChats(chatIds, tag);

      final tagsMap = storage.getChatTagsMap();
      expect(tagsMap['chat1']!.where((t) => t == tag).length, 1);

      // Verify logs (second call shouldn't log if nothing changed)
      // Wait, my implementation logs if successCount > 0.
      // If tag exists, it's not added, so successCount is 0.
      expect(storage.logs.length, 1);
    });

    test('bulkAddTagToChats preserves existing tags', () async {
      final chatIds = ['chat1'];

      // Setup existing tag
      await storage.addTagToChat('chat1', 'Existing');

      // Bulk add new tag
      await storage.bulkAddTagToChats(chatIds, 'New');

      final tags = storage.getTagsForChat('chat1');
      expect(tags, contains('Existing'));
      expect(tags, contains('New'));
    });

    test('bulkAddTagToChats does nothing with empty list', () async {
      await storage.bulkAddTagToChats([], 'Tag');
      expect(storage.logs.isEmpty, true);
    });

    test('bulkAddTagToChats does nothing with empty tag', () async {
      await storage.bulkAddTagToChats(['chat1'], '');
      expect(storage.logs.isEmpty, true);
    });
  });
}
