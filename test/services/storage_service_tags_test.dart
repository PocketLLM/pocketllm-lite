import 'package:flutter_test/flutter_test.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class TestStorageService extends StorageService {
  Map<String, List<String>> _tagsMap = {};

  void setMockTags(Map<String, List<String>> tags) {
    _tagsMap = Map<String, List<String>>.from(tags);
  }

  @override
  Map<String, List<String>> getChatTagsMap() {
    return _tagsMap;
  }

  @override
  Future<void> saveChatTags(Map<String, List<String>> tagsMap) async {
    _tagsMap = Map<String, List<String>>.from(tagsMap);
  }

  @override
  Future<void> logActivity(String action, String details) async {
    // No-op for testing
  }
}

void main() {
  group('StorageService Tag Management', () {
    late TestStorageService storageService;

    setUp(() {
      storageService = TestStorageService();
      storageService.setMockTags({
        'chat1': ['flutter', 'dart'],
        'chat2': ['flutter', 'mobile'],
        'chat3': ['ai', 'python'],
      });
    });

    test('renameTag renames tag globally', () async {
      await storageService.renameTag('flutter', 'flutter_dev');

      final map = storageService.getChatTagsMap();
      expect(map['chat1'], contains('flutter_dev'));
      expect(map['chat1'], isNot(contains('flutter')));
      expect(map['chat2'], contains('flutter_dev'));
      expect(map['chat2'], isNot(contains('flutter')));
      expect(map['chat3'], contains('ai')); // Unaffected
    });

    test('renameTag handles merge scenario', () async {
      // chat1 has 'flutter' and 'dart'.
      // Rename 'dart' to 'flutter'.
      // Result: chat1 should have 'flutter' (only once).

      await storageService.renameTag('dart', 'flutter');

      final map = storageService.getChatTagsMap();
      expect(map['chat1'], contains('flutter'));
      expect(map['chat1']!.where((t) => t == 'flutter').length, 1); // No duplicates
      expect(map['chat1'], isNot(contains('dart')));
    });

    test('deleteTag removes tag globally', () async {
      await storageService.deleteTag('flutter');

      final map = storageService.getChatTagsMap();
      expect(map['chat1'], isNot(contains('flutter')));
      expect(map['chat2'], isNot(contains('flutter')));
      expect(map['chat1'], contains('dart')); // Other tags remain
    });

    test('deleteTag removes chat entry if list becomes empty', () async {
      // chat3 has ['ai', 'python']
      await storageService.deleteTag('ai');
      await storageService.deleteTag('python');

      final map = storageService.getChatTagsMap();
      expect(map.containsKey('chat3'), false);
    });

    test('addTagToChat works', () async {
      await storageService.addTagToChat('chat1', 'new_tag');
      final map = storageService.getChatTagsMap();
      expect(map['chat1'], contains('new_tag'));
    });

    test('removeTagFromChat works', () async {
      await storageService.removeTagFromChat('chat1', 'dart');
      final map = storageService.getChatTagsMap();
      expect(map['chat1'], isNot(contains('dart')));
    });
  });
}
