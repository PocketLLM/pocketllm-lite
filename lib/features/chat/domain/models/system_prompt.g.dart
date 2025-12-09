// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_prompt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SystemPromptAdapter extends TypeAdapter<SystemPrompt> {
  @override
  final int typeId = 2;

  @override
  SystemPrompt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SystemPrompt(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SystemPrompt obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemPromptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
