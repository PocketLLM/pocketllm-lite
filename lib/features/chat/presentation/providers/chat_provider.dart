import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_session.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final String? currentSessionId;
  final String selectedModel;

  ChatState({
    required this.messages,
    required this.isGenerating,
    this.currentSessionId,
    this.selectedModel = 'llama3',
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    String? currentSessionId,
    String? selectedModel,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      selectedModel: selectedModel ?? this.selectedModel,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    return ChatState(messages: [], isGenerating: false);
  }

  void setModel(String model) {
    state = state.copyWith(selectedModel: model);
  }

  void loadSession(ChatSession session) {
    state = state.copyWith(
      messages: session.messages,
      currentSessionId: session.id,
      selectedModel: session.model,
    );
  }

  void newChat() {
    state = ChatState(
      messages: [],
      isGenerating: false,
      selectedModel: state.selectedModel,
    );
  }

  Future<void> sendMessage(String text, {List<String>? images}) async {
    if (state.isGenerating) return;

    final userMsg = ChatMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
      images: images,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isGenerating: true,
    );

    final ollama = ref.read(ollamaServiceProvider);

    final history = state.messages
        .map(
          (m) => {
            "role": m.role,
            "content": m.content,
            if (m.images != null) "images": m.images,
          },
        )
        .toList();

    String assistantContent = '';

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(role: 'assistant', content: '', timestamp: DateTime.now()),
      ],
    );

    try {
      final stream = ollama.generateChatStream(state.selectedModel, history);

      await for (final chunk in stream) {
        assistantContent += chunk;

        final updatedMessages = List<ChatMessage>.from(state.messages);
        if (updatedMessages.last.role == 'assistant') {
          updatedMessages.last = updatedMessages.last.copyWith(
            content: assistantContent,
          );
          state = state.copyWith(messages: updatedMessages);
        }
      }
    } catch (e) {
      // Normally show snackbar or add error message
      // print(e);
    } finally {
      state = state.copyWith(isGenerating: false);
      _saveSession();
    }
  }

  Future<void> _saveSession() async {
    if (state.messages.isEmpty) return;

    final storage = ref.read(storageServiceProvider);
    final id = state.currentSessionId ?? const Uuid().v4();

    String title = 'Chat ${state.selectedModel}';
    final userMsg = state.messages.firstWhere(
      (m) => m.role == 'user',
      orElse: () =>
          ChatMessage(role: 'user', content: '', timestamp: DateTime.now()),
    );
    if (userMsg.content.isNotEmpty) {
      title = userMsg.content.split('\n').first;
      if (title.length > 30) title = '${title.substring(0, 30)}...';
    }

    final session = ChatSession(
      id: id,
      title: title,
      model: state.selectedModel,
      messages: state.messages,
      createdAt: DateTime.now(),
    );

    await storage.saveChatSession(session);

    if (state.currentSessionId == null) {
      state = state.copyWith(currentSessionId: id);
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
