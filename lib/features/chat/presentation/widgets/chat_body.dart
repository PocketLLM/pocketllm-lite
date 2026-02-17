import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import '../../../../core/theme/app_motion.dart';
import '../../domain/models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/connection_status_provider.dart';
import '../providers/draft_message_provider.dart';
import 'chat_bubble.dart';

class ChatBody extends ConsumerStatefulWidget {
  const ChatBody({super.key});

  @override
  ConsumerState<ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<ChatBody> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  DateTime? _lastAutoScroll;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final show = (maxScroll - currentScroll) > 300;

    if (show != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = show;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppMotion.durationMD,
        curve: AppMotion.curveEnter,
      );
    }
  }

  void _throttledScrollToBottom() {
    final now = DateTime.now();
    if (_lastAutoScroll == null ||
        now.difference(_lastAutoScroll!) > const Duration(milliseconds: 100)) {
      _scrollToBottom();
      _lastAutoScroll = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatusAsync = ref.watch(autoConnectionStatusProvider);
    final messages = ref.watch(chatProvider.select((s) => s.messages));
    final isGenerating = ref.watch(chatProvider.select((s) => s.isGenerating));
    final hasStreamingContent = ref.watch(
      chatProvider.select((s) => s.streamingContent.isNotEmpty),
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Auto-scroll logic
    ref.listen(chatProvider.select((s) => s.messages.length), (prev, next) {
      if (next > (prev ?? 0)) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    // Throttled scroll for streaming content
    ref.listen(chatProvider.select((s) => s.streamingContent.length), (
      prev,
      next,
    ) {
      if (next > (prev ?? 0)) {
        _throttledScrollToBottom();
      }
    });

    return connectionStatusAsync.when(
      data: (isConnected) {
        if (!isConnected) {
          return _DisconnectedState();
        }

        if (messages.isEmpty) {
          return const _EmptyState();
        }

        return Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              itemCount:
                  messages.length +
                  (isGenerating && hasStreamingContent ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < messages.length) {
                  return ChatBubble(
                    key: ValueKey(messages[index]),
                    message: messages[index],
                  );
                } else {
                  return const _StreamingChatBubble();
                }
              },
            ),
            // Scroll-to-bottom FAB
            Positioned(
              right: 16,
              bottom: 16,
              child: AnimatedSwitcher(
                duration: AppMotion.durationSM,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: AppMotion.curveOvershoot,
                  ),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: _showScrollToBottom
                    ? Semantics(
                        key: const ValueKey('scroll_fab'),
                        label: 'Scroll to bottom',
                        button: true,
                        child: FloatingActionButton.small(
                          onPressed: _scrollToBottom,
                          tooltip: 'Scroll to bottom',
                          backgroundColor: colorScheme.surfaceContainerHigh,
                          foregroundColor: colorScheme.primary,
                          elevation: 3,
                          child: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}

/// Disconnected state — M3 themed with M3 expressive shape
class _DisconnectedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              M3Container(
                Shapes.soft_burst,
                width: 100,
                height: 100,
                color: colorScheme.errorContainer.withValues(alpha: 0.5),
                child: Center(
                  child: Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Not Connected',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please ensure Ollama is running and connected',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('Configure'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/settings/docs'),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Setup Guide'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state — M3 themed with staggered suggestion chips
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final suggestions = [
      (icon: Icons.sentiment_satisfied_rounded, text: 'Tell me a joke'),
      (icon: Icons.science_rounded, text: 'Explain quantum computing'),
      (icon: Icons.code_rounded, text: 'Write a python script'),
      (icon: Icons.menu_book_rounded, text: 'Summarize a book'),
    ];

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // M3 Expressive shape icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: AppMotion.durationXL,
                curve: AppMotion.curveOvershoot,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(opacity: value.clamp(0, 1), child: child),
                  );
                },
                child: M3Container(
                  Shapes.flower,
                  width: 100,
                  height: 100,
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  child: Center(
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 44,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Semantics(
                header: true,
                child: Text(
                  'How can I help you?',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'PocketLLM is ready to chat.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 36),
              // Staggered suggestion chips
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutQuart,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 24 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: suggestions.map((suggestion) {
                    return Semantics(
                      button: true,
                      hint: 'Populates the message input',
                      child: ActionChip(
                        label: Text(suggestion.text),
                        avatar: Icon(suggestion.icon, size: 18),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref.read(draftMessageProvider.notifier).state =
                              suggestion.text;
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamingChatBubble extends ConsumerStatefulWidget {
  const _StreamingChatBubble();

  @override
  ConsumerState<_StreamingChatBubble> createState() =>
      _StreamingChatBubbleState();
}

class _StreamingChatBubbleState extends ConsumerState<_StreamingChatBubble> {
  late final DateTime _timestamp;

  @override
  void initState() {
    super.initState();
    _timestamp = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(chatProvider.select((s) => s.streamingContent));

    return ChatBubble(
      message: ChatMessage(
        role: 'assistant',
        content: content,
        timestamp: _timestamp,
      ),
    );
  }
}
