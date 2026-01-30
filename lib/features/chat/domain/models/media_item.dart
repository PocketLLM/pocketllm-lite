class MediaItem {
  final String chatId;
  final DateTime messageTimestamp;
  final String base64Image;
  final int index; // Index of the image in the message's image list

  const MediaItem({
    required this.chatId,
    required this.messageTimestamp,
    required this.base64Image,
    required this.index,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MediaItem &&
        other.chatId == chatId &&
        other.messageTimestamp == messageTimestamp &&
        other.base64Image == base64Image &&
        other.index == index;
  }

  @override
  int get hashCode {
    return Object.hash(chatId, messageTimestamp, base64Image, index);
  }
}
