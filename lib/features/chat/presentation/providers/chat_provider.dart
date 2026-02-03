import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_session.dart';
import '../../domain/models/text_file_attachment.dart';
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
  final int topK;
  final String streamingContent;

  ChatState({
    required this.messages,
    required this.isGenerating,
    this.currentSessionId,
    this.selectedModel = 'llama3',
    this.systemPrompt,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.streamingContent = '',
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    String? currentSessionId,
    String? selectedModel,
    String? systemPrompt,
    double? temperature,
    double? topP,
    int? topK,
    String? streamingContent,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      selectedModel: selectedModel ?? this.selectedModel,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      streamingContent: streamingContent ?? this.streamingContent,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  static final _wordRegExp = RegExp(r'\S+');

  @override
  ChatState build() {
    return ChatState(messages: [], isGenerating: false, streamingContent: '');
  }

  void setModel(String model) {
    // If we are starting a new chat (no messages), load the model's settings
    if (state.messages.isEmpty) {
      final storage = ref.read(storageServiceProvider);
      final key = '${AppConstants.modelSettingsPrefixKey}$model';
      final settings = storage.getSetting(key);

      if (settings != null && settings is Map) {
        state = state.copyWith(
          selectedModel: model,
          systemPrompt: settings['systemPrompt'],
          temperature: (settings['temperature'] as num?)?.toDouble() ?? 0.7,
          topP: (settings['topP'] as num?)?.toDouble() ?? 0.9,
          topK: (settings['topK'] as num?)?.toInt() ?? 40,
        );
        return;
      }
    }
    state = state.copyWith(selectedModel: model);
  }

  void updateSettings({
    String? systemPrompt,
    double? temperature,
    double? topP,
    int? topK,
  }) {
    state = state.copyWith(
      systemPrompt: systemPrompt,
      temperature: temperature,
      topP: topP,
      topK: topK,
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
      topK: session.topK ?? 40,
    );
  }

  void newChat() {
    // Load default model if available
    final storage = ref.read(storageServiceProvider);
    final defaultModel = storage.getSetting(AppConstants.defaultModelKey);
    final modelToUse = defaultModel ?? state.selectedModel;

    // Load settings for modelToUse
    final key = '${AppConstants.modelSettingsPrefixKey}$modelToUse';
    final settings = storage.getSetting(key);

    String? sysPrompt;
    double temp = 0.7;
    double topP = 0.9;
    int topK = 40;

    if (settings != null && settings is Map) {
      sysPrompt = settings['systemPrompt'];
      temp = (settings['temperature'] as num?)?.toDouble() ?? 0.7;
      topP = (settings['topP'] as num?)?.toDouble() ?? 0.9;
      topK = (settings['topK'] as num?)?.toInt() ?? 40;
    }

    state = ChatState(
      messages: [],
      isGenerating: false,
      selectedModel: modelToUse,
      systemPrompt: sysPrompt,
      temperature: temp,
      topP: topP,
      topK: topK,
      streamingContent: '',
    );
  }

  /// Estimate tokens from text (rough approximation: words * 1.3)
  static int _estimateTokens(String text) {
    final words = _wordRegExp.allMatches(text).length;
    return (words * 1.3).ceil();
  }

  String _buildAttachmentContext(
    String content,
    List<TextFileAttachment> attachments,
  ) {
    if (attachments.isEmpty) return content;
    final buffer = StringBuffer(content.trim());
    buffer.writeln('\n\n---');
    buffer.writeln('Attached files:');
    for (final attachment in attachments) {
      buffer.writeln('Filename: ${attachment.name}');
      buffer.writeln('```');
      buffer.writeln(attachment.content);
      buffer.writeln('```');
    }
    return buffer.toString();
  }

  String _buildMessageContent(ChatMessage message) {
    if (message.role != 'user') return message.content;
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) {
      return message.content;
    }
    return _buildAttachmentContext(message.content, attachments);
  }

  Future<void> sendMessage(
    String text, {
    List<String>? images,
    List<TextFileAttachment>? attachments,
  }) async {
    if (state.isGenerating) return;

    final userMsg = ChatMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
      images: images,
      attachments: attachments,
    );

    final nextMessages = [...state.messages, userMsg];
    final inputForTokens = attachments == null || attachments.isEmpty
        ? text
        : _buildAttachmentContext(text, attachments);
    await _generateAssistantResponse(nextMessages, userInput: inputForTokens);
  }

  void deleteMessage(ChatMessage message) {
    final updatedMessages = state.messages.where((m) => m != message).toList();
    state = state.copyWith(messages: updatedMessages);
    _saveSession();
  }

  Future<void> editMessage(ChatMessage message, String newContent,
      {List<TextFileAttachment>? attachments}) async {
    if (state.isGenerating) return;

    final index = state.messages.indexOf(message);
    if (index == -1) {
      await sendMessage(newContent, attachments: attachments);
      return;
    }

    final updated = message.copyWith(
      content: newContent,
      attachments: attachments,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [
      ...state.messages.take(index),
      updated,
    ];

    final inputForTokens = attachments == null || attachments.isEmpty
        ? newContent
        : _buildAttachmentContext(newContent, attachments);
    await _generateAssistantResponse(updatedMessages, userInput: inputForTokens);
  }

  Future<void> regenerateMessage(ChatMessage assistantMessage) async {
    if (state.isGenerating) return;

    final index = state.messages.indexOf(assistantMessage);
    if (index == -1 || index == 0) return;

    final updatedMessages = state.messages.take(index).toList();
    await _generateAssistantResponse(updatedMessages);
  }

  Future<void> _generateAssistantResponse(
    List<ChatMessage> baseMessages, {
    String? userInput,
  }) async {
    state = state.copyWith(
      messages: baseMessages,
      isGenerating: true,
      streamingContent: '',
    );

    final ollama = ref.read(ollamaServiceProvider);
    final history = baseMessages
        .map(
          (m) => {
            "role": m.role,
            "content": _buildMessageContent(m),
            "images": m.images,
          },
        )
        .toList();

    try {
      final options = {
        "temperature": state.temperature,
        "top_p": state.topP,
        "top_k": state.topK,
      };

      final stream = ollama.generateChatStream(
        state.selectedModel,
        history,
        options: options,
        system: state.systemPrompt,
      );

      final hapticEnabled = ref
          .read(storageServiceProvider)
          .getSetting(AppConstants.hapticFeedbackKey, defaultValue: true);

      final buffer = StringBuffer();
      DateTime? lastHapticTime;
      DateTime? lastUiUpdateTime;

      await for (final chunk in stream) {
        final now = DateTime.now();
        if (hapticEnabled) {
          if (lastHapticTime == null ||
              now.difference(lastHapticTime) >
                  const Duration(milliseconds: 100)) {
            HapticFeedback.lightImpact();
            lastHapticTime = now;
          }
        }
        buffer.write(chunk);

        // Optimize: Throttle UI updates to ~20 FPS (50ms) to prevent excessive
        // rebuilds and Markdown re-parsing on every token.
        if (lastUiUpdateTime == null ||
            now.difference(lastUiUpdateTime) >
                const Duration(milliseconds: 50)) {
          state = state.copyWith(streamingContent: buffer.toString());
          lastUiUpdateTime = now;
        }
      }

      final assistantContent = buffer.toString();
      if (state.streamingContent != assistantContent) {
        state = state.copyWith(streamingContent: assistantContent);
      }

      final assistantMessage = ChatMessage(
        role: 'assistant',
        content: assistantContent,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...baseMessages, assistantMessage],
        streamingContent: '',
      );

      if (userInput != null) {
        final userTokens = _estimateTokens(userInput);
        final aiTokens = _estimateTokens(assistantContent);
        final totalTokens = userTokens + aiTokens;
        await ref.read(usageLimitsProvider.notifier).consumeTokens(totalTokens);
      }
    } catch (e) {
      // Handle potential errors, e.g., show a message to the user
    } finally {
      state = state.copyWith(isGenerating: false, streamingContent: '');
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
      topK: state.topK,
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
