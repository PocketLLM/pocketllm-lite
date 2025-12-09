import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';

class StorageService {
  static const String _boxName = 'chat_sessions';

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ChatMessageAdapter());
    Hive.registerAdapter(ChatSessionAdapter());
    await Hive.openBox<ChatSession>(_boxName);
  }

  Box<ChatSession> get _box => Hive.box<ChatSession>(_boxName);

  List<ChatSession> getChats() {
    return _box.values.toList()
      ..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
  }

  Future<void> saveChat(ChatSession session) async {
    await _box.put(session.id, session);
  }

  Future<void> deleteChat(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }

  ChatSession? getChat(String id) {
    return _box.get(id);
  }
}
