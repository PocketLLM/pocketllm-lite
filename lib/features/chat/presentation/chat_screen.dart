import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers.dart';
import '../../../services/ad_service.dart';
import '../../../services/usage_limits_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/models_provider.dart';

import 'widgets/chat_bubble.dart';
import 'widgets/chat_input.dart';
import 'dialogs/chat_settings_dialog.dart';
import 'screens/chat_history_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final AdService _adService = AdService();
  bool _isTopBannerLoaded = false;
  bool _isBottomBannerLoaded = false;
  BannerAd? _topBannerAd;
  BannerAd? _bottomBannerAd;

  @override
  void initState() {
    super.initState();
    _loadBannerAds();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _topBannerAd?.dispose();
    _bottomBannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAds() {
    // Top banner
    _topBannerAd = BannerAd(
      adUnitId: AppConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isTopBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _isTopBannerLoaded = false);
        },
      ),
    )..load();

    // Bottom banner
    _bottomBannerAd = BannerAd(
      adUnitId: AppConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isBottomBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _isBottomBannerLoaded = false);
        },
      ),
    )..load();
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

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final modelsAsync = ref.watch(modelsProvider);

    // Auto-scroll when messages change (especially when generating)
    ref.listen(chatProvider, (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0) ||
          (next.isGenerating && next.messages.isNotEmpty)) {
        // Delay slightly to let layout build
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: modelsAsync.when(
          data: (models) {
            String? currentValue = chatState.selectedModel;
            // Check if current value is valid, if not, pick first
            if (models.isNotEmpty &&
                !models.any((m) => m.name == currentValue)) {
              currentValue = models.first.name;
              // defer update
              Future.microtask(
                () => ref.read(chatProvider.notifier).setModel(currentValue!),
              );
            }

            if (models.isEmpty) return const Text('No Models');

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.4),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  dropdownColor: Theme.of(context).brightness == Brightness.dark
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              m.name,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            m.name,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newModel) {
                    if (newModel != null &&
                        newModel != chatState.selectedModel) {
                      HapticFeedback.selectionClick();
                      ref.read(chatProvider.notifier).setModel(newModel);
                    }
                  },
                ),
              ),
            );
          },
          loading: () => const Text('Loading...'),
          error: (e, s) =>
              const Text('Ollama Disconnected', style: TextStyle(fontSize: 16)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
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
            onPressed: () async {
              if (ref
                  .read(storageServiceProvider)
                  .getSetting(
                    AppConstants.hapticFeedbackKey,
                    defaultValue: true,
                  )) {
                HapticFeedback.selectionClick();
              }

              // Check chat limit
              final limitsNotifier = ref.read(usageLimitsProvider.notifier);
              if (!limitsNotifier.canCreateChat()) {
                await _showChatLimitDialog();
                return;
              }

              // Increment chat count and create new chat
              await limitsNotifier.incrementChatCount();
              ref.read(chatProvider.notifier).newChat();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
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
            icon: const Icon(Icons.tune),
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
          // Top Banner Ad
          if (_isTopBannerLoaded && _topBannerAd != null)
            Container(
              alignment: Alignment.center,
              width: double.infinity,
              height: 50,
              child: AdWidget(ad: _topBannerAd!),
            ),
          Expanded(
            child: chatState.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ensure Ollama is running in Termux',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: chatState.messages[index]);
                    },
                  ),
          ),
          const ChatInput(),
          // Bottom Banner Ad
          if (_isBottomBannerLoaded && _bottomBannerAd != null)
            SafeArea(
              child: Container(
                alignment: Alignment.center,
                width: double.infinity,
                height: 50,
                child: AdWidget(ad: _bottomBannerAd!),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showChatLimitDialog() async {
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
            onPressed: () => Navigator.pop(context, true),
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
      if (!await _adService.hasInternetConnection()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connect to WiFi/Data to watch ad and unlock.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await _adService.showRewardedAd(
        onUserEarnedReward: (reward) async {
          await ref
              .read(usageLimitsProvider.notifier)
              .addChatCredits(AppConstants.chatsPerAdWatch);
          if (mounted) {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unlocked 5 more chats!'),
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
