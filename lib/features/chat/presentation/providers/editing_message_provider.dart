import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/chat_message.dart';

class EditingMessageNotifier extends Notifier<ChatMessage?> {
  @override
  ChatMessage? build() => null;

  void setEditingMessage(ChatMessage? message) {
    state = message;
  }

  void clearEditingMessage() {
    state = null;
  }
}

final editingMessageProvider = NotifierProvider<EditingMessageNotifier, ChatMessage?>(
  EditingMessageNotifier.new,
);
