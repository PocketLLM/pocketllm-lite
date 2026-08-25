import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

void main() {
  late Directory directory;
  late StorageService storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pocketllm-restore-');
    storage = StorageService();
    await storage.init(testPath: directory.path);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('a failure after writes rolls every storage collection back', () async {
    final existing = ChatSession(
      id: 'existing',
      title: 'Keep me',
      model: 'local-model',
      messages: [
        ChatMessage(
          role: 'user',
          content: 'Existing data',
          timestamp: DateTime.utc(2026),
        ),
      ],
      createdAt: DateTime.utc(2026),
    );
    await storage.saveChatSession(existing, log: false);

    final restore = storage.restoreBackupDataAtomically(
      {
        'chats': [
          {
            'id': 'new',
            'title': 'New data',
            'model': 'local-model',
            'messages': <dynamic>[],
            'createdAt': DateTime.utc(2026, 2).toIso8601String(),
          },
        ],
        'settings': {'theme_mode': 'dark'},
      },
      afterStorageWrite: () async => throw StateError('document failure'),
    );

    await expectLater(restore, throwsStateError);
    expect(storage.getChatSession('existing')?.title, 'Keep me');
    expect(storage.getChatSession('new'), isNull);
    expect(storage.getSetting('theme_mode'), isNull);
  });

  test('successful restore commits skills, memories, settings, and chats',
      () async {
    final result = await storage.restoreBackupDataAtomically({
      'chats': [
        {
          'id': 'restored-chat',
          'title': 'Restored',
          'model': 'model-a',
          'messages': <dynamic>[],
          'createdAt': DateTime.utc(2026, 3).toIso8601String(),
        },
      ],
      'skills': [
        {
          'id': 'restored-skill',
          'title': 'Restored skill',
          'description': 'Test',
          'body': 'Do verified work.',
          'isEnabled': true,
        },
      ],
      'memories': [
        {
          'id': 'memory-1',
          'type': 'preference',
          'subject': 'user',
          'fact': 'Prefers concise answers',
          'confidence': 0.9,
          'createdAt': DateTime.utc(2026).toIso8601String(),
        },
      ],
      'settings': {'theme_mode': 'dark'},
    });

    expect(result['chats'], 1);
    expect(result['skills'], 1);
    expect(result['memories'], 1);
    expect(storage.getChatSession('restored-chat'), isNotNull);
    expect(storage.getSkills().any((skill) => skill.id == 'restored-skill'),
        isTrue);
    expect(storage.getSetting('theme_mode'), 'dark');
  });
}
