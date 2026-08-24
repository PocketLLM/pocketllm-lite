import '../features/chat/domain/models/chat_message.dart';

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

  factory ContextBudgetBreakdown.fromContextLength(int contextLength) {
    return ContextBudgetBreakdown(
      maxContextTokens: contextLength,
      systemPromptBudget: (contextLength * 0.10).round(),
      recentChatBudget: (contextLength * 0.40).round(),
      memoryBudget: (contextLength * 0.15).round(),
      documentContextBudget: (contextLength * 0.25).round(),
      responseReservationBudget: (contextLength * 0.10).round(),
    );
  }
}

class ContextBudgetResult {
  final List<ChatMessage> fittedMessages;
  final bool wasSummarized;
  final String? summaryNotice;
  final int totalTokensUsed;
  final int remainingBudget;

  const ContextBudgetResult({
    required this.fittedMessages,
    required this.wasSummarized,
    this.summaryNotice,
    required this.totalTokensUsed,
    required this.remainingBudget,
  });
}

class ContextBudgetManager {
  static final ContextBudgetManager _instance =
      ContextBudgetManager._internal();
  factory ContextBudgetManager() => _instance;
  ContextBudgetManager._internal();

  int estimateTokens(String text) {
    if (text.isEmpty) return 0;
    // Approximates ~4 characters per token
    return (text.length / 3.8).ceil();
  }

  ContextBudgetResult fitContext({
    required List<ChatMessage> messages,
    required int maxContextTokens,
    String? systemPrompt,
    String? documentContext,
    String? memoryContext,
  }) {
    final budget = ContextBudgetBreakdown.fromContextLength(maxContextTokens);

    final sysTokens = estimateTokens(systemPrompt ?? '');
    final docTokens = estimateTokens(documentContext ?? '');
    final memTokens = estimateTokens(memoryContext ?? '');

    int totalStaticTokens = sysTokens + docTokens + memTokens;
    int availableChatTokens =
        maxContextTokens - budget.responseReservationBudget - totalStaticTokens;
    if (availableChatTokens < 200) availableChatTokens = 200;

    int currentChatTokens = 0;
    final List<ChatMessage> recentMessages = [];
    final List<ChatMessage> olderMessages = [];

    // Process from newest to oldest
    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      final msgTokens = estimateTokens(msg.content);

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
      );
    }

    final summaryContent =
        'Summary of earlier conversation turns (${olderMessages.length} messages): ${olderMessages.map((m) => '${m.role}: ${m.content}').join(' ').substring(0, 180)}...';

    final summaryMessage = ChatMessage(
      role: 'system',
      content: summaryContent,
      timestamp: olderMessages.last.timestamp,
    );

    final List<ChatMessage> resultMessages = [
      summaryMessage,
      ...recentMessages
    ];

    return ContextBudgetResult(
      fittedMessages: resultMessages,
      wasSummarized: true,
      summaryNotice:
          'Older messages were summarized locally to fit the model\'s context window.',
      totalTokensUsed: estimateTokens(summaryContent) +
          currentChatTokens +
          totalStaticTokens,
      remainingBudget: availableChatTokens - currentChatTokens,
    );
  }
}
