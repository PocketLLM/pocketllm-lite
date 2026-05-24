import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_m3shapes/flutter_m3shapes.dart';
import '../../../../core/providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../core/widgets/m3_empty_state.dart';
import '../../../../services/inference_service.dart';

class BenchmarkRun {
  final String id;
  final String modelName;
  final DateTime timestamp;
  final int timeToFirstTokenMs;
  final double tokensPerSecond;
  final int totalTokens;
  final int totalTimeMs;
  final String promptType;

  BenchmarkRun({
    required this.id,
    required this.modelName,
    required this.timestamp,
    required this.timeToFirstTokenMs,
    required this.tokensPerSecond,
    required this.totalTokens,
    required this.totalTimeMs,
    required this.promptType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'modelName': modelName,
        'timestamp': timestamp.toIso8601String(),
        'timeToFirstTokenMs': timeToFirstTokenMs,
        'tokensPerSecond': tokensPerSecond,
        'totalTokens': totalTokens,
        'totalTimeMs': totalTimeMs,
        'promptType': promptType,
      };

  factory BenchmarkRun.fromJson(Map<String, dynamic> json) => BenchmarkRun(
        id: json['id'] as String,
        modelName: json['modelName'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        timeToFirstTokenMs: (json['timeToFirstTokenMs'] as num).toInt(),
        tokensPerSecond: (json['tokensPerSecond'] as num).toDouble(),
        totalTokens: (json['totalTokens'] as num).toInt(),
        totalTimeMs: (json['totalTimeMs'] as num).toInt(),
        promptType: json['promptType'] as String? ?? 'Quick Test',
      );
}

class BenchmarkState {
  final bool isRunning;
  final String status;
  final int liveTokens;
  final int liveTimeMs;
  final double liveTokensPerSecond;
  final List<BenchmarkRun> history;
  final BenchmarkRun? latestResult;

  BenchmarkState({
    this.isRunning = false,
    this.status = '',
    this.liveTokens = 0,
    this.liveTimeMs = 0,
    this.liveTokensPerSecond = 0.0,
    this.history = const [],
    this.latestResult,
  });

  BenchmarkState copyWith({
    bool? isRunning,
    String? status,
    int? liveTokens,
    int? liveTimeMs,
    double? liveTokensPerSecond,
    List<BenchmarkRun>? history,
    BenchmarkRun? latestResult,
  }) {
    return BenchmarkState(
      isRunning: isRunning ?? this.isRunning,
      status: status ?? this.status,
      liveTokens: liveTokens ?? this.liveTokens,
      liveTimeMs: liveTimeMs ?? this.liveTimeMs,
      liveTokensPerSecond: liveTokensPerSecond ?? this.liveTokensPerSecond,
      history: history ?? this.history,
      latestResult: latestResult ?? this.latestResult,
    );
  }
}

class BenchmarkNotifier extends Notifier<BenchmarkState> {
  @override
  BenchmarkState build() {
    _loadHistory();
    return BenchmarkState();
  }

  void _loadHistory() {
    final storage = ref.read(storageServiceProvider);
    final rawList = storage.getSetting('benchmark_history_runs') as List?;
    if (rawList != null) {
      try {
        final list = rawList
            .map(
              (e) => BenchmarkRun.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = state.copyWith(history: list);
      } catch (e) {
        debugPrint('Error loading benchmark history: $e');
      }
    }
  }

  Future<void> runBenchmark({
    required String prompt,
    required String promptType,
    required String modelId,
  }) async {
    if (state.isRunning) return;

    state = state.copyWith(
      isRunning: true,
      status: 'Connecting to model...',
      liveTokens: 0,
      liveTimeMs: 0,
      liveTokensPerSecond: 0.0,
      latestResult: null,
    );

    final stopwatch = Stopwatch()..start();
    final inferenceFactory = ref.read(inferenceServiceFactoryProvider);

    try {
      final service = await inferenceFactory.chooseForModel(modelId);
      state = state.copyWith(status: 'Running test prompt (measuring TTFT)...');

      final request = ChatRequest(
        modelId: modelId,
        messages: [ChatRequestMessage(role: 'user', content: prompt)],
        temperature: 0.2, // Low for consistency
        topP: 0.9,
        topK: 40,
        maxTokens: 128,
      );

      final stream = service.chatStream(request);

      int? timeToFirstTokenMs;
      final buffer = StringBuffer();
      DateTime? firstTokenTime;
      final startTime = DateTime.now();

      await for (final chunk in stream) {
        final now = DateTime.now();
        if (timeToFirstTokenMs == null) {
          firstTokenTime = now;
          timeToFirstTokenMs = now.difference(startTime).inMilliseconds;
          state = state.copyWith(status: 'Generating tokens...');
        }

        buffer.write(chunk.text);

        final elapsedSinceFirst =
            now.difference(firstTokenTime!).inMilliseconds;
        final words = RegExp(r'\S+').allMatches(buffer.toString()).length;
        final tokens = (words * 1.3).ceil();

        double tps = 0.0;
        if (elapsedSinceFirst > 0) {
          tps = (tokens / (elapsedSinceFirst / 1000.0));
        }

        state = state.copyWith(
          liveTokens: tokens,
          liveTimeMs: now.difference(startTime).inMilliseconds,
          liveTokensPerSecond: tps,
        );
      }

      stopwatch.stop();
      final totalTimeMs = stopwatch.elapsedMilliseconds;
      final words = RegExp(r'\S+').allMatches(buffer.toString()).length;
      final totalTokens = (words * 1.3).ceil();

      final genTimeMs = totalTimeMs - (timeToFirstTokenMs ?? 0);
      final finalTps =
          genTimeMs > 0 ? (totalTokens / (genTimeMs / 1000.0)) : 0.0;

      final result = BenchmarkRun(
        id: const Uuid().v4(),
        modelName: modelId,
        timestamp: DateTime.now(),
        timeToFirstTokenMs: timeToFirstTokenMs ?? totalTimeMs,
        tokensPerSecond: finalTps,
        totalTokens: totalTokens,
        totalTimeMs: totalTimeMs,
        promptType: promptType,
      );

      final updatedHistory = [result, ...state.history];

      final storage = ref.read(storageServiceProvider);
      await storage.saveSetting(
        'benchmark_history_runs',
        updatedHistory.map((e) => e.toJson()).toList(),
      );

      state = state.copyWith(
        isRunning: false,
        status: 'Completed!',
        history: updatedHistory,
        latestResult: result,
      );
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        status: 'Error: ${e.toString()}',
      );
    }
  }

  Future<void> clearHistory() async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveSetting('benchmark_history_runs', []);
    state = state.copyWith(history: [], latestResult: null);
  }
}

final benchmarkProvider = NotifierProvider<BenchmarkNotifier, BenchmarkState>(
  BenchmarkNotifier.new,
);

class BenchmarkScreen extends ConsumerStatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  ConsumerState<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends ConsumerState<BenchmarkScreen> {
  String _selectedPromptType = 'Quick Test';
  final TextEditingController _customPromptController = TextEditingController(
    text: 'Briefly write a three-word motto for an AI program.',
  );

