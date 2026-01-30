import '../../../chat/domain/models/chat_message.dart';
import '../../../chat/domain/models/chat_session.dart';

class MediaItem {
  final ChatSession session;
  final ChatMessage message;
  final String base64Image;

  MediaItem({
    required this.session,
    required this.message,
    required this.base64Image,
  });
}
