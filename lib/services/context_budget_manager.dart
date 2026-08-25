import '../features/chat/domain/models/chat_message.dart';

typedef ConversationSummarizer = Future<String> Function(
  List<ChatMessage> olderMessages,
  String? previousSummary,
);

class ContextBudgetBreakdown {
  final int maxContextTokens;
  final int systemPromptBudget;
  final int recentChatBudget;
  final int memoryBudget;
  final int documentContextBudget;
  final int responseReservationBudget;

  const ContextBudgetBreakdown({
    required this.maxContextTokens,
    required this.systemPromptBudget,
    required this.recentChatBudget,
    required this.memoryBudget,
    required this.documentContextBudget,
    required this.responseReservationBudget,
  });

  factory ContextBudgetBreakdown.fromContextLength(
    int contextLength, {
    int? responseReservationTokens,
  }) {
    final responseReservation =
        responseReservationTokens ?? (contextLength * 0.10).round();
    return ContextBudgetBreakdown(
      maxContextTokens: contextLength,
      systemPromptBudget: (contextLength * 0.10).round(),
      recentChatBudget: (contextLength * 0.40).round(),
      memoryBudget: (contextLength * 0.15).round(),
      documentContextBudget: (contextLength * 0.25).round(),
      responseReservationBudget: responseReservation,
    );
  }
}

class ContextBudgetResult {
  final List<ChatMessage> fittedMessages;
  final bool wasSummarized;
  final String? summaryNotice;
  final int totalTokensUsed;
  final int remainingBudget;
  final String? rollingSummary;
  final int omittedMessageCount;

  const ContextBudgetResult({
    required this.fittedMessages,
    required this.wasSummarized,
    this.summaryNotice,
    required this.totalTokensUsed,
    required this.remainingBudget,
    this.rollingSummary,
    this.omittedMessageCount = 0,
  });
}

class ContextSummaryError implements Exception {
  final String message;
  const ContextSummaryError(this.message);

  @override
  String toString() => message;
}

class ContextWindowError implements Exception {
  final String message;
  const ContextWindowError(this.message);

  @override
  String toString() => message;
}

class ContextBudgetManager {
  static final ContextBudgetManager _instance =
      ContextBudgetManager._internal();
  factory ContextBudgetManager() => _instance;
  ContextBudgetManager._internal();

  int estimateTokens(String text, {String? modelId}) {
    if (text.isEmpty) return 0;
    final normalizedModel = modelId?.toLowerCase() ?? '';
    final cjkCharacters = RegExp(
      r'[\u3400-\u4DBF\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]',
    ).allMatches(text).length;
    final cjkRatio = cjkCharacters / text.length;
    if (cjkRatio > 0.20) {
      return (text.length / 1.7).ceil();
    }
    final charactersPerToken = normalizedModel.contains('qwen')
        ? 3.5
        : normalizedModel.contains('gemma')
            ? 3.6
            : normalizedModel.contains('llama') ||
                    normalizedModel.contains('mistral')
                ? 4.0
                : 3.8;
    return (text.length / charactersPerToken).ceil();
  }

