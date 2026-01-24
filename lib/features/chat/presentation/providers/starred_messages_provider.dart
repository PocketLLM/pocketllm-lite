import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../domain/models/chat_message.dart';

class StarredMessagesNotifier extends Notifier<Set<ChatMessage>> {
  @override
  Set<ChatMessage> build() {
    final storage = ref.watch(storageServiceProvider);

    // Subscribe to changes
    final listenable = storage.starredMessagesListenable;

    // We need to trigger rebuilds when listenable changes
    void listener() {
       state = storage.getStarredMessages().map((s) => s.message).toSet();
    }

    listenable.addListener(listener);
    ref.onDispose(() {
      listenable.removeListener(listener);
    });

    return storage.getStarredMessages().map((s) => s.message).toSet();
  }
}

final starredMessagesProvider =
    NotifierProvider<StarredMessagesNotifier, Set<ChatMessage>>(
  StarredMessagesNotifier.new,
);
