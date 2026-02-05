// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatSessionAdapter extends TypeAdapter<ChatSession> {
  @override
  final int typeId = 1;

  @override
  ChatSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatSession(
      id: fields[0] as String,
      title: fields[1] as String,
      model: fields[2] as String,
      messages: (fields[3] as List).cast<ChatMessage>(),
      createdAt: fields[4] as DateTime,
      systemPrompt: fields[5] as String?,
      temperature: fields[6] as double?,
      topP: fields[7] as double?,
      topK: fields[8] as int?,
      numCtx: fields[9] as int?,
      repeatPenalty: fields[10] as double?,
      seed: fields[11] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatSession obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.model)
      ..writeByte(3)
      ..write(obj.messages)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.systemPrompt)
      ..writeByte(6)
      ..write(obj.temperature)
      ..writeByte(7)
      ..write(obj.topP)
      ..writeByte(8)
      ..write(obj.topK)
      ..writeByte(9)
      ..write(obj.numCtx)
      ..writeByte(10)
      ..write(obj.repeatPenalty)
      ..writeByte(11)
      ..write(obj.seed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
