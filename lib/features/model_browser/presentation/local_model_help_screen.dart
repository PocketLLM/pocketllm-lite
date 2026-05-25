import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/m3_app_bar.dart';

class LocalModelHelpScreen extends StatelessWidget {
  const LocalModelHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: M3AppBar(
        title: 'GGUF Local Model Help',
        subtitle: 'Understand offline local execution',
        onBack: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // GGUF Overview Card
          _buildInfoCard(
            context: context,
            icon: Icons.memory_rounded,
            title: 'What is GGUF & llama.cpp?',
            description:
                'GGUF (GPT-Generated Unified Format) is a file format designed for quick loading and high performance of large language models on consumer hardware. llama.cpp is a highly optimized execution engine written in C/C++ that runs these models locally on your device with accelerated GPU shaders (Metal/Vulkan) or high-performance CPU (Neon/AVX).',
          ),
          const SizedBox(height: 20),

          // stand-alone llama.cpp vs Ollama connection
          _buildSectionHeader(theme, 'Comparison: Standalone Local vs Ollama'),
          const SizedBox(height: 12),
          _buildComparisonTable(context),
          const SizedBox(height: 24),

          // Custom GGUF File Picker instructions
          _buildInfoCard(
            context: context,
            icon: Icons.file_open_rounded,
            title: 'How to Import Custom GGUF Models?',
            description:
                '1. Download any GGUF quantized model (e.g., from Hugging Face or LM Studio) in your web browser.\n'
                '2. Ensure the filename ends with `.gguf`.\n'
                '3. Open the Local GGUF Catalog settings in this app, tap "Browse Files" under GGUF Imports, and select your downloaded file.\n'
                '4. The file will be validated, copied securely to your app sandbox to protect scoped storage token permissions, and made ready to run offline!',
          ),
          const SizedBox(height: 20),

          // Optimizing parameters
          _buildInfoCard(
            context: context,
            icon: Icons.tune_rounded,
            title: 'Optimizer Settings & Hardware Tips',
            description:
                '• Context Window (n_ctx): Defines the maximum token history. For mobile, 2048 tokens is ideal. Higher values consume significantly more RAM.\n'
                '• Thread Counts: The engine automatically balances between physical high-efficiency cores and performance cores to optimize thermal throttling and battery drainage.\n'
                '• GPU Acceleration (Metal/Vulkan): Enabled natively during compilation. Metal performance shaders allow GGUF matrices to compute in parallel on the GPU.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTable(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            verticalInside: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.4),
            2: FlexColumnWidth(1.4),
          },
          children: [
            // Header Row
            TableRow(
              decoration: BoxDecoration(color: colorScheme.primaryContainer),
              children: [
                _buildTableCell('Feature', theme, isHeader: true, color: colorScheme.onPrimaryContainer),
                _buildTableCell('Standalone (llama.cpp)', theme, isHeader: true, color: colorScheme.onPrimaryContainer),
                _buildTableCell('Ollama Connection', theme, isHeader: true, color: colorScheme.onPrimaryContainer),
              ],
            ),
            // Rows
            TableRow(
              children: [
                _buildTableCell('Setup', theme),
                _buildTableCell('None. Standalone and fully self-contained.', theme),
                _buildTableCell('Requires Ollama running in Termux or on a PC.', theme),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell('Offline', theme),
                _buildTableCell('100% offline. Fits completely in sandboxed memory.', theme),
                _buildTableCell('Requires local socket connections to background daemon.', theme),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell('Imports', theme),
                _buildTableCell('Easy. Import any GGUF file directly with the file picker.', theme),
                _buildTableCell('Requires building a Modelfile and calling ollama compile.', theme),
              ],
            ),
            TableRow(
              children: [
                _buildTableCell('Speed', theme),
                _buildTableCell('Extremely fast direct C++ bindings with Metal GPU.', theme),
                _buildTableCell('Subject to local socket latency or HTTP overheads.', theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, ThemeData theme, {bool isHeader = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: color ?? theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
