import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/ad_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';
import '../../../../services/usage_limits_provider.dart';
import '../providers/chat_provider.dart';

// Helper function to show limit dialog
Future<void> showChatLimitDialog(BuildContext context, WidgetRef ref) async {
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
            // Check internet first
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

  if (result == true && context.mounted) {
    await adService.showChatCreationRewardedAd(
      onUserEarnedReward: (reward) async {
        final limitsNotifier = ref.read(usageLimitsProvider.notifier);
        await limitsNotifier.addChatCredits(AppConstants.chatsPerAdWatch);

        if (context.mounted) {
          // Immediately use one credit to create the chat
          await limitsNotifier.incrementChatCount();
          if (!context.mounted) return;

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
        if (context.mounted) {
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
