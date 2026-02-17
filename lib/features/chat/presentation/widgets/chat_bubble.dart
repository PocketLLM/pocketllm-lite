import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/image_decoder.dart';
import '../../../../core/utils/markdown_handlers.dart';
import '../../../../core/utils/url_validator.dart';
import '../../../../core/widgets/m3_avatar.dart';
import '../../domain/models/chat_message.dart';
import '../../../settings/presentation/providers/appearance_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/draft_message_provider.dart';
import '../providers/editing_message_provider.dart';
import '../../../../core/providers.dart';
import 'three_dot_loading_indicator.dart';

// Helper class for formatting timestamps
class TimestampFormatter {
  static String format(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays < 1) {
      final hour = timestamp.hour;
      final minute = timestamp.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
      return '$formattedHour:$minute $period';
    } else if (difference.inDays < 2) {
      return 'Yesterday';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }
}

class ChatBubble extends ConsumerStatefulWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  ConsumerState<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends ConsumerState<ChatBubble> {
  final GlobalKey _bubbleKey = GlobalKey();
  List<Uint8List>? _decodedImages;
  late String _formattedTimestamp;

  // Cache for MarkdownStyleSheet to prevent expensive reconstruction on every frame during streaming
  MarkdownStyleSheet? _cachedStyleSheet;
  ThemeData? _cachedTheme;
  double? _cachedFontSize;
  Color? _cachedTextColor;

  @override
  void initState() {
    super.initState();
    _decodeImages();
    _formattedTimestamp = TimestampFormatter.format(widget.message.timestamp);
  }

