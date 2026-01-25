import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';
import '../../../services/usage_limits_provider.dart';
import '../../../services/ad_service.dart';
import 'providers/chat_provider.dart';
import 'providers/models_provider.dart';
import 'providers/connection_status_provider.dart';

import 'widgets/chat_body.dart';
import 'widgets/chat_input.dart';
import 'dialogs/chat_settings_dialog.dart';
import 'screens/chat_history_screen.dart';

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
    // Only watch selectedModel for the AppBar title to prevent unnecessary rebuilds of AppBar
    // when streaming content changes.
    final selectedModel = ref.watch(chatProvider.select((s) => s.selectedModel));
    final modelsAsync = ref.watch(modelsProvider);
    final connectionStatusAsync = ref.watch(autoConnectionStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: connectionStatusAsync.when(
                data: (isConnected) {
                  if (!isConnected) {
                    return Semantics(
                      button: true,
                      label: 'Connection Status: Not Connected',
                      hint: 'Tap to troubleshoot connection issues',
                      child: Tooltip(
                        message: 'Connection Status: Not Connected',
                        child: InkWell(
                          onTap: () => _showConnectionHelpDialog(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_off,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Not Connected',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return modelsAsync.when(
                    data: (models) {
                      String? currentValue = selectedModel;
                      // Check if current value is valid, if not, pick first
                      if (models.isNotEmpty &&
                          !models.any((m) => m.name == currentValue)) {
                        currentValue = models.first.name;
                        // defer update
                        Future.microtask(
                          () => ref
                              .read(chatProvider.notifier)
                              .setModel(currentValue!),
                        );
                      }

                      if (models.isEmpty) return const Text('No Models');

                      return Semantics(
                        label: 'Select AI Model',
                        container: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: false,
                              value: currentValue,
                              icon: Icon(
                                Icons.expand_more,
                                size: 20,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                              dropdownColor:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF1E1E1E)
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              elevation: 4,
                              selectedItemBuilder: (BuildContext context) {
                                return models.map<Widget>((m) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.smart_toy_outlined,
                                        size: 16,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                      const SizedBox(width: 8),
                                      ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 150),
                                        child: Text(
                                          m.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold),
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
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        m.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
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
          IconButton(
            icon: const Icon(Icons.history),
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
            onPressed: () async {
              if (ref.read(storageServiceProvider).getSetting(
                    AppConstants.hapticFeedbackKey,
                    defaultValue: true,
                  )) {
                HapticFeedback.selectionClick();
              }

              final limitsNotifier = ref.read(usageLimitsProvider.notifier);
              if (!limitsNotifier.canCreateChat()) {
                await _showChatLimitDialog();
                return;
              }

              await limitsNotifier.incrementChatCount();
              ref.read(chatProvider.notifier).newChat();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
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
            icon: const Icon(Icons.tune),
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

  Future<void> _showConnectionHelpDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Ollama Not Connected', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pocket LLM cannot reach the Ollama server.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('Possible causes:'),
            SizedBox(height: 4),
            Text('• Ollama is not running (run "ollama serve")'),
            Text('• Termux session was closed'),
            Text('• Incorrect endpoint URL in Settings'),
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
            icon: const Icon(Icons.settings),
            label: const Text('Check Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChatLimitDialog() async {
    final adService = AdService();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat Limit Reached'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              "You've used your ${AppConstants.freeChatsAllowed} free chats.",
            ),
            const SizedBox(height: 8),
            const Text(
              'Watch a short ad to unlock more chats!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (!await adService.hasInternetConnection()) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Connect to WiFi/Data to watch ad and unlock.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                return;
              }
              if (context.mounted) Navigator.pop(context, true);
            },
            icon: const Icon(Icons.play_circle),
            label: const Text('Watch Ad'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await adService.showChatCreationRewardedAd(
        onUserEarnedReward: (reward) async {
          final limitsNotifier = ref.read(usageLimitsProvider.notifier);
          await limitsNotifier.addChatCredits(AppConstants.chatsPerAdWatch);

          if (mounted) {
            await limitsNotifier.incrementChatCount();
            if (!mounted) return;

            ref.read(chatProvider.notifier).newChat();

            if (ref.read(storageServiceProvider).getSetting(
                  AppConstants.hapticFeedbackKey,
                  defaultValue: true,
                )) {
              HapticFeedback.heavyImpact();
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unlocked more chats! New chat created.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onFailed: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ad failed: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    }
  }
}
