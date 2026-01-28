import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class FakeBox<T> extends Fake implements Box<T> {
  final Map<dynamic, T> _data = {};

  @override
  bool get isOpen => true;

  @override
  bool get isEmpty => _data.isEmpty;

  @override
  Iterable<T> get values => _data.values;

  @override
  bool containsKey(key) => _data.containsKey(key);

  @override
  Future<void> put(key, value) async {
    _data[key] = value;
  }

  @override
  Future<int> add(value) async {
    final key = _data.length;
    _data[key] = value;
    return key;
  }

  @override
  T? get(key, {defaultValue}) {
    return _data[key] ?? defaultValue;
  }

  @override
  Future<void> delete(key) async {
    _data.remove(key);
  }

  @override
  Future<int> clear() async {
    final count = _data.length;
    _data.clear();
    return count;
  }

  @override
  ValueListenable<Box<T>> listenable({List<dynamic>? keys}) {
     return ValueNotifier(this);
  }
}

void main() {
  group('StorageService Data Remanence', () {
    late StorageService storageService;
    late FakeBox<ChatSession> fakeChatBox;
    late FakeBox<dynamic> fakeSettingsBox;
    late FakeBox<dynamic> fakeLogBox;

    setUp(() {
      storageService = StorageService();
      fakeChatBox = FakeBox<ChatSession>();
      fakeSettingsBox = FakeBox<dynamic>();
      fakeLogBox = FakeBox<dynamic>();

      // Inject fakes
      storageService.chatBox = fakeChatBox;
      storageService.settingsBox = fakeSettingsBox;
      storageService.activityLogBox = fakeLogBox;
    });

    test('deleteChatSession removes associated starred messages', () async {
      // 1. Setup Data
      const chatId = 'chat-1';
      final starredMessage = {
        'id': 'star-1',
        'chatId': chatId,
        'message': {
          'role': 'user',
          'content': 'Secret Info',
          'timestamp': DateTime.now().toIso8601String(),
        },
        'starredAt': DateTime.now().toIso8601String(),
      };

      // Add starred message to settings
      await fakeSettingsBox.put(AppConstants.starredMessagesKey, [starredMessage]);

      // 2. Execute
      await storageService.deleteChatSession(chatId);

      // 3. Verify
      final starred = fakeSettingsBox.get(AppConstants.starredMessagesKey) as List;
      expect(starred.isEmpty, true, reason: 'Starred message should be removed');
    });

    test('clearAllChats removes all starred messages', () async {
      // 1. Setup Data
      final starredMessage = {
        'id': 'star-1',
        'chatId': 'chat-1',
        'message': {
          'role': 'user',
          'content': 'Secret Info',
          'timestamp': DateTime.now().toIso8601String(),
        },
        'starredAt': DateTime.now().toIso8601String(),
      };

      await fakeSettingsBox.put(AppConstants.starredMessagesKey, [starredMessage]);

      // 2. Execute
      await storageService.clearAllChats();

      // 3. Verify
      final starred = fakeSettingsBox.get(AppConstants.starredMessagesKey);
      expect(starred, null, reason: 'Starred messages key should be deleted');
    });
  });
}
