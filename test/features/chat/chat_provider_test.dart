import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/chat_provider.dart';
import 'package:pocketllm_lite/services/ollama_service.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/services/storage_service.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/services/usage_limits_provider.dart';
// import 'package:hive_flutter/hive_flutter.dart'; // Needed for ValueListenable

// Mock Classes
class MockOllamaService extends OllamaService {
  MockOllamaService() : super(); // Call default super constructor
  
  @override
  Stream<String> generateChatStream(
    String model,
    List<Map<String, dynamic>> messages, {
    Map<String, dynamic>? options,
    String? system,
  }) async* {
     // Verify messages order
     if (messages.last['content'] == 'ping') {
       yield 'pong';
     } else if (messages.last['content'] == 'stream') {
       yield 'c';
       await Future.delayed(const Duration(milliseconds: 10));
       yield 'h';
       await Future.delayed(const Duration(milliseconds: 10));
       yield 'u';
       await Future.delayed(const Duration(milliseconds: 10));
       yield 'n';
       await Future.delayed(const Duration(milliseconds: 10));
       yield 'k';
     }
  }
}

class MockStorageService extends StorageService {
  @override
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return defaultValue;
  }
  
  @override
  Future<void> saveChatSession(ChatSession session) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ChatNotifier maintains history and sends message correctly', () async {
    final mockOllama = MockOllamaService();
    final mockStorage = MockStorageService();

    final container = ProviderContainer(
      overrides: [
        ollamaServiceProvider.overrideWithValue(mockOllama),
        storageServiceProvider.overrideWithValue(mockStorage),
        usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
      ],
    );

    final notifier = container.read(chatProvider.notifier);
    
    // Initial state
    expect(container.read(chatProvider).messages.isEmpty, true);

    // Send a message
    await notifier.sendMessage('ping');

    final messages = container.read(chatProvider).messages;
    expect(messages.length, 2); // User + Assistant
    expect(messages[0].content, 'ping');
    expect(messages[0].role, 'user');
    expect(messages[1].content, 'pong');
    expect(messages[1].role, 'assistant');
  });

  test('ChatNotifier handles streamed response correctly', () async {
    final mockOllama = MockOllamaService();
    final mockStorage = MockStorageService();

    final container = ProviderContainer(
      overrides: [
        ollamaServiceProvider.overrideWithValue(mockOllama),
        storageServiceProvider.overrideWithValue(mockStorage),
        usageLimitsProvider.overrideWith(UsageLimitsNotifier.new),
      ],
    );

    final notifier = container.read(chatProvider.notifier);

    // Send a message that triggers the streaming response
    await notifier.sendMessage('stream');

    final messages = container.read(chatProvider).messages;
    expect(messages.length, 2);
    expect(messages[1].content, 'chunk');
    expect(messages[1].role, 'assistant');
  });
  
  test('ChatNotifier updates settings correctly', () {
      final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(MockStorageService()),
      ],
    );
    
    final notifier = container.read(chatProvider.notifier);
    
    notifier.updateSettings(
        temperature: 0.8,
        topP: 0.5,
        systemPrompt: 'Be concise',
    );
    
    final state = container.read(chatProvider);
    expect(state.temperature, 0.8);
    expect(state.topP, 0.5);
    expect(state.systemPrompt, 'Be concise');
  });
}