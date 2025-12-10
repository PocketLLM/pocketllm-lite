import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_session.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/usage_limits_provider.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final String? currentSessionId;
  final String selectedModel;
  final String? systemPrompt;
  final double temperature;
  final double topP;

  ChatState({
    required this.messages,
    required this.isGenerating,
    this.currentSessionId,
    this.selectedModel = 'llama3',
    this.systemPrompt,
    this.temperature = 0.7,
    this.topP = 0.9,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    String? currentSessionId,
    String? selectedModel,
    String? systemPrompt,
    double? temperature,
    double? topP,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      selectedModel: selectedModel ?? this.selectedModel,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
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

  void updateSettings({
    String? systemPrompt,
    double? temperature,
    double? topP,
  }) {
    state = state.copyWith(
      systemPrompt: systemPrompt,
      temperature: temperature,
      topP: topP,
    );
  }

  void loadSession(ChatSession session) {
    state = state.copyWith(
      messages: session.messages,
      currentSessionId: session.id,
      selectedModel: session.model,
      systemPrompt: session.systemPrompt,
      temperature: session.temperature ?? 0.7,
      topP: session.topP ?? 0.9,
    );
  }

  void newChat() {
    // Load default model if available
    final storage = ref.read(storageServiceProvider);
    final defaultModel = storage.getSetting(AppConstants.defaultModelKey);
    final modelToUse = defaultModel ?? state.selectedModel;

    state = ChatState(
      messages: [],
      isGenerating: false,
      selectedModel: modelToUse,
      systemPrompt: state.systemPrompt,
      temperature: 0.7,
      topP: 0.9,
    );
  }

  /// Estimate tokens from text (rough approximation: words * 1.3)
  static int _estimateTokens(String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return (words * 1.3).ceil();
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
            "images": m.images,
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
      final options = {"temperature": state.temperature, "top_p": state.topP};

      final stream = ollama.generateChatStream(
        state.selectedModel,
        history,
        options: options,
        system: state
            .systemPrompt, // We pass system string, service handles it (conceptually)
      );

      final hapticEnabled = ref
          .read(storageServiceProvider)
          .getSetting(AppConstants.hapticFeedbackKey, defaultValue: true);

      await for (final chunk in stream) {
        if (hapticEnabled) HapticFeedback.lightImpact();
        assistantContent += chunk;

        final updatedMessages = List<ChatMessage>.from(state.messages);
        if (updatedMessages.last.role == 'assistant') {
          updatedMessages.last = updatedMessages.last.copyWith(
            content: assistantContent,
          );
          state = state.copyWith(messages: updatedMessages);
        }
      }
      
      // Estimate and consume tokens after the response is complete
      // Estimate tokens for both user input and AI response
      final userTokens = _estimateTokens(text);
      final aiTokens = _estimateTokens(assistantContent);
      final totalTokens = userTokens + aiTokens;
      
      // Consume tokens
      await ref.read(usageLimitsProvider.notifier).consumeTokens(totalTokens);
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
      systemPrompt: state.systemPrompt,
      temperature: state.temperature,
      topP: state.topP,
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
