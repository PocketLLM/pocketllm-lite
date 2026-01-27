import 'package:uuid/uuid.dart';

class MediaItem {
  final String id;
  final String chatId;
  final DateTime messageTimestamp;
  final DateTime timestamp;
  final String base64Image;

  MediaItem({
    String? id,
    required this.chatId,
    required this.messageTimestamp,
    required this.timestamp,
    required this.base64Image,
  }) : id = id ?? const Uuid().v4();
}
