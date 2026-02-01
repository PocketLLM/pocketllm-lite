import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';
import '../../../../services/ad_service.dart';
import '../../../../services/usage_limits_provider.dart';
import '../../domain/models/chat_session.dart';
import '../providers/chat_provider.dart';
import '../../../settings/presentation/widgets/export_dialog.dart';
import '../dialogs/tag_editor_dialog.dart';
import 'archived_chats_screen.dart';
import '../../../media/presentation/screens/media_gallery_screen.dart';

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
  int _topBannerRetryCount = 0;
  int _bottomBannerRetryCount = 0;
  static const int _maxBannerRetries = 5;

  // Search & Filter State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // Cache the RegExp to prevent recompilation on every list item build
  RegExp? _cachedSearchRegex;

  String? _selectedModelFilter;
  DateTime? _selectedDateFilter;
  String? _selectedTagFilter;

  @override
  void initState() {
    super.initState();
    // Add a small delay to ensure the widget is built before loading banners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBannerAds();
    });

    // Listen to search controller changes to update state
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // Only update state if the query actually changed
    final newQuery = _searchController.text;
    if (newQuery != _searchQuery) {
      setState(() {
        _searchQuery = newQuery;
        // Update cached RegExp
        if (_searchQuery.isNotEmpty) {
          _cachedSearchRegex = RegExp(
            RegExp.escape(_searchQuery),
            caseSensitive: false,
          );
        } else {
          _cachedSearchRegex = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _topBannerAd?.dispose();
    _bottomBannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadBannerAds() async {
    _loadTopBanner();
    // Add a small delay between loading the two banners
    await Future.delayed(const Duration(milliseconds: 500));
    _loadBottomBanner();
  }

  Future<void> _loadTopBanner() async {
    _topBannerAd?.dispose();
    _topBannerAd = await _adService.createAndLoadBannerAd(
      onLoaded: () {
        if (mounted) {
          setState(() {
            _isTopBannerLoaded = true;
            _topBannerRetryCount = 0; // Reset retry count on success
          });
        }
      },
      onFailed: (error) {
        if (kDebugMode) {
          // print('Top banner ad failed to load: $error');
        }
        if (mounted) {
          setState(() => _isTopBannerLoaded = false);
          // Retry with longer delay and max retries
          if (_topBannerRetryCount < _maxBannerRetries) {
            _topBannerRetryCount++;
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && !_isTopBannerLoaded) {
                _loadTopBanner();
              }
            });
          }
        }
      },
    );
  }

  Future<void> _loadBottomBanner() async {
    _bottomBannerAd?.dispose();
    _bottomBannerAd = await _adService.createAndLoadBannerAd(
      onLoaded: () {
        if (mounted) {
          setState(() {
            _isBottomBannerLoaded = true;
            _bottomBannerRetryCount = 0; // Reset retry count on success
          });
        }
      },
      onFailed: (error) {
        if (kDebugMode) {
          // print('Bottom banner ad failed to load: $error');
        }
        if (mounted) {
          setState(() => _isBottomBannerLoaded = false);
          // Retry with longer delay and max retries
          if (_bottomBannerRetryCount < _maxBannerRetries) {
            _bottomBannerRetryCount++;
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && !_isBottomBannerLoaded) {
                _loadBottomBanner();
              }
            });
          }
        }
      },
    );
  }

  String? _getMatchingSnippet(ChatSession session, RegExp? queryRegex, String query) {
    if (query.isEmpty || queryRegex == null) return null;

    // Search in messages using cached regex
    for (final message in session.messages) {
      final content = message.content;
      final match = queryRegex.firstMatch(content);
      if (match != null) {
        final index = match.start;
        // Found match. Extract snippet.
        int start = (index - 20).clamp(0, content.length);
        int end = (index + query.length + 50).clamp(0, content.length);
        String snippet = content.substring(start, end);
        if (start > 0) snippet = '...$snippet';
        if (end < content.length) snippet = '$snippet...';
        return snippet.replaceAll('\n', ' ');
      }
    }
    return null;
  }

  Widget _buildHighlightedText(
    String text,
    String query,
    TextStyle style,
    Color highlightColor,
  ) {
    // Basic optimization: if query not in text, return plain text
    // (Though snippet logic ensures it usually is)
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    final children = <TextSpan>[];
    int start = 0;
    int index = lowerText.indexOf(lowerQuery, start);

    if (index == -1) {
      return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    }

    while (index != -1) {
      if (index > start) {
        children.add(TextSpan(text: text.substring(start, index)));
      }
      children.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: style.copyWith(
            fontWeight: FontWeight.bold,
            color: highlightColor,
          ),
        ),
      );
      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    if (start < text.length) {
      children.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      text: TextSpan(style: style, children: children),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSubtitle(
    ChatSession session,
    String query,
    RegExp? queryRegex,
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final defaultStyle = TextStyle(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (query.isEmpty || queryRegex == null) {
      // Show date and last message preview
      DateTime dateToShow = session.createdAt;
      String preview = '';

      if (session.messages.isNotEmpty) {
        final lastMsg = session.messages.last;
        dateToShow = lastMsg.timestamp;
        preview = lastMsg.content.replaceAll('\n', ' ').trim();
        if (preview.length > 60) {
          preview = '${preview.substring(0, 60)}...';
        }
      }

      final dateStr = _formatDate(dateToShow);
      final text = preview.isNotEmpty ? '$dateStr  •  $preview' : dateStr;

      return Text(
        text,
        style: defaultStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final snippet = _getMatchingSnippet(session, queryRegex, query);
    if (snippet == null) {
      // Matched in title
      return Text(_formatDate(session.createdAt), style: defaultStyle);
    }

    // Matched in content - highlight
    return _buildHighlightedText(
      snippet,
      query,
      defaultStyle,
      theme.colorScheme.primary,
    );
  }

  Future<void> _handleNewChat() async {
    HapticFeedback.mediumImpact();

    // Check chat limit
    final limitsNotifier = ref.read(usageLimitsProvider.notifier);
    if (!limitsNotifier.canCreateChat()) {
      await _showChatLimitDialog();
      return;
    }

    await limitsNotifier.incrementChatCount();
    ref.read(chatProvider.notifier).newChat();
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _handleViewArchived() async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ArchivedChatsScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _isSearching
          ? AppBar(
              title: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    // Listener will handle query update
                  });
                },
              ),
              actions: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
              ],
            )
          : AppBar(
              title: Text(
                _isSelectionMode
                    ? '${_selectedIds.length} Selected'
                    : 'Chat History',
              ),
              actions: [
                if (_isSelectionMode) ...[
                  IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Export selected chats',
                    onPressed: _selectedIds.isEmpty ? null : _exportSelected,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete selected chats',
                    onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Search chats',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isSearching = true;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color:
                          (_selectedModelFilter != null ||
                                  _selectedDateFilter != null ||
                                  _selectedTagFilter != null)
                              ? theme.colorScheme.primary
                              : null,
                    ),
                    tooltip: 'Filter chats',
                    onPressed: () => _showFilterDialog(storage),
                  ),
                  IconButton(
                    icon: const Icon(Icons.photo_library_outlined),
                    tooltip: 'Media Gallery',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const MediaGalleryScreen(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.archive_outlined),
                    tooltip: 'Archived Chats',
                    onPressed: _handleViewArchived,
                  ),
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
              ],
              leading: _isSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel selection',
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
                      tooltip: 'Back',
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
              height: 60,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: AdWidget(ad: _topBannerAd!),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.refresh,
                          size: 14,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          _topBannerRetryCount = 0;
                          _loadTopBanner();
                        },
                        padding: EdgeInsets.all(2),
                        constraints: BoxConstraints.tight(Size(18, 18)),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (!_isTopBannerLoaded)
            Container(
              height: 60,
              alignment: Alignment.center,
              color: Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Top ad loading...',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, size: 14),
                    onPressed: () {
                      _topBannerRetryCount = 0;
                      _loadTopBanner();
                    },
                    padding: EdgeInsets.all(4),
                  ),
                ],
              ),
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

          if (_selectedModelFilter != null ||
              _selectedDateFilter != null ||
              _selectedTagFilter != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_selectedModelFilter != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text('Model: $_selectedModelFilter'),
                          onDeleted:
                              () => setState(() => _selectedModelFilter = null),
                        ),
                      ),
                    if (_selectedTagFilter != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text('Tag: $_selectedTagFilter'),
                          onDeleted:
                              () => setState(() => _selectedTagFilter = null),
                        ),
                      ),
                    if (_selectedDateFilter != null)
                      Chip(
                        label: Text(
                          'After: ${_formatDate(_selectedDateFilter!).split(' ')[0]}',
                        ),
                        onDeleted:
                            () => setState(() => _selectedDateFilter = null),
                      ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: ValueListenableBuilder<Box<ChatSession>>(
              valueListenable: storage.chatBoxListenable,
              builder: (context, box, _) {
                final sessions = storage.searchSessions(
                  query: _searchQuery,
                  model: _selectedModelFilter,
                  fromDate: _selectedDateFilter,
                  tag: _selectedTagFilter,
                );

                if (sessions.isEmpty) {
                  if (_searchQuery.isNotEmpty ||
                      _selectedModelFilter != null ||
                      _selectedDateFilter != null ||
                      _selectedTagFilter != null) {
                    return const _EmptyHistoryState(
                      icon: Icons.search_off,
                      title: 'No results found',
                      subtitle: 'Try adjusting your search or filters',
                    );
                  }

                  return _EmptyHistoryState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No chat history',
                    subtitle: 'Start a new conversation to begin',
                    action: FilledButton.icon(
                      onPressed: _handleNewChat,
                      icon: const Icon(Icons.add),
                      label: const Text('Start New Chat'),
                    ),
                  );
                }

                // Split into Pinned and Recent if not searching
                List<ChatSession> pinnedSessions = [];
                List<ChatSession> recentSessions = [];

                final isFiltering =
                    _searchQuery.isNotEmpty ||
                    _selectedModelFilter != null ||
                    _selectedDateFilter != null ||
                    _selectedTagFilter != null;

                if (!isFiltering) {
                  for (var session in sessions) {
                    if (storage.isArchived(session.id)) {
                      continue; // Skip archived chats in main history
                    }
                    if (storage.isPinned(session.id)) {
                      pinnedSessions.add(session);
                    } else {
                      recentSessions.add(session);
                    }
                  }
                  // Sort recent sessions by date just in case
                  // (Assuming sessions are already sorted by date from storageService)
                } else {
                  // If filtering, still exclude archived?
                  // Usually search searches everything, but Archive is meant to be hidden.
                  // Let's hide archived unless explicitly searching in Archive screen.
                  // Or should search find archived items?
                  // Standard behavior: Archive hides from main list. Search might find them.
                  // For now, let's exclude them to keep "Archive" meaning "Hidden".
                  // OR include them but mark as archived?
                  // Let's exclude for consistency.
                  recentSessions = sessions
                      .where((s) => !storage.isArchived(s.id))
                      .toList();
                }

                if (!isFiltering &&
                    pinnedSessions.isEmpty &&
                    recentSessions.isEmpty) {
                  return _EmptyHistoryState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No active chats',
                    subtitle: 'All your chats are archived',
                    action: TextButton.icon(
                      onPressed: _handleViewArchived,
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('View Archived'),
                    ),
                  );
                }

                // Optimization: Use CustomScrollView with Slivers to lazily build list items.
                // This prevents constructing all list tiles at once for large histories.
                return CustomScrollView(
                  slivers: [
                    const SliverPadding(padding: EdgeInsets.only(top: 8)),
                    if (!isFiltering && pinnedSessions.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(
                            'Pinned',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildChatListTile(
                              session: pinnedSessions[index],
                              storage: storage,
                              theme: theme,
                              isPinned: true,
                            );
                          },
                          childCount: pinnedSessions.length,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            'Recent',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final session = recentSessions[index];
                          return _buildChatListTile(
                            session: session,
                            storage: storage,
                            theme: theme,
                            isPinned:
                                !isFiltering && storage.isPinned(session.id),
                          );
                        },
                        childCount: recentSessions.length,
                      ),
                    ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
                  ],
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
                height: 60,
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: AdWidget(ad: _bottomBannerAd!),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.refresh,
                            size: 14,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _bottomBannerRetryCount = 0;
                            _loadBottomBanner();
                          },
                          padding: EdgeInsets.all(2),
                          constraints: BoxConstraints.tight(Size(18, 18)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (!_isBottomBannerLoaded)
            SafeArea(
              child: Container(
                height: 60,
                alignment: Alignment.center,
                color: Colors.grey[200],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Bottom ad loading...',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, size: 14),
                      onPressed: () {
                        _bottomBannerRetryCount = 0;
                        _loadBottomBanner();
                      },
                      padding: EdgeInsets.all(4),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _handleNewChat,
              label: const Text('New Chat'),
              icon: const Icon(Icons.add),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showFilterDialog(dynamic storage) {
    showDialog(
      context: context,
      builder: (context) {
        // Temp state for dialog
        String? tempModel = _selectedModelFilter;
        DateTime? tempDate = _selectedDateFilter;
        String? tempTag = _selectedTagFilter;
        final models = storage.getAvailableModels();
        final tags = storage.getAllTags();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter Chats'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date Range',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Anytime'),
                        selected: tempDate == null,
                        onSelected: (val) => setState(() => tempDate = null),
                      ),
                      ChoiceChip(
                        label: const Text('Last 7 Days'),
                        selected:
                            tempDate != null &&
                            tempDate!.difference(DateTime.now()).inDays.abs() <
                                8,
                        onSelected: (val) {
                          if (val) {
                            setState(
                              () => tempDate = DateTime.now().subtract(
                                const Duration(days: 7),
                              ),
                            );
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Last 30 Days'),
                        selected:
                            tempDate != null &&
                            tempDate!.difference(DateTime.now()).inDays.abs() >
                                8,
                        onSelected: (val) {
                          if (val) {
                            setState(
                              () => tempDate = DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Model',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tempModel,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    hint: const Text('All Models'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Models'),
                      ),
                      ...models.map(
                        (m) =>
                            DropdownMenuItem<String>(value: m, child: Text(m)),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => tempModel = val);
                    },
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Tag',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: tempTag,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      hint: const Text('All Tags'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Tags'),
                        ),
                        ...tags.map(
                          (t) =>
                              DropdownMenuItem<String>(value: t, child: Text(t)),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => tempTag = val);
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    this.setState(() {
                      _selectedModelFilter = tempModel;
                      _selectedDateFilter = tempDate;
                      _selectedTagFilter = tempTag;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _loadSession(ChatSession session) {
    ref.read(chatProvider.notifier).loadSession(session);
    Navigator.pop(context);
  }

  void _showSessionOptions(ChatSession session) {
    final storage = ref.read(storageServiceProvider);
    final isPinned = storage.isPinned(session.id);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chat Options',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin,
              ),
              title: Text(isPinned ? 'Unpin Chat' : 'Pin Chat'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await storage.togglePin(session.id);
                // Force rebuild to show changes
                if (!mounted) return;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isPinned ? 'Chat unpinned' : 'Chat pinned'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive Chat'),
              onTap: () async {
                Navigator.pop(context);
                await storage.toggleArchive(session.id);
                if (!mounted) return;
                setState(() {});
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Chat archived')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('Manage Tags'),
              onTap: () {
                Navigator.pop(sheetContext);
                showDialog(
                  context: context,
                  builder:
                      (context) =>
                          TagEditorDialog(chatId: session.id, storage: storage),
                ).then((_) {
                  if (mounted) setState(() {});
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename Chat'),
              onTap: () {
                Navigator.pop(sheetContext);
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
                Navigator.pop(sheetContext);
                _deleteSession(session.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatListTile({
    required ChatSession session,
    required dynamic storage,
    required ThemeData theme,
    required bool isPinned,
  }) {
    final isSelected = _selectedIds.contains(session.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              backgroundColor: isPinned
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                isPinned ? Icons.push_pin : Icons.chat_bubble_outline,
                size: 20,
                color: isPinned
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
      title: Text(
        session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubtitle(session, _searchQuery, _cachedSearchRegex, context),
          Builder(
            builder: (context) {
              final tags = storage.getTagsForChat(session.id);
              if (tags.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children: tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
      trailing: !_isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Open chat',
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
            onPressed: () async {
              if (!await _adService.hasInternetConnection()) {
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
      await _adService.showChatCreationRewardedAd(
        onUserEarnedReward: (reward) async {
          final limitsNotifier = ref.read(usageLimitsProvider.notifier);
          await limitsNotifier.addChatCredits(AppConstants.chatsPerAdWatch);

          if (mounted) {
            // Immediately use one credit to create the chat
            await limitsNotifier.incrementChatCount();
            if (!mounted) return;

            ref.read(chatProvider.notifier).newChat();

            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unlocked more chats! New chat created.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context); // Go back to chat screen
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
                color: Colors.blue.withValues(alpha: 0.1),
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

      await _adService.showDeletionRewardedAd(
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

  Future<void> _exportSelected() async {
    if (_selectedIds.isEmpty) return;

    await showDialog(
      context: context,
      builder: (context) => ExportDialog(selectedChatIds: _selectedIds),
    );
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
                color: Colors.blue.withValues(alpha: 0.1),
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

      await _adService.showDeletionRewardedAd(
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

class _EmptyHistoryState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _EmptyHistoryState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                      : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: 32),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
