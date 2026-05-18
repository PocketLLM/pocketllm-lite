import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/m3_app_bar.dart';
import '../domain/error_entry.dart';

class ErrorLogScreen extends ConsumerStatefulWidget {
  const ErrorLogScreen({super.key});

  @override
  ConsumerState<ErrorLogScreen> createState() => _ErrorLogScreenState();
}

class _ErrorLogScreenState extends ConsumerState<ErrorLogScreen> {
  ErrorSeverity? _severityFilter;
  ErrorCategory? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final errorLog = ref.watch(errorLogServiceProvider);
    final listenable = errorLog.listenable;

    return Scaffold(
      appBar: M3AppBar(
        title: 'Error Log',
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export log',
            onPressed: _exportLog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear log',
            onPressed: _confirmClear,
          ),
        ],
      ),
      body: listenable == null
          ? const _ErrorLogList()
          : ValueListenableBuilder(
              valueListenable: listenable,
              builder: (context, _, __) => _ErrorLogList(
                severityFilter: _severityFilter,
                categoryFilter: _categoryFilter,
                onSeverityChanged: (value) {
                  setState(() => _severityFilter = value);
                },
                onCategoryChanged: (value) {
                  setState(() => _categoryFilter = value);
                },
              ),
            ),
    );
  }

  Future<void> _exportLog() async {
    final text = await ref.read(errorLogServiceProvider).exportLog();
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'PocketLLM Lite Error Log'),
    );
  }

  Future<void> _confirmClear() async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.delete_outline_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Clear Error Log?'),
        content: const Text('This removes all saved diagnostic entries.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(errorLogServiceProvider).clearEntries();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error log cleared')));
    }
  }
}

class _ErrorLogList extends ConsumerWidget {
  final ErrorSeverity? severityFilter;
  final ErrorCategory? categoryFilter;
  final ValueChanged<ErrorSeverity?>? onSeverityChanged;
  final ValueChanged<ErrorCategory?>? onCategoryChanged;

  const _ErrorLogList({
    this.severityFilter,
    this.categoryFilter,
    this.onSeverityChanged,
    this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return FutureBuilder<List<ErrorEntry>>(
      future: ref
          .read(errorLogServiceProvider)
          .getEntries(severity: severityFilter, category: categoryFilter),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: Text(severityFilter?.label ?? 'All Severities'),
                  selected: severityFilter != null,
                  onSelected: (_) => _showSeverityMenu(context),
                ),
                FilterChip(
                  label: Text(categoryFilter?.name ?? 'All Categories'),
                  selected: categoryFilter != null,
                  onSelected: (_) => _showCategoryMenu(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const LinearProgressIndicator()
            else if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 96),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text('No errors logged', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Diagnostics will appear here if something needs attention.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...entries.map((entry) => _ErrorEntryTile(entry: entry)),
          ],
        );
      },
    );
  }

  Future<void> _showSeverityMenu(BuildContext context) async {
    final selected = await showModalBottomSheet<ErrorSeverity?>(
      context: context,
      builder: (context) => _FilterSheet<ErrorSeverity>(
        title: 'Severity',
        values: ErrorSeverity.values,
        labelFor: (value) => value.label,
      ),
    );
    onSeverityChanged?.call(selected);
  }

  Future<void> _showCategoryMenu(BuildContext context) async {
    final selected = await showModalBottomSheet<ErrorCategory?>(
      context: context,
      builder: (context) => _FilterSheet<ErrorCategory>(
        title: 'Category',
        values: ErrorCategory.values,
        labelFor: (value) => value.name,
      ),
    );
    onCategoryChanged?.call(selected);
  }
}

class _FilterSheet<T> extends StatelessWidget {
  final String title;
  final List<T> values;
  final String Function(T value) labelFor;

  const _FilterSheet({
    required this.title,
    required this.values,
    required this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            title: const Text('All'),
            onTap: () => Navigator.pop(context, null),
          ),
          ...values.map(
            (value) => ListTile(
              title: Text(labelFor(value)),
              onTap: () => Navigator.pop(context, value),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ErrorEntryTile extends StatelessWidget {
  final ErrorEntry entry;

  const _ErrorEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _severityColor(theme.colorScheme, entry.severity);

    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(_severityIcon(entry.severity), color: color),
        title: Text(
          entry.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${entry.timestamp.toLocal()} - ${entry.category.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _showDetails(context),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          _severityIcon(entry.severity),
          color: _severityColor(theme.colorScheme, entry.severity),
        ),
        title: Text(entry.message),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(label: 'Severity', value: entry.severity.label),
              _DetailRow(label: 'Category', value: entry.category.name),
              _DetailRow(
                label: 'Time',
                value: entry.timestamp.toLocal().toString(),
              ),
              if (entry.details?.isNotEmpty ?? false)
                _DetailRow(label: 'Details', value: entry.details!),
              if (entry.suggestedFix?.isNotEmpty ?? false)
                _DetailRow(label: 'Suggested Fix', value: entry.suggestedFix!),
              if (entry.stackTrace?.isNotEmpty ?? false)
                _DetailRow(label: 'Stack Trace', value: entry.stackTrace!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _severityColor(ColorScheme colorScheme, ErrorSeverity severity) {
    return switch (severity) {
      ErrorSeverity.info => colorScheme.primary,
      ErrorSeverity.warning => colorScheme.tertiary,
      ErrorSeverity.error => colorScheme.error,
      ErrorSeverity.critical => colorScheme.error,
    };
  }

  IconData _severityIcon(ErrorSeverity severity) {
    return switch (severity) {
      ErrorSeverity.info => Icons.info_outline_rounded,
      ErrorSeverity.warning => Icons.warning_amber_rounded,
      ErrorSeverity.error => Icons.error_outline_rounded,
      ErrorSeverity.critical => Icons.report_gmailerrorred_rounded,
    };
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