  MarkdownStyleSheet _getStyleSheet(
    ThemeData theme,
    double fontSize,
    Color textColor,
  ) {
    if (_cachedStyleSheet != null &&
        identical(_cachedTheme, theme) &&
        _cachedFontSize == fontSize &&
        _cachedTextColor == textColor) {
      return _cachedStyleSheet!;
    }

    _cachedTheme = theme;
    _cachedFontSize = fontSize;
    _cachedTextColor = textColor;
    _cachedStyleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontSize: fontSize,
        height: 1.5,
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        backgroundColor: textColor.withValues(alpha: 0.08),
        color: textColor,
        fontSize: fontSize * 0.9,
      ),
      codeblockDecoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      h1: theme.textTheme.titleLarge?.copyWith(color: textColor),
      h2: theme.textTheme.titleMedium?.copyWith(color: textColor),
      h3: theme.textTheme.titleSmall?.copyWith(color: textColor),
      listBullet: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontSize: fontSize,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: textColor.withValues(alpha: 0.4), width: 3),
        ),
      ),
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: textColor.withValues(alpha: 0.8),
        fontSize: fontSize,
        fontStyle: FontStyle.italic,
      ),
    );
    return _cachedStyleSheet!;
  }

  @override
  void didUpdateWidget(ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldImages = oldWidget.message.images;
    final newImages = widget.message.images;
    if (oldImages != newImages && !listEquals(oldImages, newImages)) {
      _decodeImages();
    }

    if (oldWidget.message.timestamp != widget.message.timestamp) {
      _formattedTimestamp = TimestampFormatter.format(widget.message.timestamp);
    }
  }

  Future<void> _decodeImages() async {
    if (widget.message.images != null && widget.message.images!.isNotEmpty) {
      final images = await IsolateImageDecoder.decodeImages(
        widget.message.images!,
      );
      if (mounted) {
        setState(() {
          _decodedImages = images;
        });
      }
    } else {
      if (_decodedImages != null) {
        setState(() {
          _decodedImages = null;
        });
      }
    }
  }

  void _showImageViewer(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  void _showAttachmentViewer(String title, String content) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.description_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(
            content,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File content copied'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  /// Compute the text color based on the bubble's background luminance.
  /// This ensures readability regardless of user customization.
  Color _getTextColor(Color bubbleColor) {
    return bubbleColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Build M3-style asymmetric bubble border radius.
  /// User: rounded top + left, sharp bottom-right (tail).
  /// AI: rounded top + right, sharp bottom-left (tail).
  BorderRadius _getBubbleRadius(double radius, bool isUser) {
    return BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
      bottomLeft: Radius.circular(isUser ? radius : 4),
      bottomRight: Radius.circular(isUser ? 4 : radius),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.role == 'user';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final appearance = ref.watch(
      appearanceProvider.select(
        (state) => (
          userMsgColor: state.userMsgColor,
          aiMsgColor: state.aiMsgColor,
          msgOpacity: state.msgOpacity,
          bubbleRadius: state.bubbleRadius,
          fontSize: state.fontSize,
          chatPadding: state.chatPadding,
          bubbleElevation: state.bubbleElevation,
          showAvatars: state.showAvatars,
        ),
      ),
    );

    final profile = ref.watch(profileProvider);

    // Appearance Values — user customization takes priority
    final bubbleColor = isUser
        ? Color(
            appearance.userMsgColor,
          ).withValues(alpha: appearance.msgOpacity)
        : Color(appearance.aiMsgColor).withValues(alpha: appearance.msgOpacity);
    final radius = appearance.bubbleRadius;
    final fontSize = appearance.fontSize;
    final padding = appearance.chatPadding;
    final hasElevation = appearance.bubbleElevation;
    final showAvatars = appearance.showAvatars;
    final textColor = _getTextColor(bubbleColor);

    final storage = ref.watch(storageServiceProvider);

    // Show loading indicator for empty assistant messages (AI is generating)
    if (!isUser && message.content.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showAvatars) ...[
              M3Avatar.ai(
                size: 28,
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: _getBubbleRadius(18, false),
                boxShadow: hasElevation
                    ? [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ThreeDotLoadingIndicator(
                color: textColor.withValues(alpha: 0.7),
                size: 6.0,
              ),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder(
      valueListenable: storage.starredMessagesListenable,
      builder: (context, _, __) {
        final isStarred = storage.isMessageStarred(message);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser && showAvatars) ...[
                Semantics(
                  excludeSemantics: true,
                  child: M3Avatar.ai(
                    size: 28,
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Semantics(
                  container: true,
                  hint: 'Double tap and hold for options',
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    _showFocusedMenu(context, isUser, isStarred);
                  },
                  child: GestureDetector(
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      _showFocusedMenu(context, isUser, isStarred);
                    },
                    child: RepaintBoundary(
                      child: Container(
                        key: _bubbleKey,
                        padding: EdgeInsets.all(padding),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: _getBubbleRadius(radius, isUser),
                          boxShadow: hasElevation
                              ? [
                                  BoxShadow(
                                    color: colorScheme.shadow.withValues(
                                      alpha: 0.08,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_decodedImages != null &&
                                _decodedImages!.isNotEmpty)
                              ..._decodedImages!.map(
                                (bytes) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      onTap: () => _showImageViewer(bytes),
                                      child: Image.memory(
                                        bytes,
                                        height: 150,
                                        fit: BoxFit.cover,
                                        cacheHeight: 450,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (isUser)
                              Text(
                                message.content,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: textColor,
                                  fontSize: fontSize,
                                  height: 1.5,
                                ),
                              )
                            else
                              MarkdownBody(
                                data: message.content,
                                // ignore: deprecated_member_use
                                imageBuilder: MarkdownHandlers.imageBuilder,
                                onTapLink: (text, href, title) async {
                                  if (href != null) {
                                    final uri = Uri.tryParse(href);
                                    if (uri != null &&
                                        UrlValidator.isSecureUrl(uri) &&
                                        await canLaunchUrl(uri)) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  }
                                },
                                styleSheet: _getStyleSheet(
                                  theme,
                                  fontSize,
                                  textColor,
                                ),
                              ),
                            if (message.attachments != null &&
                                message.attachments!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: message.attachments!.map((
                                    attachment,
                                  ) {
                                    return ActionChip(
                                      avatar: Icon(
                                        Icons.description_outlined,
                                        size: 16,
                                        color: textColor.withValues(alpha: 0.8),
                                      ),
                                      label: Text(
                                        attachment.name,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: fontSize * 0.85,
                                        ),
                                      ),
                                      backgroundColor: textColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      side: BorderSide(
                                        color: textColor.withValues(alpha: 0.2),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      onPressed: () => _showAttachmentViewer(
                                        attachment.name,
                                        attachment.content,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            // Timestamp display
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isStarred) ...[
                                    Icon(
                                      Icons.star_rounded,
                                      size: 12,
                                      color: Colors.amber.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    _formattedTimestamp,
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.6),
                                      fontSize: fontSize * 0.7,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (isUser && showAvatars) ...[
                const SizedBox(width: 8),
                Semantics(
                  excludeSemantics: true,
                  child: profile.avatarImageBase64 != null
                      ? CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(profile.avatarColor),
                          backgroundImage: MemoryImage(
                            base64Decode(profile.avatarImageBase64!),
                          ),
                        )
                      : M3Avatar.user(
                          size: 28,
                          backgroundColor: Color(profile.avatarColor),
                          child: const Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showFocusedMenu(BuildContext context, bool isUser, bool isStarred) {
    final RenderBox renderBox =
        _bubbleKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.2),
        pageBuilder: (context, _, __) => _FocusedMenuOverlay(
          message: widget.message,
          bubbleSize: size,
          bubbleOffset: offset,
          isUser: isUser,
          isStarred: isStarred,
          onToggleStar: () async {
            final storage = ref.read(storageServiceProvider);
            final chatId = ref.read(chatProvider).currentSessionId;
            if (chatId != null) {
              await storage.toggleStarMessage(chatId, widget.message);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isStarred ? 'Message unstarred' : 'Message starred',
                    ),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          onDelete: () {
            ref.read(chatProvider.notifier).deleteMessage(widget.message);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Message deleted'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: widget,
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _FocusedMenuOverlay extends ConsumerWidget {
  final Widget child;
  final ChatMessage message;
  final Size bubbleSize;
  final Offset bubbleOffset;
  final bool isUser;
  final bool isStarred;
  final VoidCallback onToggleStar;
  final VoidCallback onDelete;

  const _FocusedMenuOverlay({
    required this.child,
    required this.message,
    required this.bubbleSize,
    required this.bubbleOffset,
    required this.isUser,
    required this.isStarred,
    required this.onToggleStar,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appearance = ref.read(appearanceProvider);

    final bubbleColor = isUser
        ? Color(
            appearance.userMsgColor,
          ).withValues(alpha: appearance.msgOpacity)
        : Color(appearance.aiMsgColor).withValues(alpha: appearance.msgOpacity);
    final radius = appearance.bubbleRadius;
    final fontSize = appearance.fontSize;
    final padding = appearance.chatPadding;
    final textColor = bubbleColor.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    final screenHeight = MediaQuery.of(context).size.height;
    final showAbove = bubbleOffset.dy > screenHeight * 0.6;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Blur Backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: colorScheme.scrim.withValues(alpha: 0.35),
              ),
            ),
          ),

          // 2. Dismiss logic
          Positioned.fill(
            child: Semantics(
              label: 'Dismiss menu',
              button: true,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // 3. Highlighted Bubble
          Positioned(
            top: bubbleOffset.dy,
            left: bubbleOffset.dx,
            width: bubbleSize.width,
            child: Material(
              color: Colors.transparent,
              elevation: 12,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(radius),
                topRight: Radius.circular(radius),
                bottomLeft: Radius.circular(isUser ? radius : 4),
                bottomRight: Radius.circular(isUser ? 4 : radius),
              ),
              child: Container(
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(radius),
                    topRight: Radius.circular(radius),
                    bottomLeft: Radius.circular(isUser ? radius : 4),
                    bottomRight: Radius.circular(isUser ? 4 : radius),
                  ),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.images != null)
                      ...message.images!.map(
                        (str) => const SizedBox(
                          height: 100,
                          child: Center(
                            child: Icon(Icons.image, color: Colors.white),
                          ),
                        ),
                      ),

                    if (isUser)
                      Text(
                        message.content,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          fontSize: fontSize,
                        ),
                      )
                    else
                      MarkdownBody(
                        data: message.content,
                        // ignore: deprecated_member_use
                        imageBuilder: MarkdownHandlers.imageBuilder,
                        onTapLink: (text, href, title) async {
                          if (href != null) {
                            final uri = Uri.tryParse(href);
                            if (uri != null &&
                                UrlValidator.isSecureUrl(uri) &&
                                await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          }
                        },
                        styleSheet: MarkdownStyleSheet.fromTheme(theme)
                            .copyWith(
                              p: theme.textTheme.bodyMedium?.copyWith(
                                color: textColor,
                                fontSize: fontSize,
                              ),
                              code: theme.textTheme.bodyMedium?.copyWith(
                                backgroundColor: textColor.withValues(
                                  alpha: 0.08,
                                ),
                                fontSize: fontSize * 0.9,
                              ),
                            ),
                      ),
                    // Timestamp display in overlay
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        TimestampFormatter.format(message.timestamp),
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: fontSize * 0.7,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. M3 Action Bar
          Positioned(
            top: showAbove
                ? bubbleOffset.dy - 70
                : bubbleOffset.dy + bubbleSize.height + 12,
            left: isUser ? null : bubbleOffset.dx,
            right: isUser
                ? MediaQuery.of(context).size.width -
                      (bubbleOffset.dx + bubbleSize.width)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionChip(
                    context,
                    isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                    isStarred ? 'Unstar' : 'Star',
                    () {
                      onToggleStar();
                      Navigator.pop(context);
                    },
                    iconColor: isStarred
                        ? Colors.amber.shade600
                        : colorScheme.onSurface,
                  ),
                  _buildActionChip(context, Icons.copy_rounded, 'Copy', () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Message copied to clipboard'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }),
                  _buildActionChip(context, Icons.share_rounded, 'Share', () {
                    SharePlus.instance.share(
                      ShareParams(text: message.content),
                    );
                    Navigator.pop(context);
                  }),
                  if (isUser)
                    _buildActionChip(context, Icons.edit_rounded, 'Edit', () {
                      ref
                          .read(draftMessageProvider.notifier)
                          .update((state) => message.content);
                      ref
                          .read(editingMessageProvider.notifier)
                          .setEditingMessage(message);
                      Navigator.pop(context);
                    })
                  else
                    _buildActionChip(
                      context,
                      Icons.refresh_rounded,
                      'Redo',
                      () {
                        ref
                            .read(chatProvider.notifier)
                            .regenerateMessage(message);
                        Navigator.pop(context);
                      },
                    ),
                  _buildActionChip(
                    context,
                    Icons.delete_outline_rounded,
                    'Delete',
                    () {
                      _confirmDelete(context);
                    },
                    iconColor: colorScheme.error,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    Color? iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = iconColor ?? colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        label: tooltip,
        button: true,
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: color, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_outline_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Delete Message?'),
        content: const Text(
          'This message will be permanently removed from the chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
