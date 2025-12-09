import 'package:hive/hive.dart';

part 'system_prompt.g.dart';

@HiveType(typeId: 2)
class SystemPrompt {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String content;

  SystemPrompt({required this.id, required this.title, required this.content});
}
