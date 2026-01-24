import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pocketllm_lite/core/providers.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_message.dart';
import 'package:pocketllm_lite/features/chat/domain/models/chat_session.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/chat_provider.dart';
import 'package:pocketllm_lite/features/chat/presentation/providers/chat_selection_provider.dart';
import 'package:pocketllm_lite/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {
  @override
  Future<void> saveChatSession(ChatSession session, {bool log = true}) async {}

  @override
  Future<void> deleteChatSession(String id) async {}

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) => null;
}

void main() {
  group('Bulk Actions Tests', () {
    test('ChatSelectionNotifier toggles selection correctly', () {
      final container = ProviderContainer();
      final notifier = container.read(chatSelectionProvider.notifier);
      final message1 = ChatMessage(role: 'user', content: 'A', timestamp: DateTime.now());
      final message2 = ChatMessage(role: 'ai', content: 'B', timestamp: DateTime.now());

      // Enter selection
      notifier.enterSelectionMode(message1);
      expect(container.read(chatSelectionProvider).isSelectionMode, true);
      expect(container.read(chatSelectionProvider).selectedMessages.length, 1);
      expect(container.read(chatSelectionProvider).selectedMessages.contains(message1), true);

      // Toggle another
      notifier.toggleMessage(message2);
      expect(container.read(chatSelectionProvider).selectedMessages.length, 2);

      // Toggle first off
      notifier.toggleMessage(message1);
      expect(container.read(chatSelectionProvider).selectedMessages.length, 1);
      expect(container.read(chatSelectionProvider).selectedMessages.first, message2);

      // Exit
      notifier.exitSelectionMode();
      expect(container.read(chatSelectionProvider).isSelectionMode, false);
      expect(container.read(chatSelectionProvider).selectedMessages.isEmpty, true);
    });

    test('ChatNotifier deleteMessages removes multiple messages', () {
       final mockStorage = MockStorageService();
       final container = ProviderContainer(
         overrides: [
           storageServiceProvider.overrideWithValue(mockStorage),
         ],
       );

       // Setup initial state
       final notifier = container.read(chatProvider.notifier);
       final message1 = ChatMessage(role: 'user', content: '1', timestamp: DateTime.now());
       final message2 = ChatMessage(role: 'ai', content: '2', timestamp: DateTime.now());
       final message3 = ChatMessage(role: 'user', content: '3', timestamp: DateTime.now());

       // Manually seed state (since we can't easily modify protected state, we use loadSession)
       notifier.loadSession(ChatSession(
         id: 'test',
         title: 'test',
         model: 'model',
         messages: [message1, message2, message3],
         createdAt: DateTime.now(),
       ));

       // Delete 1 and 3
       notifier.deleteMessages([message1, message3]);

       final messages = container.read(chatProvider).messages;
       expect(messages.length, 1);
       expect(messages.first, message2);
    });
  });
}
