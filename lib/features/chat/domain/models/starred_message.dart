import 'chat_message.dart';

class StarredMessage {
  final String id;
  final String chatId;
  final ChatMessage message;
  final DateTime starredAt;

  StarredMessage({
    required this.id,
    required this.chatId,
    required this.message,
    required this.starredAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'message': {
        'role': message.role,
        'content': message.content,
        'timestamp': message.timestamp.toIso8601String(),
        'images': message.images,
      },
      'starredAt': starredAt.toIso8601String(),
    };
  }

  factory StarredMessage.fromJson(Map<String, dynamic> json) {
    return StarredMessage(
      id: json['id'],
      chatId: json['chatId'],
      message: ChatMessage(
        role: json['message']['role'],
        content: json['message']['content'],
        timestamp: DateTime.parse(json['message']['timestamp']),
        images: json['message']['images'] != null
            ? List<String>.from(json['message']['images'])
            : null,
      ),
      starredAt: DateTime.parse(json['starredAt']),
    );
  }
}
