import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/storage_service.dart';
import '../../../../main.dart';
import '../models/starred_message.dart';
import '../models/chat_message.dart';

final starredMessagesProvider = StateNotifierProvider<StarredMessagesNotifier, List<StarredMessage>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return StarredMessagesNotifier(storage);
});

class StarredMessagesNotifier extends StateNotifier<List<StarredMessage>> {
  final StorageService _storage;

  StarredMessagesNotifier(this._storage) : super([]) {
    _loadStarredMessages();
  }

  void _loadStarredMessages() {
    state = _storage.getStarredMessages();
  }

  Future<void> toggleStar({
    required String sessionId,
    required ChatMessage message,
    String? sessionTitle,
  }) async {
    await _storage.toggleStarMessage(
      sessionId: sessionId,
      message: message,
      sessionTitle: sessionTitle,
    );
    _loadStarredMessages();
  }

  bool isStarred(ChatMessage message) {
    return state.any((s) => s.message == message);
  }
}
