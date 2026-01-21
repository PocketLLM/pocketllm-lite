import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers.dart';
import '../../../../services/storage_service.dart';
import '../widgets/activity_chart.dart';

final usageStatisticsProvider = FutureProvider.autoDispose<UsageStatistics>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  return storage.getUsageStatistics();
});

class UsageStatisticsScreen extends ConsumerWidget {
  const UsageStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(usageStatisticsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(usageStatisticsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(context, stats),
              const SizedBox(height: 24),
              _buildTrendSection(context, stats),
              const SizedBox(height: 24),
              _buildActivitySection(context, stats),
              const SizedBox(height: 24),
              _buildModelUsageSection(context, stats),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error loading stats: $err', style: TextStyle(color: theme.colorScheme.error)),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, UsageStatistics stats) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          context,
          'Total Chats',
          stats.totalChats.toString(),
          Icons.chat_bubble_outline,
          Colors.blue,
        ),
        _buildStatCard(
          context,
          'Total Messages',
          stats.totalMessages.toString(),
          Icons.message_outlined,
          Colors.green,
        ),
        _buildStatCard(
          context,
          'Tokens Used',
          NumberFormat.compact().format(stats.totalTokensUsed),
          Icons.token,
          Colors.orange,
        ),
        _buildStatCard(
          context,
          'Chats (7d)',
          stats.chatsLast7Days.toString(),
          Icons.calendar_today,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildTrendSection(BuildContext context, UsageStatistics stats) {
    return ActivityChart(activity: stats.dailyActivity);
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(BuildContext context, UsageStatistics stats) {
    final theme = Theme.of(context);
    final lastActive = stats.lastActiveDate != null
        ? DateFormat.yMMMd().add_jm().format(stats.lastActiveDate!)
        : 'Never';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Active',
                    style: theme.textTheme.labelMedium,
                  ),
                  Text(
                    lastActive,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModelUsageSection(BuildContext context, UsageStatistics stats) {
    final theme = Theme.of(context);
    final sortedModels = stats.modelUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Model Usage',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: sortedModels.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: Text('No model usage data yet.')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedModels.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final entry = sortedModels[index];
                    final percentage = stats.totalChats > 0
                        ? (entry.value / stats.totalChats * 100).toStringAsFixed(1)
                        : '0.0';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          entry.key.isNotEmpty ? entry.key[0].toUpperCase() : '?',
                          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                        ),
                      ),
                      title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: LinearProgressIndicator(
                        value: stats.totalChats > 0 ? entry.value / stats.totalChats : 0,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${entry.value} chats', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('$percentage%', style: theme.textTheme.labelSmall),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
