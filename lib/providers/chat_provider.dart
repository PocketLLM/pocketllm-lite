import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../repositories/chat_repository.dart';
import '../services/storage_service.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import 'settings_provider.dart';
import 'ollama_provider.dart';

part 'chat_provider.g.dart';

@riverpod
StorageService storageService(StorageServiceRef ref) {
  // This needs to be initialized in main, but we provide access here.
  // Ideally, we treat it as a singleton or initialized instance.
  return StorageService();
}

@riverpod
ChatRepository chatRepository(ChatRepositoryRef ref) {
  return ChatRepository(ref.watch(storageServiceProvider));
}

@riverpod
class ChatHistory extends _$ChatHistory {
  @override
  List<ChatSession> build() {
    final repo = ref.watch(chatRepositoryProvider);
    // We should probably subscribe to changes if Hive supports it,
    // or manually invalidate on changes.
    // Hive's watch() is stream based. For now, simple fetch.
    return repo.getAllChats();
  }

  void refresh() {
    final repo = ref.read(chatRepositoryProvider);
    state = repo.getAllChats();
  }
}

@riverpod
class CurrentChatSession extends _$CurrentChatSession {
  @override
  ChatSession? build(String? chatId) {
    if (chatId == null) return null;
    // Accessing via storage service directly might be cleaner if repo doesn't expose getChat
    // But let's assume repo wraps it.
    // Wait, repo.getAllChats returns list.
    // Let's add getChat to repo interface implicitly via storage.
    // For now, find in list or fetch.
    return ref.read(storageServiceProvider).getChat(chatId);
  }

  void refresh() {
    if (state != null) {
      state = ref.read(storageServiceProvider).getChat(state!.id);
    }
  }
}

// Logic for sending message and handling stream
@riverpod
class ChatController extends _$ChatController {
  @override
  Future<void> build() async {
    // idle
  }

  Future<void> sendMessage({
    required String chatId,
    required String message,
    required String modelId,
    String? imageBase64,
  }) async {
    state = const AsyncLoading();

    final repo = ref.read(chatRepositoryProvider);
    final ollama = ref.read(ollamaServiceProvider);
    final settings = await ref.read(settingsProvider.future);

    // 1. Add User Message
    final userMsg = ChatMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
      imageBase64: imageBase64,
    );
    await repo.addMessage(chatId, userMsg);

    // Refresh UI
    ref.read(chatHistoryProvider.notifier).refresh();
    ref.invalidate(currentChatSessionProvider(chatId));

    // 2. Stream Response
    try {
      final stream = ollama.generateResponse(
        baseUrl: settings.ollamaEndpoint,
        model: modelId,
        prompt:
            message, // Simplification: full context handling usually requires sending history
        images: imageBase64 != null ? [imageBase64] : null,
      );

      // Create placeholder AI message
      final aiMsg = ChatMessage(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
      );
      await repo.addMessage(chatId, aiMsg); // Add empty first

      String fullResponse = '';

      await for (final chunk in stream) {
        fullResponse += chunk;
        // Updating UI with partial response would go here
      }

      // Update the final message in Hive
      // We need to remove the placeholder and add the full one, or update it.
      // Since Hive objects are mutable if they extend HiveObject (which they do),
      // we can theoretically update it.
      // But `ChatSession` holds a List<ChatMessage>. ChatMessage is HiveObject.
      // So we can update the message instance?
      // `ChatMessage` is defined as HiveObject.

      // Let's retrieve the session and update the last message.
      final session = ref.read(storageServiceProvider).getChat(chatId);
      if (session != null && session.messages.isNotEmpty) {
        final lastMsg = session.messages.last;
        if (!lastMsg.isUser) {
          // This is risky if user sent another message in between, but unlikely in single stream.
          // Ideally we track message ID or index.
          // For now, let's assume we replace the last message.
          session.messages.removeLast();
          session.messages.add(
            ChatMessage(
              text: fullResponse,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          await session.save(); // Save the session (and its list)
        }
      }

      ref.read(chatHistoryProvider.notifier).refresh();
      ref.invalidate(currentChatSessionProvider(chatId));

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
