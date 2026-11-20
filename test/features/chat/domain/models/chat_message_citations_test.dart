import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('chat-citations-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'citation snippets and retrieval status survive chat persistence',
    () async {
      final box = await Hive.openBox<ChatMessage>('messages');
      final message = ChatMessage(
        role: 'assistant',
        content: 'The answer is supported [Evidence.pdf, page 2].',
        timestamp: DateTime.utc(2026),
        citations: const [
          {
            'chunkId': 'chunk-1',
            'documentId': 'doc-1',
            'label': '[Evidence.pdf, page 2]',
            'filename': 'Evidence.pdf',
            'page': 2,
            'snippet': 'The exact supporting passage.',
          },
        ],
        hasRetrievedSources: true,
      );

      await box.put('answer', message);
      final restored = box.get('answer')!;

      expect(restored.citations, hasLength(1));
      expect(
        restored.citations!.single['snippet'],
        'The exact supporting passage.',
      );
      expect(restored.citations!.single['page'], 2);
      expect(restored.hasRetrievedSources, isTrue);
    },
  );

  test('copyWith preserves citation metadata when editing message content', () {
    final message = ChatMessage(
      role: 'assistant',
      content: 'Original answer',
      timestamp: DateTime.utc(2026),
      citations: const [
        {'label': '[notes.txt, section 1]', 'snippet': 'Source text'},
      ],
      hasRetrievedSources: false,
    );

    final edited = message.copyWith(content: 'Edited answer');

    expect(edited.citations!.single['snippet'], 'Source text');
    expect(edited.hasRetrievedSources, isFalse);
  });
}
