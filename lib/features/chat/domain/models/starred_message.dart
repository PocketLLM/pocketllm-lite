import 'package:uuid/uuid.dart';
import 'chat_message.dart';

class StarredMessage {
  final String id;
  final String chatId;
  final ChatMessage message;
  final DateTime savedAt;
  final String? note;

  StarredMessage({
    required this.id,
    required this.chatId,
    required this.message,
    required this.savedAt,
    this.note,
  });

  factory StarredMessage.create({
    required String chatId,
    required ChatMessage message,
    String? note,
  }) {
    return StarredMessage(
      id: const Uuid().v4(),
      chatId: chatId,
      message: message,
      savedAt: DateTime.now(),
      note: note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'message': _chatMessageToJson(message),
      'savedAt': savedAt.toIso8601String(),
      'note': note,
    };
  }

  factory StarredMessage.fromJson(Map<String, dynamic> json) {
    return StarredMessage(
      id: json['id'],
      chatId: json['chatId'],
      message: _chatMessageFromJson(Map<String, dynamic>.from(json['message'])),
      savedAt: DateTime.parse(json['savedAt']),
      note: json['note'],
    );
  }

  // Helper to serialize ChatMessage manually since we store it in a JSON map
  static Map<String, dynamic> _chatMessageToJson(ChatMessage message) {
    return {
      'role': message.role,
      'content': message.content,
      'timestamp': message.timestamp.toIso8601String(),
      'images': message.images,
    };
  }

  static ChatMessage _chatMessageFromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      images:
          json['images'] != null ? List<String>.from(json['images']) : null,
    );
  }
}
