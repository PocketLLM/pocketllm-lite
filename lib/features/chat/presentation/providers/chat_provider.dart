import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/providers.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_session.dart';
import '../../domain/models/text_file_attachment.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/inference_service.dart';
import '../../../../services/rag_service.dart';
import '../../domain/models/chat_persona.dart';
import '../../domain/models/skill.dart';
import '../../../../providers/model_manager_provider.dart';
import '../../../../models/local_model.dart';
import '../../../../services/generation_pipeline.dart';
import '../../../../core/navigation.dart';

class ThinkingParseResult {
  final String thinking;
  final String mainContent;
  ThinkingParseResult({required this.thinking, required this.mainContent});
}

ThinkingParseResult parseThinking(String rawText) {
  final List<MapEntry<String, String>> tags = [
    const MapEntry('<think>', '</think>'),
    const MapEntry('<thought>', '</thought>'),
    const MapEntry('<thinking>', '</thinking>'),
    const MapEntry('[thought]', '[/thought]'),
    const MapEntry('[thinking]', '[/thinking]'),
  ];

  for (final tag in tags) {
    if (rawText.contains(tag.key)) {
      final startIdx = rawText.indexOf(tag.key);
      final startLen = tag.key.length;
      if (rawText.contains(tag.value)) {
        final endIdx = rawText.indexOf(tag.value);
        final endLen = tag.value.length;
        final thinking = rawText.substring(startIdx + startLen, endIdx).trim();
        final mainContent = (rawText.substring(0, startIdx) +
                rawText.substring(endIdx + endLen))
            .trim();
        return ThinkingParseResult(
          thinking: thinking,
          mainContent: mainContent,
        );
      } else {
        final thinking = rawText.substring(startIdx + startLen).trim();
        final mainContent = rawText.substring(0, startIdx).trim();
        return ThinkingParseResult(
          thinking: thinking,
          mainContent: mainContent,
        );
      }
    }
  }

  final List<String> prefixes = ['thinking process:', 'thought:', 'thinking:'];

  final rawLower = rawText.toLowerCase().trim();
  for (final prefix in prefixes) {
    if (rawLower.startsWith(prefix)) {
      final startIndex = rawText.toLowerCase().indexOf(prefix) + prefix.length;
      int splitIndex = rawText.indexOf('\n\n', startIndex);
      if (splitIndex == -1) {
        splitIndex = rawText.indexOf('\r\n\r\n', startIndex);
      }

      if (splitIndex != -1) {
        final thinking = rawText.substring(startIndex, splitIndex).trim();
        final mainContent = rawText.substring(splitIndex).trim();
        return ThinkingParseResult(
          thinking: thinking,
          mainContent: mainContent,
        );
      }
    }
  }

  return ThinkingParseResult(thinking: '', mainContent: rawText);
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final bool isModelLoading;
  final String? currentSessionId;
  final String selectedModel;
  final String? systemPrompt;
  final double temperature;
  final double topP;
  final int topK;
  final String streamingContent;
  final String streamingThinkingContent;
  final bool useRag;
  final double? lastTps;
  final int? lastTtftMs;
  final String? activePersonaId;
  final bool useTools;
  final bool useWebSearch;
  final bool isSearchingWeb;

  ChatState({
    required this.messages,
    required this.isGenerating,
    this.isModelLoading = false,
    this.currentSessionId,
    this.selectedModel = 'llama3',
    this.systemPrompt,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.streamingContent = '',
    this.streamingThinkingContent = '',
    this.useRag = false,
    this.lastTps,
    this.lastTtftMs,
    this.activePersonaId = 'general_assistant',
    this.useTools = false,
    this.useWebSearch = false,
    this.isSearchingWeb = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    bool? isModelLoading,
    String? currentSessionId,
    String? selectedModel,
    String? systemPrompt,
    double? temperature,
    double? topP,
    int? topK,
    String? streamingContent,
    String? streamingThinkingContent,
    bool? useRag,
    double? lastTps,
    int? lastTtftMs,
    String? activePersonaId,
    bool? useTools,
    bool? useWebSearch,
    bool? isSearchingWeb,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      isModelLoading: isModelLoading ?? this.isModelLoading,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      selectedModel: selectedModel ?? this.selectedModel,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      streamingContent: streamingContent ?? this.streamingContent,
      streamingThinkingContent:
          streamingThinkingContent ?? this.streamingThinkingContent,
      useRag: useRag ?? this.useRag,
      lastTps: lastTps ?? this.lastTps,
      lastTtftMs: lastTtftMs ?? this.lastTtftMs,
      activePersonaId: activePersonaId ?? this.activePersonaId,
      useTools: useTools ?? this.useTools,
      useWebSearch: useWebSearch ?? this.useWebSearch,
      isSearchingWeb: isSearchingWeb ?? this.isSearchingWeb,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  static final _wordRegExp = RegExp(r'\S+');
  GenerationCancellationToken? _activeCancellation;

  @override
  ChatState build() {
    return ChatState(
      messages: [],
      isGenerating: false,
      isModelLoading: false,
      streamingContent: '',
      streamingThinkingContent: '',
      useRag: false,
      activePersonaId: 'general_assistant',
      useTools: false,
      useWebSearch: false,
      isSearchingWeb: false,
    );
  }

  void toggleRag() {
    state = state.copyWith(useRag: !state.useRag);
  }

  void toggleTools() {
    state = state.copyWith(useTools: !state.useTools);
  }

  void toggleWebSearch() {
    state = state.copyWith(useWebSearch: !state.useWebSearch);
  }

  void setPersona(ChatPersona persona) {
    state = state.copyWith(
      activePersonaId: persona.id,
      systemPrompt: persona.systemPrompt,
      temperature: persona.temperature,
    );
    if (persona.modelId != null) {
      setModel(persona.modelId!);
    }
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
      streamingThinkingContent: '',
      useRag: false,
      useWebSearch: false,
      isSearchingWeb: false,
    );
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

  Future<void> editMessage(
    ChatMessage message,
    String newContent, {
    List<TextFileAttachment>? attachments,
  }) async {
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

    final updatedMessages = [...state.messages.take(index), updated];

    final inputForTokens = attachments == null || attachments.isEmpty
        ? newContent
        : _buildAttachmentContext(newContent, attachments);
    await _generateAssistantResponse(
      updatedMessages,
      userInput: inputForTokens,
    );
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
    final localState = ref.read(modelManagerProvider);
    final isLocalModel = localState.models.containsKey(state.selectedModel) &&
        localState.models[state.selectedModel]?.status ==
            DownloadStatus.downloaded;

    final conversationId = state.currentSessionId ?? const Uuid().v4();
    _activeCancellation = GenerationCancellationToken();
    state = state.copyWith(
      messages: baseMessages,
      currentSessionId: conversationId,
      isGenerating: true,
      isModelLoading: isLocalModel,
      streamingContent: '',
      streamingThinkingContent: '',
      lastTps: 0.0,
      lastTtftMs: 0,
    );

    try {
      final messages = <ChatRequestMessage>[];
      for (int i = 0; i < baseMessages.length; i++) {
        final m = baseMessages[i];
        messages.add(
          ChatRequestMessage(
            role: m.role,
            content: _buildMessageContent(m),
            images: m.images,
          ),
        );
      }

      // Check for skill triggers inside user message
      final allSkills = ref.read(storageServiceProvider).getSkills();
      final activeSkills = <Skill>[];
      if (baseMessages.isNotEmpty) {
        final lastUserMessage = baseMessages.lastWhere(
          (m) => m.role == 'user',
          orElse: () => ChatMessage(
            role: 'user',
            content: '',
            timestamp: DateTime.now(),
          ),
        );
        if (lastUserMessage.content.isNotEmpty) {
          for (final skill in allSkills) {
            if (skill.isEnabled &&
                lastUserMessage.content.contains('/${skill.id}')) {
              activeSkills.add(skill);
            }
          }
        }
      }

      String? documentContext;
      if (state.useRag) {
        final userMessages = baseMessages
            .where((message) => message.role == 'user')
            .toList(growable: false);
        final query = userInput ??
            (userMessages.isEmpty ? null : userMessages.last.content);
        if (query != null && query.trim().isNotEmpty) {
          final retrieved = await ref
              .read(ragServiceProvider)
              .retrieveContext(query, topK: 4);
          documentContext = retrieved.promptContext;
        }
      }

      final request = ChatRequest(
        modelId: state.selectedModel,
        messages: messages,
        systemPrompt: state.systemPrompt,
        temperature: state.temperature,
        topP: state.topP,
        topK: state.topK,
      );

      final toolsEnabled = state.useTools || state.useWebSearch;
      final allowedTools = state.useTools
          ? (state.useWebSearch
              ? null
              : const <String>{
                  'calculator',
                  'system_info',
                  'clipboard',
                  'notes',
                  'reminders',
                  'draft_email',
                  'open_url',
                })
          : (state.useWebSearch ? const <String>{'web_search'} : null);
      final stream = ref.read(generationPipelineProvider).stream(
            request,
            options: GenerationOptions(
              enableTools: toolsEnabled,
              enableMemoryExtraction:
                  ref.read(storageServiceProvider).getSetting(
                            AppConstants.autoMemoryExtractionKey,
                            defaultValue: false,
                          ) ==
                      true,
              allowedTools: allowedTools,
              conversationId: conversationId,
              documentContext: documentContext,
              skillInstructions: activeSkills.map(
                (skill) => '${skill.title} (/${skill.id})\n${skill.body}',
              ),
              cancellationToken: _activeCancellation,
              confirmTool: (tool, call) async {
                final context = rootNavigatorKey.currentContext;
                if (context == null || !context.mounted) return false;
                return await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => AlertDialog(
                        icon: Icon(
                          Icons.security_rounded,
                          color: Theme.of(dialogContext).colorScheme.primary,
                        ),
                        title: Text('Allow ${tool.name}?'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tool.description),
                              const SizedBox(height: 12),
                              Text(
                                'Risk: ${tool.riskLevel.name}',
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .labelLarge,
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                call.arguments.toString(),
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Deny'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Allow once'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
              },
              onToolEvent: (event) async {
                final content = event.type == GenerationToolEventType.call
                    ? '🔧 [TOOL_CALL] ${event.call.name}\n'
                        '${event.call.arguments}'
                    : '🔧 [TOOL_RESPONSE] ${event.call.name}\n'
                        '${event.result?.modelContent ?? "No result"}';
                if (event.call.name == 'web_search') {
                  state = state.copyWith(
                    isSearchingWeb: event.type == GenerationToolEventType.call,
                  );
                }
                state = state.copyWith(
                  messages: [
                    ...state.messages,
                    ChatMessage(
                      role: event.type == GenerationToolEventType.call
                          ? 'assistant'
                          : 'user',
                      content: content,
                      timestamp: DateTime.now(),
                    ),
                  ],
                  streamingContent: '',
                  streamingThinkingContent: '',
                );
              },
            ),
          );

      final hapticEnabled = ref
          .read(storageServiceProvider)
          .getSetting(AppConstants.hapticFeedbackKey, defaultValue: true);

      final buffer = StringBuffer();
      DateTime? lastHapticTime;
      DateTime? lastUiUpdateTime;
      final startTime = DateTime.now();
      int? timeToFirstTokenMs;

      await for (final chunk in stream) {
        final now = DateTime.now();
        if (timeToFirstTokenMs == null) {
          timeToFirstTokenMs = now.difference(startTime).inMilliseconds;
          state = state.copyWith(isModelLoading: false);
        }

        if (hapticEnabled) {
          if (lastHapticTime == null ||
              now.difference(lastHapticTime) >
                  const Duration(milliseconds: 100)) {
            HapticFeedback.lightImpact();
            lastHapticTime = now;
          }
        }
        buffer.write(chunk.text);

        final rawText = buffer.toString();
        final parseResult = parseThinking(rawText);
        final thinking = parseResult.thinking;
        final mainContent = parseResult.mainContent;

        // Optimize: Throttle UI updates to ~20 FPS (50ms) to prevent excessive
        // rebuilds and Markdown re-parsing on every token.
        if (lastUiUpdateTime == null ||
            now.difference(lastUiUpdateTime) >
                const Duration(milliseconds: 50)) {
          final elapsed = now.difference(startTime).inMilliseconds;
          final words = _wordRegExp.allMatches(mainContent).length;
          final tokens = (words * 1.3).ceil();
          final tps = elapsed > 0 ? (tokens / (elapsed / 1000.0)) : 0.0;

          state = state.copyWith(
            streamingContent: mainContent,
            streamingThinkingContent: thinking,
            lastTps: tps,
            lastTtftMs: timeToFirstTokenMs,
          );
          lastUiUpdateTime = now;
        }
      }

      final finalRaw = buffer.toString();
      final finalResult = parseThinking(finalRaw);
      final finalThinking = finalResult.thinking;
      final finalMainContent = finalResult.mainContent;

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final words = _wordRegExp.allMatches(finalMainContent).length;
      final tokens = (words * 1.3).ceil();
      final finalTps = elapsed > 0 ? (tokens / (elapsed / 1000.0)) : 0.0;

      if (state.streamingContent != finalMainContent ||
          state.streamingThinkingContent != finalThinking) {
        state = state.copyWith(
          streamingContent: finalMainContent,
          streamingThinkingContent: finalThinking,
          lastTps: finalTps,
          lastTtftMs: timeToFirstTokenMs ?? elapsed,
        );
      }

      final assistantMessage = ChatMessage(
        role: 'assistant',
        content: finalMainContent,
        timestamp: DateTime.now(),
        thinkingContent: finalThinking.isNotEmpty ? finalThinking : null,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        streamingContent: '',
        streamingThinkingContent: '',
        lastTps: finalTps,
        lastTtftMs: timeToFirstTokenMs ?? elapsed,
      );
    } on GenerationCancelledError {
      // Cancellation is user initiated and should not create an error message.
    } catch (e) {
      // Handle potential errors, e.g., show a message to the user
      debugPrint('Inference Error: $e');
      final errorMessage = ChatMessage(
        role: 'assistant',
        content: '⚠️ Error: $e',
        timestamp: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, errorMessage]);
    } finally {
      state = state.copyWith(
        isGenerating: false,
        isModelLoading: false,
        streamingContent: '',
        streamingThinkingContent: '',
      );
      _activeCancellation = null;
      _saveSession();
    }
  }

  void cancelGeneration() {
    _activeCancellation?.cancel();
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
