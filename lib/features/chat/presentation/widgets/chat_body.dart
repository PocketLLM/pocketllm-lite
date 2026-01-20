import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    // Show button if we are more than 300 pixels away from the bottom
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
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
    // Only watch what we need for the body
    final connectionStatusAsync = ref.watch(autoConnectionStatusProvider);
    final messages = ref.watch(chatProvider.select((s) => s.messages));
    final isGenerating = ref.watch(chatProvider.select((s) => s.isGenerating));
    final hasStreamingContent = ref.watch(
      chatProvider.select((s) => s.streamingContent.isNotEmpty),
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Auto-scroll logic scoped to this widget
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Not Connected',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please ensure Ollama is running and connected',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(Icons.settings),
                      label: const Text('Configure Connection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/settings/docs'),
                      icon: const Icon(Icons.description),
                      label: const Text('Docs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
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
            Positioned(
              right: 16,
              bottom: 16,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
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
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : Colors.white,
                          foregroundColor: theme.colorScheme.primary,
                          elevation: 4,
                          child: const Icon(Icons.arrow_downward),
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

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = [
      'Tell me a joke',
      'Explain quantum computing',
      'Write a python script',
      'Summarize a book',
    ];

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'How can I help you?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'PocketLLM is ready to chat.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: suggestions.map((suggestion) {
                  return ActionChip(
                    label: Text(suggestion),
                    avatar: const Icon(Icons.auto_awesome, size: 16),
                    onPressed: () {
                      ref.read(draftMessageProvider.notifier).state =
                          suggestion;
                    },
                  );
                }).toList(),
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
  // Capture timestamp once when streaming starts to prevent unnecessary
  // object creation and identity changes during high-frequency updates.
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
