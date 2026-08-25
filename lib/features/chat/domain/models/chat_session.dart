import 'package:hive_ce/hive_ce.dart';
import 'chat_message.dart';

part 'chat_session.g.dart';

@HiveType(typeId: 1)
class ChatSession {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String model;

  @HiveField(3)
  final List<ChatMessage> messages;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final String? systemPrompt;

  @HiveField(6)
  final double? temperature;

  @HiveField(7)
  final double? topP;

  @HiveField(8)
  final int? topK;

  @HiveField(9)
  final String? systemPromptId;

  ChatSession({
    required this.id,
    required this.title,
    required this.model,
    required this.messages,
    required this.createdAt,
    this.systemPrompt,
    this.temperature,
    this.topP,
    this.topK,
    this.systemPromptId,
  });

  ChatSession copyWith({
    String? id,
    String? title,
    String? model,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    Object? systemPrompt = _chatSessionUnset,
    double? temperature,
    double? topP,
    int? topK,
    Object? systemPromptId = _chatSessionUnset,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      model: model ?? this.model,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      systemPrompt: identical(systemPrompt, _chatSessionUnset)
          ? this.systemPrompt
          : systemPrompt as String?,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      systemPromptId: identical(systemPromptId, _chatSessionUnset)
          ? this.systemPromptId
          : systemPromptId as String?,
    );
  }
}

const Object _chatSessionUnset = Object();
