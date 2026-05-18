// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_persona.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatPersonaAdapter extends TypeAdapter<ChatPersona> {
  @override
  final typeId = 6;

  @override
  ChatPersona read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatPersona(
      id: fields[0] as String,
      name: fields[1] as String,
      systemPrompt: fields[2] as String,
      temperature: fields[3] == null ? 0.7 : (fields[3] as num).toDouble(),
      avatarIcon: fields[4] == null ? '🤖' : fields[4] as String,
      modelId: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatPersona obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.systemPrompt)
      ..writeByte(3)
      ..write(obj.temperature)
      ..writeByte(4)
      ..write(obj.avatarIcon)
      ..writeByte(5)
      ..write(obj.modelId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatPersonaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
