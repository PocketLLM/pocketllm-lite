
class MediaItem {
  final String id;
  final String chatId;
  final DateTime timestamp;
  final String base64Data;
  final int index;

  MediaItem({
    required this.id,
    required this.chatId,
    required this.timestamp,
    required this.base64Data,
    required this.index,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MediaItem &&
      other.id == id &&
      other.chatId == chatId &&
      other.timestamp == timestamp &&
      other.index == index &&
      other.base64Data == base64Data;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      chatId,
      timestamp,
      index,
      base64Data,
    );
  }
}
