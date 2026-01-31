class MediaItem {
  final String id;
  final String base64Content;
  final DateTime timestamp;
  final String sessionId;
  final String sessionTitle;

  const MediaItem({
    required this.id,
    required this.base64Content,
    required this.timestamp,
    required this.sessionId,
    required this.sessionTitle,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaItem &&
        other.id == id &&
        other.base64Content == base64Content &&
        other.timestamp == timestamp &&
        other.sessionId == sessionId &&
        other.sessionTitle == sessionTitle;
  }

  @override
  int get hashCode => Object.hash(
    id,
    base64Content,
    timestamp,
    sessionId,
    sessionTitle,
  );
}
