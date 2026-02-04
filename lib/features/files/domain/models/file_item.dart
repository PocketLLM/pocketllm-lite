import '../../../chat/domain/models/chat_message.dart';
import '../../../chat/domain/models/text_file_attachment.dart';

class FileItem {
  final String chatId;
  final String chatTitle;
  final ChatMessage message;
  final TextFileAttachment attachment;

  const FileItem({
    required this.chatId,
    required this.chatTitle,
    required this.message,
    required this.attachment,
  });
}
