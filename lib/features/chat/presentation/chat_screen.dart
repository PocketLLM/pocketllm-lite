import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';
import 'providers/chat_provider.dart';
import 'providers/models_provider.dart';
import 'providers/connection_status_provider.dart';

import 'widgets/chat_body.dart';
import 'widgets/chat_input.dart';
import 'dialogs/chat_settings_dialog.dart';
import 'screens/chat_history_screen.dart';
import '../../media/presentation/screens/media_gallery_screen.dart';
import '../../../core/widgets/m3_app_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final selectedModel = ref.watch(
      chatProvider.select((s) => s.selectedModel),
    );
    final modelsAsync = ref.watch(modelsProvider);
    final connectionStatusAsync = ref.watch(autoConnectionStatusProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: M3AppBar(
        title: '',
        automaticallyImplyLeading: false,
        titleWidget: Row(
          children: [
            Expanded(
              child: connectionStatusAsync.when(
                data: (isConnected) {
                  if (!isConnected) {
                    return InkWell(
                      onTap: () => _showConnectionHelpDialog(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_off_rounded,
                              size: 14,
                              color: colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Not Connected',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return modelsAsync.when(
                    data: (models) {
                      String? currentValue = selectedModel;
                      if (models.isNotEmpty &&
                          !models.any((m) => m.name == currentValue)) {
                        currentValue = models.first.name;
                        Future.microtask(
                          () => ref
                              .read(chatProvider.notifier)
                              .setModel(currentValue!),
                        );
                      }

                      if (models.isEmpty) {
                        return Text(
                          'No Models',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        );
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: false,
                            value: currentValue,
                            icon: Icon(
                              Icons.expand_more_rounded,
                              size: 20,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                            dropdownColor: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            elevation: 4,
                            selectedItemBuilder: (BuildContext context) {
                              return models.map<Widget>((m) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.smart_toy_outlined,
                                      size: 16,
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 8),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 150,
                                      ),
                                      child: Text(
                                        m.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList();
                            },
                            items: models.map<DropdownMenuItem<String>>((m) {
                              return DropdownMenuItem<String>(
                                value: m.name,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.smart_toy_outlined,
                                      size: 16,
                                      color: colorScheme.onSurface,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      m.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurface,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newModel) {
                              if (newModel != null &&
                                  newModel != selectedModel) {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(chatProvider.notifier)
                                    .setModel(newModel);
                              }
                            },
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final chatState = ref.watch(chatProvider);
              final lastTps = chatState.lastTps;
              final lastTtftMs = chatState.lastTtftMs;
              final isGenerating = chatState.isGenerating;

              if (isGenerating && lastTps != null && lastTps > 0) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Tooltip(
                    message: 'Live inference speed',
                    child: RawChip(
                      avatar: const Icon(
                        Icons.offline_bolt_rounded,
                        size: 14,
                        color: Colors.green,
                      ),
                      label: Text(
                        '${lastTps.toStringAsFixed(1)} t/s' +
                            (lastTtftMs != null ? ' • ${lastTtftMs}ms' : ''),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      border: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 0,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Media Gallery',
            onPressed: () {
              final sessionId = ref.read(chatProvider).currentSessionId;
              final storage = ref.read(storageServiceProvider);
              if (sessionId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No media yet for this chat.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              final session = storage.getChatSession(sessionId);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MediaGalleryScreen(
                    chatId: sessionId,
                    chatTitle: session?.title ?? 'Chat',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'History',
            onPressed: () {
              if (ref
                  .read(storageServiceProvider)
                  .getSetting(
                    AppConstants.hapticFeedbackKey,
                    defaultValue: true,
                  )) {
                HapticFeedback.selectionClick();
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChatHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New Chat',
            onPressed: () {
              if (ref
                  .read(storageServiceProvider)
                  .getSetting(
                    AppConstants.hapticFeedbackKey,
                    defaultValue: true,
                  )) {
                HapticFeedback.selectionClick();
              }
              ref.read(chatProvider.notifier).newChat();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () {
              if (ref
                  .read(storageServiceProvider)
                  .getSetting(
                    AppConstants.hapticFeedbackKey,
                    defaultValue: true,
                  )) {
                HapticFeedback.selectionClick();
              }
              context.push('/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Chat Settings',
            onPressed: () {
              if (ref
                  .read(storageServiceProvider)
                  .getSetting(
                    AppConstants.hapticFeedbackKey,
                    defaultValue: true,
                  )) {
                HapticFeedback.selectionClick();
              }
              showDialog(
                context: context,
                builder: (context) => const ChatSettingsDialog(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Expanded(child: ChatBody()),
          const ChatInput(),
        ],
      ),
    );
  }

  Future<void> _showConnectionHelpDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.cloud_off_rounded, color: colorScheme.error),
        title: const Text('Ollama Not Connected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pocket LLM cannot reach the Ollama server.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Possible causes:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            ...[
              'Ollama is not running (run "ollama serve")',
              'Termux session was closed',
              'Incorrect endpoint URL in Settings',
            ].map(
              (cause) => Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    Expanded(
                      child: Text(
                        cause,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/settings');
            },
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Check Settings'),
          ),
        ],
      ),
    );
  }
}
