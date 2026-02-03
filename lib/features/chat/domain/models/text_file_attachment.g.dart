// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'text_file_attachment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TextFileAttachmentAdapter extends TypeAdapter<TextFileAttachment> {
  @override
  final int typeId = 3;

  @override
  TextFileAttachment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TextFileAttachment(
      name: fields[0] as String,
      content: fields[1] as String,
      sizeBytes: fields[2] as int,
      mimeType: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TextFileAttachment obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.sizeBytes)
      ..writeByte(3)
      ..write(obj.mimeType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextFileAttachmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
