import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';
import '../widgets/activity_chart.dart';
import '../widgets/usage_stats_cards.dart';

enum LogFilter { all, chats, prompts, settings, system }

class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  String _searchQuery = '';
  LogFilter _selectedFilter = LogFilter.all;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _mapFilterToString(LogFilter filter) {
    switch (filter) {
      case LogFilter.chats:
        return 'chats';
      case LogFilter.prompts:
        return 'prompts';
      case LogFilter.settings:
        return 'settings';
      case LogFilter.system:
        return 'system';
      default:
        return 'all';
    }
  }

  Future<void> _handleExport(StorageService storage) async {
    // Show format selection dialog
    final format = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export Activity Logs'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'csv'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.table_chart_outlined, color: Colors.green),
                  SizedBox(width: 12),
                  Text('CSV (Excel/Sheets)'),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'json'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.code, color: Colors.orange),
                  SizedBox(width: 12),
                  Text('JSON (Raw Data)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (format == null) return;

    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      File file;
      String subject;

      if (format == 'csv') {
        final csvString = storage.exportActivityLogsToCsv();
        file = File('${directory.path}/pocketllm_logs_$timestamp.csv');
        await file.writeAsString(csvString);
        subject = 'Activity Logs (CSV)';
      } else {
        final jsonString = storage.exportActivityLogsToJson();
        file = File('${directory.path}/pocketllm_logs_$timestamp.json');
        await file.writeAsString(jsonString);
        subject = 'Activity Logs (JSON)';
      }

      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'PocketLLM Lite Activity Logs',
            subject: subject,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);
    final stats = storage.getUsageStatistics();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Export Logs',
            onPressed: () => _handleExport(storage),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear Logs',
            onPressed: () => _confirmClearLogs(context, storage),
          ),
        ],
      ),
      body: Column(
        children: [
          // Dashboard Visualization
          ExpansionTile(
            title: Text(
              'Overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            initiallyExpanded: true,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ActivityChart(activity: stats.dailyActivity),
              ),
              const SizedBox(height: 16),
              UsageStatsCards(stats: stats),
              const SizedBox(height: 16),
            ],
          ),

          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(LogFilter.all, 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip(LogFilter.chats, 'Chats'),
                      const SizedBox(width: 8),
                      _buildFilterChip(LogFilter.prompts, 'Prompts'),
                      const SizedBox(width: 8),
                      _buildFilterChip(LogFilter.settings, 'Settings'),
                      const SizedBox(width: 8),
                      _buildFilterChip(LogFilter.system, 'System'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Log List
          Expanded(
            child: ValueListenableBuilder<Box>(
              valueListenable: storage.activityLogBoxListenable,
              builder: (context, box, _) {
                final filteredLogs = storage.searchActivityLogs(
                  query: _searchQuery,
                  filter: _mapFilterToString(_selectedFilter),
                );

                if (filteredLogs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_toggle_off,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No activity logs yet'
                              : 'No matching logs found',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = filteredLogs[index];
                    final timestamp = DateTime.parse(log['timestamp']);
                    final action = log['action'] ?? 'Unknown';
                    final details = log['details'] ?? '';

                    // Date header logic could be added here, but keep it simple for now
                    // Just show the list tile
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index == 0 ||
                            !_isSameDay(
                              DateTime.parse(
                                filteredLogs[index - 1]['timestamp'],
                              ),
                              timestamp,
                            ))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                            child: Text(
                              _formatDateHeader(timestamp),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ListTile(
                          leading: _buildIconForAction(action),
                          title: Text(
                            action,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                details,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('HH:mm:ss').format(timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          onLongPress: () {
                            Clipboard.setData(
                              ClipboardData(text: '$action: $details'),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Log details copied to clipboard',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 1),
                              ),
                            );
                            HapticFeedback.selectionClick();
                          },
                        ),
                        if (index < filteredLogs.length - 1)
                          Divider(
                            height: 1,
                            indent: 72,
                            endIndent: 16,
                            color: theme.dividerColor.withValues(alpha: 0.1),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(LogFilter filter, String label) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedFilter = filter);
        HapticFeedback.selectionClick();
      },
      checkmarkColor: isSelected ? Colors.white : null,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.w600 : null,
      ),
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, MMMM d, y').format(date);
  }

  Widget _buildIconForAction(String action) {
    IconData icon;
    Color? color;

    if (action.contains('Chat Created')) {
      icon = Icons.chat_bubble_outline;
      color = Colors.blue;
    } else if (action.contains('Chat Deleted') ||
        action.contains('History Cleared')) {
      icon = Icons.delete_outline;
      color = Colors.red;
    } else if (action.contains('Prompt')) {
      if (action.contains('Deleted')) {
        icon = Icons.delete_outline;
        color = Colors.deepOrange;
      } else {
        icon = Icons.edit_note;
        color = Colors.purple;
      }
    } else if (action.contains('Settings')) {
      icon = Icons.settings;
      color = Colors.grey;
    } else if (action.contains('Export')) {
      icon = Icons.download;
      color = Colors.green;
    } else if (action.contains('Import')) {
      icon = Icons.upload;
      color = Colors.teal;
    } else if (action.contains('Logs Cleared')) {
      icon = Icons.cleaning_services;
      color = Colors.amber;
    } else if (action.contains('Pinned')) {
      icon = Icons.push_pin_outlined;
      color = Colors.orange;
    } else {
      icon = Icons.info_outline;
      color = Colors.blueGrey;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _confirmClearLogs(BuildContext context, StorageService storage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Audit Trail?'),
        content: const Text(
          'This will permanently delete your entire activity history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await storage.clearActivityLogs();
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
