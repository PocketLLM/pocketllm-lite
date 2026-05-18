import 'package:hive_ce/hive_ce.dart';

part 'chat_persona.g.dart';

@HiveType(typeId: 6)
class ChatPersona {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String systemPrompt;

  @HiveField(3)
  final double temperature;

  @HiveField(4)
  final String avatarIcon; // Emoji (e.g. 🤖, 🧙, 🐍)

  @HiveField(5)
  final String? modelId; // Associated default model

  ChatPersona({
    required this.id,
    required this.name,
    required this.systemPrompt,
    this.temperature = 0.7,
    this.avatarIcon = '🤖',
    this.modelId,
  });

  ChatPersona copyWith({
    String? id,
    String? name,
    String? systemPrompt,
    double? temperature,
    String? avatarIcon,
    String? modelId,
  }) {
    return ChatPersona(
      id: id ?? this.id,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      modelId: modelId ?? this.modelId,
    );
  }
}
