import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import '../../../../core/providers.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../services/storage_service.dart';
import '../../../../core/theme/app_motion.dart';
import '../widgets/activity_chart.dart';

final usageStatisticsProvider = FutureProvider.autoDispose<UsageStatistics>((
  ref,
) async {
  final storage = ref.watch(storageServiceProvider);
  return storage.getUsageStatistics();
});

class UsageStatisticsScreen extends ConsumerStatefulWidget {
  const UsageStatisticsScreen({super.key});

  @override
  ConsumerState<UsageStatisticsScreen> createState() =>
      _UsageStatisticsScreenState();
}

class _UsageStatisticsScreenState extends ConsumerState<UsageStatisticsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(usageStatisticsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: M3AppBar(
        title: 'Usage Statistics',
        onBack: () => Navigator.pop(context),
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
              _AnimatedItem(
                controller: _animController,
                index: 0,
                child: _buildSummaryCards(context, stats),
              ),
              const SizedBox(height: 24),
              _AnimatedItem(
                controller: _animController,
                index: 1,
                child: _buildTrendSection(context, stats),
              ),
              const SizedBox(height: 24),
              _AnimatedItem(
                controller: _animController,
                index: 2,
                child: _buildActivitySection(context, stats),
              ),
              const SizedBox(height: 24),
              _AnimatedItem(
                controller: _animController,
                index: 3,
                child: _buildModelUsageSection(context, stats),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Error loading stats: $err',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, UsageStatistics stats) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            _buildStatCard(
              context,
              'Total Chats',
              stats.totalChats.toString(),
              Icons.chat_bubble_outline_rounded,
              theme.colorScheme.primary,
              theme.colorScheme.primaryContainer,
              Shapes.soft_burst,
            ),
            _buildStatCard(
              context,
              'Messages',
              stats.totalMessages.toString(),
              Icons.message_outlined,
              theme.colorScheme.secondary,
              theme.colorScheme.secondaryContainer,
              Shapes.circle,
            ),
            _buildStatCard(
              context,
              'Tokens',
              NumberFormat.compact().format(stats.totalTokensUsed),
              Icons.token_outlined,
              theme.colorScheme.tertiary,
              theme.colorScheme.tertiaryContainer,
              Shapes.gem,
            ),
            _buildStatCard(
              context,
              'This Week',
              stats.chatsLast7Days.toString(),
              Icons.calendar_today_rounded,
              theme.colorScheme.error,
              theme.colorScheme.errorContainer,
              Shapes.flower,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrendSection(BuildContext context, UsageStatistics stats) {
    return ActivityChart(activity: stats.dailyActivity);
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color contentColor,
    Color containerColor,
    Shapes shape,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: contentColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          M3Container(
            shape,
            width: 40,
            height: 40,
            color: containerColor,
            child: Center(child: Icon(icon, color: contentColor, size: 20)),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: contentColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
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
          'Last Activity',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.access_time_filled_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Active Session',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastActive,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
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
          'Model Preference',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: sortedModels.isEmpty
              ? const Center(child: Text('No model usage data yet.'))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedModels.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final entry = sortedModels[index];
                    final count = entry.value;
                    final total = stats.totalChats > 0 ? stats.totalChats : 1;
                    final percentage = count / total;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${(percentage * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              height: 12,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: percentage,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AnimatedItem extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final Widget child;

  const _AnimatedItem({
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final start = index * 0.1;
        final end = start + 0.4;

        final fade = CurvedAnimation(
          parent: controller,
          curve: Interval(start, end, curve: AppMotion.curveEnter),
        );

        final slide =
            Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: controller,
                curve: Interval(start, end, curve: AppMotion.curveOvershoot),
              ),
            );

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child!),
        );
      },
      child: child,
    );
  }
}
