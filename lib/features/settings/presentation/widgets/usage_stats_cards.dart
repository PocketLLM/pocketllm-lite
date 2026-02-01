import 'package:flutter/material.dart';
import '../../../../services/storage_service.dart';

class UsageStatsCards extends StatelessWidget {
  final UsageStatistics stats;

  const UsageStatsCards({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildCard(
            context,
            'Total Chats',
            stats.totalChats.toString(),
            Icons.chat_bubble_outline,
            Colors.blue,
          ),
          const SizedBox(width: 12),
          _buildCard(
            context,
            'Total Messages',
            stats.totalMessages.toString(),
            Icons.message_outlined,
            Colors.green,
          ),
          const SizedBox(width: 12),
          _buildCard(
            context,
            'Top Model',
            stats.mostUsedModel,
            Icons.psychology_outlined,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Container(
      width: 140, // Fixed width for consistency
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