  ContextBudgetResult fitContext({
    required List<ChatMessage> messages,
    required int maxContextTokens,
    String? systemPrompt,
    String? documentContext,
    String? memoryContext,
    String? modelId,
    String? rollingSummary,
    int? responseReservationTokens,
  }) {
    final budget = ContextBudgetBreakdown.fromContextLength(
      maxContextTokens,
      responseReservationTokens: responseReservationTokens,
    );
    if (budget.responseReservationBudget <= 0 ||
        budget.responseReservationBudget >= maxContextTokens) {
      throw ContextWindowError(
        'The requested output reservation '
        '(${budget.responseReservationBudget} tokens) leaves no usable input '
        'space in a $maxContextTokens-token context window.',
      );
    }

    final sysTokens = estimateTokens(systemPrompt ?? '', modelId: modelId);
    final docTokens = estimateTokens(documentContext ?? '', modelId: modelId);
    final memTokens = estimateTokens(memoryContext ?? '', modelId: modelId);
    final existingSummaryTokens = estimateTokens(
      rollingSummary ?? '',
      modelId: modelId,
    );

    final totalStaticTokens =
        sysTokens + docTokens + memTokens + existingSummaryTokens;
    final availableChatTokens =
        maxContextTokens - budget.responseReservationBudget - totalStaticTokens;
    if (availableChatTokens <= 0) {
      throw const ContextWindowError(
        'The system prompt, memories, and document excerpts already fill the '
        'model context window. Remove some context or choose a model with a '
        'larger verified context length.',
      );
    }

    if (messages.isNotEmpty) {
      final newestTokens = estimateTokens(
        messages.last.content,
        modelId: modelId,
      );
      if (newestTokens > availableChatTokens) {
        throw ContextWindowError(
          'The newest message needs about $newestTokens tokens, but only '
          '$availableChatTokens fit after reserved context. Shorten the '
          'message or attachments, or choose a larger-context model.',
        );
      }
    }

    int currentChatTokens = 0;
    final List<ChatMessage> recentMessages = [];
    final List<ChatMessage> olderMessages = [];

    // Process from newest to oldest
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      final msgTokens = estimateTokens(msg.content, modelId: modelId);

      if (currentChatTokens + msgTokens <= availableChatTokens) {
        recentMessages.insert(0, msg);
        currentChatTokens += msgTokens;
      } else {
        olderMessages.insert(0, msg);
      }
    }

    if (olderMessages.isEmpty) {
      return ContextBudgetResult(
        fittedMessages: messages,
        wasSummarized: false,
        totalTokensUsed: currentChatTokens + totalStaticTokens,
        remainingBudget: availableChatTokens - currentChatTokens,
        rollingSummary: rollingSummary,
      );
    }

    final hasSummary = rollingSummary?.trim().isNotEmpty == true;
    final resultMessages = <ChatMessage>[
      if (hasSummary)
        ChatMessage(
          role: 'system',
          content: 'Rolling conversation summary:\n${rollingSummary!.trim()}',
          timestamp: olderMessages.last.timestamp,
        ),
      ...recentMessages,
    ];
    return ContextBudgetResult(
      fittedMessages: resultMessages,
      wasSummarized: hasSummary,
      summaryNotice: hasSummary
          ? 'Older messages were summarized locally to fit the model\'s context window.'
          : 'Older messages were omitted because no verified rolling summary was available.',
      totalTokensUsed: currentChatTokens + totalStaticTokens,
      remainingBudget: availableChatTokens - currentChatTokens,
      rollingSummary: rollingSummary,
      omittedMessageCount: olderMessages.length,
    );
  }

  Future<ContextBudgetResult> fitContextWithSummary({
    required List<ChatMessage> messages,
    required int maxContextTokens,
    required ConversationSummarizer summarizer,
    String? systemPrompt,
    String? documentContext,
    String? memoryContext,
    String? modelId,
    String? rollingSummary,
    int? responseReservationTokens,
  }) async {
    final initial = fitContext(
      messages: messages,
      maxContextTokens: maxContextTokens,
      systemPrompt: systemPrompt,
      documentContext: documentContext,
      memoryContext: memoryContext,
      modelId: modelId,
      rollingSummary: rollingSummary,
      responseReservationTokens: responseReservationTokens,
    );
    if (initial.omittedMessageCount == 0) return initial;

    final olderCount = initial.omittedMessageCount;
    final olderMessages = messages.take(olderCount).toList(growable: false);
    final generated = (await summarizer(olderMessages, rollingSummary)).trim();
    if (generated.isEmpty) {
      throw const ContextSummaryError(
        'The local summarizer returned an empty conversation summary.',
      );
    }
    return fitContext(
      messages: messages,
      maxContextTokens: maxContextTokens,
      systemPrompt: systemPrompt,
      documentContext: documentContext,
      memoryContext: memoryContext,
      modelId: modelId,
      rollingSummary: generated,
      responseReservationTokens: responseReservationTokens,
    );
  }
}
