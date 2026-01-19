import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';

class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
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
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear Logs',
            onPressed: () => _confirmClearLogs(context, storage),
          ),
        ],
      ),
      body: ValueListenableBuilder<Box>(
        valueListenable: storage.activityLogBoxListenable,
        builder: (context, box, _) {
          final logs = storage.getActivityLogs();

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No activity logs yet',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final timestamp = DateTime.parse(log['timestamp']);
              final formattedTime = DateFormat('MMM d, y HH:mm:ss').format(timestamp);
              final action = log['action'] ?? 'Unknown';
              final details = log['details'] ?? '';

              return ListTile(
                leading: _buildIconForAction(action),
                title: Text(
                  action,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(details),
                    const SizedBox(height: 4),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildIconForAction(String action) {
    IconData icon;
    Color? color;

    switch (action) {
      case 'Chat Created':
        icon = Icons.chat_bubble_outline;
        color = Colors.blue;
        break;
      case 'Chat Deleted':
        icon = Icons.delete_outline;
        color = Colors.red;
        break;
      case 'History Cleared':
        icon = Icons.delete_forever;
        color = Colors.red;
        break;
      case 'System Prompt Created':
      case 'System Prompt Updated':
        icon = Icons.edit_note;
        color = Colors.purple;
        break;
      case 'System Prompt Deleted':
        icon = Icons.note_remove;
        color = Colors.deepOrange;
        break;
      case 'Settings Changed':
        icon = Icons.settings;
        color = Colors.grey;
        break;
      case 'Data Export':
        icon = Icons.download;
        color = Colors.green;
        break;
      case 'Data Import':
        icon = Icons.upload;
        color = Colors.teal;
        break;
      case 'Logs Cleared':
        icon = Icons.cleaning_services;
        color = Colors.amber;
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.blueGrey;
    }

    return CircleAvatar(
      backgroundColor: color?.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  void _confirmClearLogs(BuildContext context, StorageService storage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Activity Logs?'),
        content: const Text(
          'This will permanently delete your activity history. This action cannot be undone.',
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
