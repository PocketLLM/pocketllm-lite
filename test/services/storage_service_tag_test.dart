import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends StorageService {
  final Map<String, List<String>> _tagsMap = {};
  final List<Map<String, dynamic>> logs = [];

  @override
  Map<String, List<String>> getChatTagsMap() {
    return _tagsMap;
  }

  @override
  Future<void> saveChatTags(Map<String, List<String>> tags) async {
    // In-memory update is already happening because we return a reference to _tagsMap
    // but we can simulate persistence or just do nothing as _tagsMap is the source of truth
  }

  @override
  Future<void> logActivity(String action, String details) async {
    logs.add({'action': action, 'details': details});
  }
}

void main() {
  group('StorageService Tags', () {
    late MockStorageService storage;

    setUp(() {
      storage = MockStorageService();
      // Setup initial state
      storage.getChatTagsMap()['chat1'] = ['work', 'urgent'];
      storage.getChatTagsMap()['chat2'] = ['work'];
      storage.getChatTagsMap()['chat3'] = ['personal'];
    });

    test('getTagUsageCounts returns correct counts', () {
      final counts = storage.getTagUsageCounts();
      expect(counts['work'], 2);
      expect(counts['urgent'], 1);
      expect(counts['personal'], 1);
    });

    test('renameTag renames tag in all chats', () async {
      await storage.renameTag('work', 'office');

      expect(storage.getChatTagsMap()['chat1'], contains('office'));
      expect(storage.getChatTagsMap()['chat1'], isNot(contains('work')));
      expect(storage.getChatTagsMap()['chat2'], contains('office'));

      expect(storage.logs.last['action'], 'Tag Renamed');
    });

    test('renameTag merges if new tag exists', () async {
      // chat1 has 'work' and 'urgent'
      // Rename 'urgent' to 'work' -> should result in just 'work' (no duplicates)
      await storage.renameTag('urgent', 'work');

      expect(storage.getChatTagsMap()['chat1']!.length, 1);
      expect(storage.getChatTagsMap()['chat1'], contains('work'));
    });

    test('deleteTagGlobal removes tag from all chats', () async {
      await storage.deleteTagGlobal('work');

      expect(storage.getChatTagsMap()['chat1'], contains('urgent')); // urgent remains
      expect(storage.getChatTagsMap()['chat1'], isNot(contains('work')));

      // chat2 had only 'work', should disappear from map
      expect(storage.getChatTagsMap().containsKey('chat2'), false);

      expect(storage.logs.last['action'], 'Tag Deleted');
    });
  });
}
