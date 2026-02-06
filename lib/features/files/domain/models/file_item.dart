import '../../../chat/domain/models/text_file_attachment.dart';

class FileItem {
  final String chatId;
  final String
  messageId; // Using message timestamp as ID since messages don't have explicit IDs
  final TextFileAttachment attachment;
  final DateTime uploadedAt;

  const FileItem({
    required this.chatId,
    required this.messageId,
    required this.attachment,
    required this.uploadedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileItem &&
        other.chatId == chatId &&
        other.messageId == messageId &&
        other.attachment == attachment &&
        other.uploadedAt == uploadedAt;
  }

  @override
  int get hashCode => Object.hash(chatId, messageId, attachment, uploadedAt);
}
