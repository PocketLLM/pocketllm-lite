import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';
import '../../../../services/ad_service.dart';
import '../../domain/models/chat_session.dart';
import '../providers/chat_provider.dart';

class ChatHistoryScreen extends ConsumerStatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  ConsumerState<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends ConsumerState<ChatHistoryScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
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
    _topBannerAd?.dispose();
    _bottomBannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAds() {
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
        },
      ),
    )..load();

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
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode ? '${_selectedIds.length} Selected' : 'Chat History',
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
            )
          else
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Manage Chats',
              onPressed: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _isSelectionMode = true;
                });
              },
            ),
        ],
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
              ),
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
          if (_isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surfaceContainer,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final box = storage.chatBoxListenable.value;
                      setState(() {
                        if (_selectedIds.length == box.length) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds.addAll(box.keys.cast<String>());
                        }
                      });
                    },
                    icon: Icon(
                      _selectedIds.isNotEmpty
                          ? Icons.deselect
                          : Icons.select_all,
                    ),
                    label: Text(
                      _selectedIds.isNotEmpty ? 'Deselect All' : 'Select All',
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ValueListenableBuilder<Box<ChatSession>>(
              valueListenable: storage.chatBoxListenable,
              builder: (context, box, _) {
                final sessions = box.values.toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (sessions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_toggle_off,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No chat history',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isSelected = _selectedIds.contains(session.id);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: _isSelectionMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(session.id);
                                  } else {
                                    _selectedIds.remove(session.id);
                                  }
                                });
                              },
                            )
                          : CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Icon(
                                Icons.chat_bubble_outline,
                                size: 20,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                      title: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _formatDate(session.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: !_isSelectionMode
                          ? IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => _loadSession(session),
                            )
                          : null,
                      onTap: () {
                        if (_isSelectionMode) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(session.id);
                            } else {
                              _selectedIds.add(session.id);
                            }
                          });
                        } else {
                          HapticFeedback.lightImpact();
                          _loadSession(session);
                        }
                      },
                      onLongPress: _isSelectionMode
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              _showSessionOptions(session);
                            },
                    );
                  },
                );
              },
            ),
          ),
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
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(chatProvider.notifier).newChat();
                Navigator.pop(context); // Go back to chat screen with new chat
              },
              label: const Text('New Chat'),
              icon: const Icon(Icons.add),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _loadSession(ChatSession session) {
    ref.read(chatProvider.notifier).loadSession(session);
    Navigator.pop(context);
  }

  void _showSessionOptions(ChatSession session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename Chat'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Chat',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteSession(session.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(ChatSession session) {
    final controller = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Chat Title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final storage = ref.read(storageServiceProvider);
                final updated = session.copyWith(title: controller.text.trim());
                storage.saveChatSession(updated);
                HapticFeedback.mediumImpact();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(String id) async {
    // Show confirmation with ad requirement
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This chat will be permanently deleted.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.play_circle, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Watch a short ad to confirm',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_circle, size: 18),
            label: const Text('Watch Ad & Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      if (!await _adService.hasInternetConnection()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connect to internet to watch ad and delete.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await _adService.showRewardedAd(
        onUserEarnedReward: (reward) async {
          final storage = ref.read(storageServiceProvider);
          await storage.deleteChatSession(id);
          if (mounted) {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chat deleted!'),
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

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Delete ${_selectedIds.length} chats? This cannot be undone.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.play_circle, size: 18, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Watch a short ad to confirm deletion',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.play_circle, size: 18),
            label: const Text('Watch Ad & Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Check internet and show rewarded ad
      if (!await _adService.hasInternetConnection()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connect to internet to watch ad and delete.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await _adService.showRewardedAd(
        onUserEarnedReward: (reward) async {
          final storage = ref.read(storageServiceProvider);
          for (final id in _selectedIds) {
            await storage.deleteChatSession(id);
          }
          if (mounted) {
            setState(() {
              _selectedIds.clear();
              _isSelectionMode = false;
            });
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chats deleted successfully!'),
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
