import 'package:hive_ce/hive_ce.dart';

@HiveType(typeId: 8)
class Skill {
  @HiveField(0)
  final String id; // Kebab-case slug e.g. 'webdesign'

  @HiveField(1)
  final String title; // Human-readable title e.g. 'Web Design Expert'

  @HiveField(2)
  final String description; // Description of triggers or behavior

  @HiveField(3)
  final String body; // Detailed markdown instructions

  @HiveField(4)
  final String? githubUrl; // URL if installed from Github

  @HiveField(5)
  final bool isEnabled;

  Skill({
    required this.id,
    required this.title,
    required this.description,
    required this.body,
    this.githubUrl,
    this.isEnabled = true,
  });

  Skill copyWith({
    String? id,
    String? title,
    String? description,
    String? body,
    String? githubUrl,
    bool? isEnabled,
  }) {
    return Skill(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      body: body ?? this.body,
      githubUrl: githubUrl ?? this.githubUrl,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}

class SkillAdapter extends TypeAdapter<Skill> {
  @override
  final typeId = 8;

  @override
  Skill read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Skill(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      body: fields[3] as String,
      githubUrl: fields[4] as String?,
      isEnabled: fields[5] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, Skill obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.body)
      ..writeByte(4)
      ..write(obj.githubUrl)
      ..writeByte(5)
      ..write(obj.isEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
