import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers.dart';
import '../../../chat/domain/models/ollama_model_details.dart';

class ModelDetailsDialog extends ConsumerStatefulWidget {
  final String modelName;

  const ModelDetailsDialog({super.key, required this.modelName});

  @override
  ConsumerState<ModelDetailsDialog> createState() => _ModelDetailsDialogState();
}

class _ModelDetailsDialogState extends ConsumerState<ModelDetailsDialog> {
  late Future<OllamaModelDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  void _loadDetails() {
    _detailsFuture = ref
        .read(ollamaServiceProvider)
        .showModelInfo(widget.modelName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.modelName),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: FutureBuilder<OllamaModelDetails>(
          future: _detailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _loadDetails();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('No details available'));
            }

            final details = snapshot.data!;
            return DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'General'),
                      Tab(text: 'Modelfile'),
                      Tab(text: 'Template'),
                      Tab(text: 'License'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildGeneralTab(details),
                        _buildScrollableText(details.modelfile),
                        _buildScrollableText(details.template),
                        _buildScrollableText(details.license),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildGeneralTab(OllamaModelDetails details) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Format', details.details.format),
          _buildInfoRow('Family', details.details.family),
          _buildInfoRow('Parameter Size', details.details.parameterSize),
          _buildInfoRow('Quantization', details.details.quantizationLevel),
          if (details.details.families.isNotEmpty)
             _buildInfoRow('Families', details.details.families.join(', ')),
          const SizedBox(height: 16),
           if (details.parameters.isNotEmpty) ...[
             const Text(
               'Parameters',
               style: TextStyle(fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 8),
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Text(
                 details.parameters,
                 style: const TextStyle(
                   fontFamily: 'monospace',
                   fontSize: 12,
                 ),
               ),
             ),
           ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableText(String text) {
    if (text.isEmpty) {
      return const Center(
        child: Text(
          'None',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
