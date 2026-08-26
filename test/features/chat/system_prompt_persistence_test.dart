import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

void main() {
  test('backfills and persists prompt identity from exact stored content',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('pocketllm_prompt_identity_');
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    final first = StorageService();
    await first.init(testPath: directory.path);
    final prompt = first.getSystemPrompts().first;
    await first.saveChatSession(
      ChatSession(
        id: 'prompt-chat',
        title: 'Prompt chat',
        model: 'fixture-model',
        messages: const [],
        createdAt: DateTime.utc(2026, 8, 26),
        systemPrompt: prompt.content,
      ),
      log: false,
    );
    await Hive.close();

    final restarted = StorageService();
    await restarted.init(testPath: directory.path);
    final restored = restarted.getChatSession('prompt-chat')!;
    expect(restored.systemPromptId, prompt.id);
    expect(restored.systemPrompt, prompt.content);
  });
}
