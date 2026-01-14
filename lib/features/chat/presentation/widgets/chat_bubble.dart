import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/image_decoder.dart';
import '../../../../core/utils/url_validator.dart';
import '../../domain/models/chat_message.dart';
import '../../../settings/presentation/providers/appearance_provider.dart';
import 'three_dot_loading_indicator.dart';

// Helper class for formatting timestamps
class TimestampFormatter {
  static String format(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays < 1) {
      // Format as HH:MM AM/PM
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

  @override
  void initState() {
    super.initState();
    _decodeImages();
  }

  @override
  void didUpdateWidget(ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-decode if the image list actually changed.
    // Using listEquals from foundation to check content equality if references differ.
    final oldImages = oldWidget.message.images;
    final newImages = widget.message.images;
    if (oldImages != newImages && !listEquals(oldImages, newImages)) {
      _decodeImages();
    }
  }

  Future<void> _decodeImages() async {
    if (widget.message.images != null && widget.message.images!.isNotEmpty) {
      // Use Isolate to decode images off the main thread to avoid UI jank
      // during scrolling or message reception.
      final images =
          await IsolateImageDecoder.decodeImages(widget.message.images!);
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

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.role == 'user';
    final theme = Theme.of(context);
    final appearance = ref.watch(appearanceProvider);

    // Appearance Values
    final bubbleColor = isUser
        ? Color(
            appearance.userMsgColor,
          ).withValues(alpha: appearance.msgOpacity)
        : Color(appearance.aiMsgColor).withValues(alpha: appearance.msgOpacity);
    final radius = appearance.bubbleRadius;
    final fontSize = appearance.fontSize;
    final padding = appearance.chatPadding;
    final hasElevation = appearance.bubbleElevation;

    // Show loading indicator for empty assistant messages (AI is generating)
    if (!isUser && message.content.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: hasElevation
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: const ThreeDotLoadingIndicator(
                color: Colors.white,
                size: 6.0,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showFocusedMenu(context, isUser);
              },
              child: Hero(
                tag: 'bubble_${message.hashCode}',
                // Note: Hero helps transition if we pushed a page,
                // but for overlay we manually position.
                // Keeping tag just in case or we can remove if unused.
                child: Container(
                  key: _bubbleKey,
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(radius).copyWith(
                      bottomRight: isUser ? const Radius.circular(0) : null,
                      bottomLeft: !isUser ? const Radius.circular(0) : null,
                    ),
                    boxShadow: hasElevation
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_decodedImages != null && _decodedImages!.isNotEmpty)
                        ..._decodedImages!.map(
                          (bytes) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                bytes,
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      if (isUser)
                        Text(
                          message.content,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                            fontSize: fontSize,
                          ),
                        )
                      else
                        MarkdownBody(
                          data: message.content,
                          onTapLink: (text, href, title) async {
                            if (href != null) {
                              final uri = Uri.tryParse(href);
                              // Use UrlValidator to ensure we only launch secure schemes (http, https, mailto)
                              if (UrlValidator.isSecureUrl(uri) &&
                                  await canLaunchUrl(uri!)) {
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
                                  color: Colors.white,
                                  fontSize: fontSize,
                                ),
                                code: theme.textTheme.bodyMedium?.copyWith(
                                  backgroundColor: Colors.black26,
                                  fontSize: fontSize * 0.9,
                                ),
                              ),
                        ),
                      // Timestamp display
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          TimestampFormatter.format(message.timestamp),
                          style: TextStyle(
                            color: Colors.white70,
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
          ),
        ],
      ),
    );
  }

  void _showFocusedMenu(BuildContext context, bool isUser) {
    // 1. Calculate Position
    final RenderBox renderBox =
        _bubbleKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(
          alpha: 0.2,
        ), // Slight dim initially, animated in widget
        pageBuilder: (context, _, __) => _FocusedMenuOverlay(
          child: widget, // Pass actual widget or reconstructed bubble
          message: widget.message,
          bubbleSize: size,
          bubbleOffset: offset,
          isUser: isUser,
          ref: ref,
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

class _FocusedMenuOverlay extends StatelessWidget {
  final Widget
  child; // We will reconstruct visually or use cached image if needed, but easier to rebuild basic container
  final ChatMessage message;
  final Size bubbleSize;
  final Offset bubbleOffset;
  final bool isUser;
  final WidgetRef ref;

  const _FocusedMenuOverlay({
    required this.child,
    required this.message,
    required this.bubbleSize,
    required this.bubbleOffset,
    required this.isUser,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    // Reconstruct appearance to match exactly
    final theme = Theme.of(context);
    // Use ref to get current snapshot
    final appearance = ref.read(appearanceProvider);

    final bubbleColor = isUser
        ? Color(
            appearance.userMsgColor,
          ).withValues(alpha: appearance.msgOpacity)
        : Color(appearance.aiMsgColor).withValues(alpha: appearance.msgOpacity);
    final radius = appearance.bubbleRadius;
    final fontSize = appearance.fontSize;
    final padding = appearance.chatPadding;

    // Determine where to put actions: Above or Below?
    // If bubble is too low, put above.
    final screenHeight = MediaQuery.of(context).size.height;
    final showAbove = bubbleOffset.dy > screenHeight * 0.6;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Blur Backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),

          // 2. Dismiss logic (tap anywhere)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
          ),

          // 3. Highlighted Bubble
          Positioned(
            top: bubbleOffset.dy,
            left: bubbleOffset.dx,
            width: bubbleSize.width,
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              shadowColor: Colors.black45,
              child: Container(
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(radius).copyWith(
                    bottomRight: isUser ? const Radius.circular(0) : null,
                    bottomLeft: !isUser ? const Radius.circular(0) : null,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ), // Highlight border
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Same content rendering ... simplified for overlay (no images for brevity if desired, or duplicate)
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
                          color: Colors.white,
                          fontSize: fontSize,
                        ),
                      )
                    else
                      MarkdownBody(
                        data: message.content,
                        styleSheet: MarkdownStyleSheet.fromTheme(theme)
                            .copyWith(
                              p: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontSize: fontSize,
                              ),
                              code: theme.textTheme.bodyMedium?.copyWith(
                                backgroundColor: Colors.black26,
                                fontSize: fontSize * 0.9,
                              ),
                            ),
                      ),
                    // Timestamp display in overlay
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        TimestampFormatter.format(message.timestamp),
                        style: TextStyle(
                          color: Colors.white70,
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

          // 4. Action Icons
          Positioned(
            top: showAbove
                ? bubbleOffset.dy - 70
                : bubbleOffset.dy + bubbleSize.height + 10,
            left: isUser ? null : bubbleOffset.dx,
            right: isUser
                ? MediaQuery.of(context).size.width -
                      (bubbleOffset.dx + bubbleSize.width)
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconBtn(context, Icons.copy, 'Copy', () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Message copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }),
                const SizedBox(width: 12),
                _buildIconBtn(context, Icons.share, 'Share', () {
                  Share.share(message.content);
                  Navigator.pop(context);
                }),
                if (isUser) ...[
                  const SizedBox(width: 12),
                  _buildIconBtn(context, Icons.edit, 'Edit', () {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Edit feature coming soon!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onTap,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: tooltip,
          button: true,
          child: Material(
            color: Colors.white.withValues(alpha: 0.2),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        ExcludeSemantics(
          child: Text(
            tooltip,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
