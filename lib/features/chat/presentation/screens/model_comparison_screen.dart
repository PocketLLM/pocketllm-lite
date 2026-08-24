import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../../services/device_spec_service.dart';
import '../../../../services/model_recommendation_engine.dart';
import '../../../../core/widgets/m3_app_bar.dart';

class ComparisonResult {
  final String modelId;
  final String responseText;
  final int? timeToFirstTokenMs;
  final double? tokensPerSec;
  final int totalTimeMs;
  final double peakRamGB;
  final bool isWinner;

  const ComparisonResult({
    required this.modelId,
    required this.responseText,
    required this.timeToFirstTokenMs,
    required this.tokensPerSec,
    required this.totalTimeMs,
    required this.peakRamGB,
    this.isWinner = false,
  });
}

class ModelComparisonScreen extends ConsumerStatefulWidget {
  const ModelComparisonScreen({super.key});

  @override
  ConsumerState<ModelComparisonScreen> createState() =>
      _ModelComparisonScreenState();
}

class _ModelComparisonScreenState extends ConsumerState<ModelComparisonScreen> {
  final TextEditingController _promptController = TextEditingController(
    text: 'Explain quantum computing in simple terms for a 10 year old.',
  );

  String _modelA = 'qwen3:1.7b';
  String _modelB = 'llama3.2:3b';
  bool _isComparing = false;

  ComparisonResult? _resultA;
  ComparisonResult? _resultB;
  String? _selectedWinner;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _runComparison() async {
    if (_promptController.text.trim().isEmpty) return;

    setState(() {
      _isComparing = true;
      _resultA = null;
      _resultB = null;
      _selectedWinner = null;
    });

    final ollamaService = ref.read(ollamaServiceProvider);
    final stopwatch = Stopwatch()..start();

    // Model A execution
    int? ttftA;
    final bufferA = StringBuffer();
    var succeededA = false;
    try {
      final streamA = ollamaService.generateChatStream(
        _modelA,
        [
          {'role': 'user', 'content': _promptController.text.trim()}
        ],
      );

      bool firstTokenCaptured = false;
      await for (final chunk in streamA) {
        if (!firstTokenCaptured) {
          ttftA = stopwatch.elapsedMilliseconds;
          firstTokenCaptured = true;
        }
        bufferA.write(chunk);
      }
      succeededA = true;
    } catch (e) {
      bufferA.write('Model A inference failed: $e');
    }

    final totalMsA = stopwatch.elapsedMilliseconds;
    final tokenCountA = (bufferA.length / 4.0).ceil();
    final tpsA =
        succeededA && totalMsA > 0 ? tokenCountA / (totalMsA / 1000.0) : null;

    final profile = await DeviceSpecService().getHardwareProfile();
    final recA = ModelRecommendationEngine().evaluateModel(
      profile: profile,
      parameterCountB: _modelA.contains('3b') ? 3.0 : 1.7,
      quantization: 'Q4_K_M',
      contextLength: 8192,
    );

    _resultA = ComparisonResult(
      modelId: _modelA,
      responseText: bufferA.toString(),
      timeToFirstTokenMs: ttftA,
      tokensPerSec: tpsA,
      totalTimeMs: totalMsA,
      peakRamGB: recA.estimatedRamUsageGB,
    );

    // Model B execution
    stopwatch.reset();
    stopwatch.start();
    int? ttftB;
    final bufferB = StringBuffer();
    var succeededB = false;
    try {
      final streamB = ollamaService.generateChatStream(
        _modelB,
        [
          {'role': 'user', 'content': _promptController.text.trim()}
        ],
      );

      bool firstTokenCaptured = false;
      await for (final chunk in streamB) {
        if (!firstTokenCaptured) {
          ttftB = stopwatch.elapsedMilliseconds;
          firstTokenCaptured = true;
        }
        bufferB.write(chunk);
      }
      succeededB = true;
    } catch (e) {
      bufferB.write('Model B inference failed: $e');
    }

    final totalMsB = stopwatch.elapsedMilliseconds;
    final tokenCountB = (bufferB.length / 4.0).ceil();
    final tpsB =
        succeededB && totalMsB > 0 ? tokenCountB / (totalMsB / 1000.0) : null;

    final recB = ModelRecommendationEngine().evaluateModel(
      profile: profile,
      parameterCountB: _modelB.contains('3b') ? 3.0 : 1.7,
      quantization: 'Q4_K_M',
      contextLength: 8192,
    );

    _resultB = ComparisonResult(
      modelId: _modelB,
      responseText: bufferB.toString(),
      timeToFirstTokenMs: ttftB,
      tokensPerSec: tpsB,
      totalTimeMs: totalMsB,
      peakRamGB: recB.estimatedRamUsageGB,
    );

    setState(() {
      _isComparing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const M3AppBar(title: 'A/B Model Comparison'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Benchmark Prompt', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _promptController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'Enter test prompt for side-by-side comparison...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Model A'),
                            const SizedBox(height: 4),
                            TextField(
                              decoration: InputDecoration(hintText: _modelA),
                              onChanged: (val) => _modelA = val.trim(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Model B'),
                            const SizedBox(height: 4),
                            TextField(
                              decoration: InputDecoration(hintText: _modelB),
                              onChanged: (val) => _modelB = val.trim(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isComparing ? null : _runComparison,
                      icon: _isComparing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.compare_arrows_rounded),
                      label: Text(_isComparing
                          ? 'Running Side-by-Side Inference...'
                          : 'Compare Models'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_resultA != null && _resultB != null) ...[
            Text('Comparison Results', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildResultCard(_resultA!, theme, 'A')),
                const SizedBox(width: 8),
                Expanded(child: _buildResultCard(_resultB!, theme, 'B')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(ComparisonResult res, ThemeData theme, String label) {
    final isSelectedWinner = _selectedWinner == res.modelId;

    return Card(
      color: isSelectedWinner
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text('Model $label')),
                const Spacer(),
                if (isSelectedWinner)
                  Icon(
                    Icons.emoji_events_rounded,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
            Text(res.modelId,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Text(
              res.timeToFirstTokenMs == null
                  ? 'TTFT: unavailable'
                  : 'TTFT: ${res.timeToFirstTokenMs} ms',
            ),
            Text(
              res.tokensPerSec == null
                  ? 'Approx. output rate: unavailable'
                  : 'Approx. output rate: ${res.tokensPerSec!.toStringAsFixed(1)} tokens/sec',
            ),
            Text(
                'Total Time: ${(res.totalTimeMs / 1000.0).toStringAsFixed(1)}s'),
            Text('Estimated RAM need: ${res.peakRamGB.toStringAsFixed(1)} GB'),
            const Divider(),
            Text(
              res.responseText.isEmpty ? 'No response' : res.responseText,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                setState(() => _selectedWinner = res.modelId);
              },
              child:
                  Text(isSelectedWinner ? 'Winner Selected' : 'Select Winner'),
            ),
          ],
        ),
      ),
    );
  }
}