  final Map<String, String> _prompts = {
    'Quick Test': 'Briefly explain the word "Pocket" in one short sentence.',
    'Complex Reasoning':
        'A box contains 3 red balls and 7 blue balls. If you draw 2 balls without replacement, what is the probability that both are red? Explain step-by-step.',
  };

  @override
  void dispose() {
    _customPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(benchmarkProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storage = ref.watch(storageServiceProvider);
    final currentModel =
        storage.getSetting(AppConstants.defaultModelKey) ?? 'llama3';

    // Calculate comparative metrics compared to average
    double averageTps = 0.0;
    if (state.history.isNotEmpty) {
      final total = state.history.fold<double>(
        0.0,
        (acc, run) => acc + run.tokensPerSecond,
      );
      averageTps = total / state.history.length;
    }

    return Scaffold(
      appBar: M3AppBar(
        title: 'Performance Benchmark',
        onBack: () => context.pop(),
        actions: [
          if (state.history.isNotEmpty && !state.isRunning)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear History',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Benchmark History?'),
                    content: const Text(
                      'This will delete all past local performance logs.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: colorScheme.onError,
                        ),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(benchmarkProvider.notifier).clearHistory();
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Model Info header card
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    M3Container(
                      Shapes.flower,
                      width: 48,
                      height: 48,
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      child: Center(
                        child: Icon(Icons.speed, color: colorScheme.primary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Model: $currentModel',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Performance tests will run against this model.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Prompt Selector card
            Text(
              'Benchmark Scenario',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Quick Test'),
                      subtitle: const Text(
                        'Short 1-sentence prompt (approx. 10 tokens)',
                      ),
                      value: 'Quick Test',
                      groupValue: _selectedPromptType,
                      onChanged: state.isRunning
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _selectedPromptType = val);
                              }
                            },
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      title: const Text('Complex Reasoning'),
                      subtitle: const Text(
                        'Step-by-step logic puzzle (approx. 30 tokens)',
                      ),
                      value: 'Complex Reasoning',
                      groupValue: _selectedPromptType,
                      onChanged: state.isRunning
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _selectedPromptType = val);
                              }
                            },
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      title: const Text('Custom Prompt'),
                      subtitle: const Text(
                        'Define your own prompt to measure performance',
                      ),
                      value: 'Custom Prompt',
                      groupValue: _selectedPromptType,
                      onChanged: state.isRunning
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _selectedPromptType = val);
                              }
                            },
                    ),
                    if (_selectedPromptType == 'Custom Prompt') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customPromptController,
                        enabled: !state.isRunning,
                        decoration: InputDecoration(
                          hintText: 'Enter custom test prompt...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Start Test Glowing Gradient Button
            if (!state.isRunning)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.tertiary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    final p = _selectedPromptType == 'Custom Prompt'
                        ? _customPromptController.text
                        : _prompts[_selectedPromptType]!;
                    ref.read(benchmarkProvider.notifier).runBenchmark(
                          prompt: p,
                          promptType: _selectedPromptType,
                          modelId: currentModel,
                        );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rocket_launch, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Start Performance Test',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Live Progress Panel
              Card(
                elevation: 4,
                color: colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            state.status,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLiveStatColumn(
                            theme,
                            '${state.liveTokensPerSecond.toStringAsFixed(1)} t/s',
                            'Live Speed',
                          ),
                          _buildLiveStatColumn(
                            theme,
                            '${state.liveTokens} tokens',
                            'Tokens Generated',
                          ),
                          _buildLiveStatColumn(
                            theme,
                            '${(state.liveTimeMs / 1000.0).toStringAsFixed(1)}s',
                            'Elapsed Time',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Latest Result Display
            if (state.latestResult != null) ...[
              Text(
                'Latest Results',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      theme,
                      colorScheme,
                      Icons.bolt,
                      '${state.latestResult!.tokensPerSecond.toStringAsFixed(1)} t/s',
                      'Generation Speed',
                      colorScheme.primaryContainer,
                      colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      theme,
                      colorScheme,
                      Icons.timer_outlined,
                      '${state.latestResult!.timeToFirstTokenMs} ms',
                      'Time to 1st Token',
                      state.latestResult!.timeToFirstTokenMs < 1000
                          ? colorScheme.secondaryContainer
                          : colorScheme.errorContainer,
                      state.latestResult!.timeToFirstTokenMs < 1000
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      theme,
                      colorScheme,
                      Icons.format_align_left,
                      '${state.latestResult!.totalTokens} tokens',
                      'Total Output Size',
                      colorScheme.surfaceContainerHighest,
                      colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      theme,
                      colorScheme,
                      Icons.hourglass_empty,
                      '${(state.latestResult!.totalTimeMs / 1000.0).toStringAsFixed(2)}s',
                      'Total Duration',
                      colorScheme.surfaceContainerHighest,
                      colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // History Panel
            Text(
              'Benchmark History',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            state.history.isEmpty
                ? const SizedBox(
                    height: 250,
                    child: M3EmptyState(
                      icon: Icons.history_toggle_off,
                      title: 'No past runs',
                      description:
                          'Test results will be listed here after you run a benchmark.',
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.history.length,
                    itemBuilder: (context, index) {
                      final run = state.history[index];
                      final isFaster =
                          averageTps > 0 && run.tokensPerSecond > averageTps;
                      final percentDiff = averageTps > 0
                          ? (((run.tokensPerSecond - averageTps) / averageTps) *
                                  100)
                              .abs()
                          : 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        color: colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          leading: M3Container(
                            Shapes.soft_burst,
                            width: 40,
                            height: 40,
                            color: isFaster
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: Icon(
                                Icons.offline_bolt_outlined,
                                color: isFaster
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          title: Text(
                            '${run.tokensPerSecond.toStringAsFixed(1)} t/s • ${run.timeToFirstTokenMs}ms TTFT',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Model: ${run.modelName} (${run.promptType})',
                              ),
                              Text(
                                'Date: ${run.timestamp.toLocal().toString().split('.')[0]}',
                              ),
                            ],
                          ),
                          trailing: averageTps > 0 && percentDiff > 1.0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isFaster
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${isFaster ? '+' : '-'}${percentDiff.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: isFaster
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatColumn(ThemeData theme, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    ThemeData theme,
    ColorScheme colorScheme,
    IconData icon,
    String value,
    String label,
    Color bg,
    Color fg,
  ) {
    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: fg.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
