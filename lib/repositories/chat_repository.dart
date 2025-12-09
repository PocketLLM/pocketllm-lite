import '../models/chat_session.dart';
import '../models/chat_message.dart';
import '../services/storage_service.dart';
import 'package:uuid/uuid.dart';

class ChatRepository {
  final StorageService _storageService;

  ChatRepository(this._storageService);

  List<ChatSession> getAllChats() {
    return _storageService.getChats();
  }

  Future<void> createChat(String modelId) async {
    final id = const Uuid().v4();
    final session = ChatSession(
      id: id,
      title: 'New Chat',
      messages: [],
      modelId: modelId,
      lastUpdated: DateTime.now(),
    );
    await _storageService.saveChat(session);
  }

  Future<void> addMessage(String chatId, ChatMessage message) async {
    final session = _storageService.getChat(chatId);
    if (session != null) {
      session.messages.add(message);

      // Update title if it's the first user message
      String newTitle = session.title;
      if (session.messages.length == 1 && message.isUser) {
        newTitle =
            message.text.length > 30
                ? '${message.text.substring(0, 30)}...'
                : message.text;
      } else if (session.title == 'New Chat' && message.isUser) {
        newTitle =
            message.text.length > 30
                ? '${message.text.substring(0, 30)}...'
                : message.text;
      }

      final updatedSession = ChatSession(
        id: session.id,
        title: newTitle,
        messages: session.messages,
        modelId: session.modelId,
        lastUpdated: DateTime.now(),
      );
      await _storageService.saveChat(updatedSession);
    }
  }

  Future<void> updateChatModel(String chatId, String modelId) async {
    final session = _storageService.getChat(chatId);
    if (session != null) {
      final updatedSession = ChatSession(
        id: session.id,
        title: session.title,
        messages: session.messages,
        modelId: modelId,
        lastUpdated: DateTime.now(),
      );
      await _storageService.saveChat(updatedSession);
    }
  }

  Future<void> updateChatTitle(String chatId, String newTitle) async {
    final session = _storageService.getChat(chatId);
    if (session != null) {
      final updatedSession = ChatSession(
        id: session.id,
        title: newTitle,
        messages: session.messages,
        modelId: session.modelId,
        lastUpdated: DateTime.now(),
      );
      await _storageService.saveChat(updatedSession);
    }
  }

  Future<void> deleteChat(String id) => _storageService.deleteChat(id);

  Future<void> clearAll() => _storageService.clearAll();
}
