import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  Map<String, List<String>> _mockTags = {};
  List<Map<String, dynamic>> logs = [];

  // Initialize with some data
  void setTags(Map<String, List<String>> tags) {
    // Deep copy to avoid reference issues
    _mockTags = tags.map((k, v) => MapEntry(k, List<String>.from(v)));
  }

  @override
  Map<String, List<String>> getChatTagsMap() {
    return _mockTags;
  }

  @override
  Future<void> saveChatTagsMap(Map<String, List<String>> map) async {
    _mockTags = map;
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
      storage.logs.clear();
    });

    test('renameTag renames tag across all chats', () async {
      storage.setTags({
        'chat1': ['work', 'important'],
        'chat2': ['work', 'todo'],
        'chat3': ['personal'],
      });

      await storage.renameTag('work', 'job');

      final tags = storage.getChatTagsMap();
      expect(tags['chat1'], contains('job'));
      expect(tags['chat1'], isNot(contains('work')));
      expect(tags['chat2'], contains('job'));
      expect(tags['chat2'], contains('todo'));
      expect(tags['chat3'], ['personal']); // Unchanged

      expect(storage.logs.last['action'], 'Tag Renamed');
    });

    test('renameTag merges if new tag exists', () async {
      storage.setTags({
        'chat1': ['work', 'job'], // Already has both
      });

      await storage.renameTag('work', 'job');

      final tags = storage.getChatTagsMap();
      // Should remove 'work', 'job' is already there
      expect(tags['chat1'], ['job']);
      expect(tags['chat1']!.length, 1);
    });

    test('deleteTag removes tag from all chats', () async {
      storage.setTags({
        'chat1': ['work', 'important'],
        'chat2': ['work'],
      });

      await storage.deleteTag('work');

      final tags = storage.getChatTagsMap();
      expect(tags['chat1'], ['important']);
      expect(tags.containsKey('chat2'), false); // Should remove entry if empty

      expect(storage.logs.last['action'], 'Tag Deleted');
    });
  });
}
