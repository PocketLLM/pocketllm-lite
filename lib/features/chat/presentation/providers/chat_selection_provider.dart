import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_message.dart';
import 'chat_provider.dart';

class ChatSelectionState {
  final bool isSelectionMode;
  final Set<ChatMessage> selectedMessages;

  const ChatSelectionState({
    this.isSelectionMode = false,
    this.selectedMessages = const {},
  });

  ChatSelectionState copyWith({
    bool? isSelectionMode,
    Set<ChatMessage>? selectedMessages,
  }) {
    return ChatSelectionState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedMessages: selectedMessages ?? this.selectedMessages,
    );
  }
}

class ChatSelectionNotifier extends Notifier<ChatSelectionState> {
  @override
  ChatSelectionState build() {
    return const ChatSelectionState();
  }

  void enterSelectionMode(ChatMessage? initialMessage) {
    state = ChatSelectionState(
      isSelectionMode: true,
      selectedMessages: initialMessage != null ? {initialMessage} : {},
    );
  }

  void exitSelectionMode() {
    state = const ChatSelectionState();
  }

  void toggleMessage(ChatMessage message) {
    final newSelection = Set<ChatMessage>.from(state.selectedMessages);
    if (newSelection.contains(message)) {
      newSelection.remove(message);
    } else {
      newSelection.add(message);
    }

    // If last message deselected, exit selection mode?
    // Usually standard behavior is to stay in mode until user cancels or deletes.
    state = state.copyWith(selectedMessages: newSelection);
  }

  void selectAll(List<ChatMessage> messages) {
    state = state.copyWith(selectedMessages: Set.from(messages));
  }

  void deselectAll() {
    state = state.copyWith(selectedMessages: {});
  }

  /// Helper to get formatted text for copy/share
  String getSelectedText() {
    // Sort messages by timestamp or index?
    // Since Set is unordered, we rely on the ChatProvider messages list for order.
    final allMessages = ref.read(chatProvider).messages;
    final sortedSelection = allMessages.where((m) => state.selectedMessages.contains(m));

    return sortedSelection.map((m) {
      final prefix = m.role == 'user' ? 'User: ' : 'AI: ';
      return '$prefix${m.content}';
    }).join('\n\n');
  }
}

final chatSelectionProvider = NotifierProvider<ChatSelectionNotifier, ChatSelectionState>(
  ChatSelectionNotifier.new,
);
