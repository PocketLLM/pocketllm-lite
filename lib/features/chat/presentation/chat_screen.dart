import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';
import 'providers/chat_provider.dart';
import 'providers/models_provider.dart';

import 'widgets/chat_body.dart';
import 'widgets/chat_input.dart';
import 'dialogs/chat_settings_dialog.dart';
import 'screens/chat_history_screen.dart';
import '../../media/presentation/screens/media_gallery_screen.dart';
import '../../../core/widgets/m3_app_bar.dart';
import '../../../providers/model_manager_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    final state = ref.read(modelManagerProvider);
    if (state.activeLoadedId != null) {
      ref.read(modelManagerProvider.notifier).unloadActiveModel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Memory Pressure Alert: Local model unloaded from RAM to prevent application crash.',
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedModel = ref.watch(
      chatProvider.select((s) => s.selectedModel),
    );
    final modelsAsync = ref.watch(unifiedModelsProvider);
    final localState = ref.watch(modelManagerProvider);
    final activeLoadedId = localState.activeLoadedId;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: M3AppBar(
        title: '',
        automaticallyImplyLeading: false,
        titleWidget: Row(
          children: [
            Expanded(
              child: modelsAsync.when(
                data: (models) {
                  String? currentValue = selectedModel;
                  if (models.isNotEmpty &&
                      !models.any((m) => m.id == currentValue)) {
                    currentValue = models.first.id;
                    Future.microtask(
                      () => ref
                          .read(chatProvider.notifier)
                          .setModel(currentValue!),
                    );
                  }

                  if (models.isEmpty) {
                    return Text(
                      'No Models Available',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    );
                  }

                  return Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Container(
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
                            isExpanded: true,
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
                                final isActive = m.id == activeLoadedId;
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isActive) ...[
                                        Icon(
                                          Icons.bolt_rounded,
                                          size: 14,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Flexible(
                                        child: Text(
                                          m.name,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList();
                            },
                            items: models.map<DropdownMenuItem<String>>((m) {
                              final isActive = m.id == activeLoadedId;
                              return DropdownMenuItem<String>(
                                value: m.id,
                                child: Row(
                                  children: [
                                    Text(
                                      m.isLocal ? '📁 ' : '☁️ ',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      m.name,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: isActive
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    if (isActive) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.tertiaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'RAM',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color:
                                                colorScheme.onTertiaryContainer,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                final activeId = ref
                                    .read(modelManagerProvider)
                                    .activeLoadedId;
                                if (activeId != null && activeId != newModel) {
                                  ref
                                      .read(modelManagerProvider.notifier)
                                      .unloadActiveModel();
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, s) => Text(
                  'Error loading models',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
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
                        '${lastTps.toStringAsFixed(1)} t/s${lastTtftMs != null ? ' • ${lastTtftMs}ms' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
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
          if (activeLoadedId != null)
            IconButton(
              icon: Icon(Icons.power_settings_new_rounded,
                  color: colorScheme.error),
              tooltip: 'Unload Local Model',
              onPressed: () {
                if (ref.read(storageServiceProvider).getSetting(
                      AppConstants.hapticFeedbackKey,
                      defaultValue: true,
                    )) {
                  HapticFeedback.selectionClick();
                }
                ref.read(modelManagerProvider.notifier).unloadActiveModel();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Local GGUF model unloaded from memory.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
              if (ref.read(storageServiceProvider).getSetting(
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
              if (ref.read(storageServiceProvider).getSetting(
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
              if (ref.read(storageServiceProvider).getSetting(
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
              if (ref.read(storageServiceProvider).getSetting(
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
}
