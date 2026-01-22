import 'chat_message.dart';

class StarredMessage {
  final String id;
  final String sessionId;
  final ChatMessage message;
  final DateTime starredAt;
  final String? sessionTitle; // Optional snapshot of title

  StarredMessage({
    required this.id,
    required this.sessionId,
    required this.message,
    required this.starredAt,
    this.sessionTitle,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'message': {
        'role': message.role,
        'content': message.content,
        'timestamp': message.timestamp.toIso8601String(),
        'images': message.images,
      },
      'starredAt': starredAt.toIso8601String(),
      'sessionTitle': sessionTitle,
    };
  }

  factory StarredMessage.fromJson(Map<String, dynamic> json) {
    return StarredMessage(
      id: json['id'],
      sessionId: json['sessionId'],
      message: ChatMessage(
        role: json['message']['role'],
        content: json['message']['content'],
        timestamp: DateTime.parse(json['message']['timestamp']),
        images: json['message']['images'] != null
            ? List<String>.from(json['message']['images'])
            : null,
      ),
      starredAt: DateTime.parse(json['starredAt']),
      sessionTitle: json['sessionTitle'],
    );
  }
}
