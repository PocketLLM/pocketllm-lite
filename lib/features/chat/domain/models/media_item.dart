class MediaItem {
  final String imageBase64;
  final String chatId;
  final String? messageId; // Optional, as ChatMessage doesn't strictly have an ID in the current model
  final DateTime timestamp;

  MediaItem({
    required this.imageBase64,
    required this.chatId,
    this.messageId,
    required this.timestamp,
  });
}
