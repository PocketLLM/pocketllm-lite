import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../features/error_log/domain/error_entry.dart';

export '../features/error_log/domain/error_entry.dart';

class ErrorLogService {
  final int maxEntries;
  final List<ErrorEntry>? _memoryEntries;
  Box? _box;

  ErrorLogService({this.maxEntries = 1000}) : _memoryEntries = null;

  ErrorLogService.inMemory({this.maxEntries = 1000}) : _memoryEntries = [];

  Future<void> init() async {
    if (_memoryEntries != null) return;
    _box = await Hive.openBox(AppConstants.errorLogBoxName);
    await _rotateIfNeeded();
  }

  ValueListenable<Box>? get listenable => _box?.listenable();

  Future<void> logInfo({
    required ErrorCategory category,
    required String message,
    String? details,
    String? suggestedFix,
    String? stackTrace,
  }) {
    return _add(
      ErrorEntry(
        severity: ErrorSeverity.info,
        category: category,
        message: message,
        details: details,
        suggestedFix: suggestedFix,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<void> logWarning({
    required ErrorCategory category,
    required String message,
    String? details,
    String? suggestedFix,
    String? stackTrace,
  }) {
    return _add(
      ErrorEntry(
        severity: ErrorSeverity.warning,
        category: category,
        message: message,
        details: details,
        suggestedFix: suggestedFix,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<void> logError({
    required ErrorCategory category,
    required String message,
    String? details,
    String? suggestedFix,
    String? stackTrace,
  }) {
    return _add(
      ErrorEntry(
        severity: ErrorSeverity.error,
        category: category,
        message: message,
        details: details,
        suggestedFix: suggestedFix,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<void> logCritical({
    required ErrorCategory category,
    required String message,
    String? details,
    String? suggestedFix,
    String? stackTrace,
  }) {
    return _add(
      ErrorEntry(
        severity: ErrorSeverity.critical,
        category: category,
        message: message,
        details: details,
        suggestedFix: suggestedFix,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<void> logFlutterError(FlutterErrorDetails details) {
    return logError(
      category: ErrorCategory.storage,
      message: details.exceptionAsString(),
      details: details.context?.toDescription(),
      stackTrace: details.stack?.toString(),
      suggestedFix:
          'Try the action again. If it repeats, export the error log for debugging.',
    );
  }

  Future<List<ErrorEntry>> getEntries({
    ErrorSeverity? severity,
    ErrorCategory? category,
  }) async {
    final entries = _readEntries();
    return entries.where((entry) {
      final severityMatches = severity == null || entry.severity == severity;
      final categoryMatches = category == null || entry.category == category;
      return severityMatches && categoryMatches;
    }).toList();
  }

  Future<void> clearEntries() async {
    if (_memoryEntries != null) {
      _memoryEntries.clear();
      return;
    }
    await _requireBox().clear();
  }

  Future<String> exportLog() async {
    final entries = await getEntries();
    if (entries.isEmpty) return 'PocketLLM Lite Error Log\nNo entries.';

    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    final buffer = StringBuffer('PocketLLM Lite Error Log\n');
    buffer.writeln('Entries: ${entries.length}');
    buffer.writeln();

    for (final entry in entries) {
      buffer.writeln(
        '[${formatter.format(entry.timestamp)}] '
        '${entry.severity.label} ${entry.category.name}',
      );
      buffer.writeln('Message: ${entry.message}');
      if (entry.details?.isNotEmpty ?? false) {
        buffer.writeln('Details: ${entry.details}');
      }
      if (entry.suggestedFix?.isNotEmpty ?? false) {
        buffer.writeln('Suggested fix: ${entry.suggestedFix}');
      }
      if (entry.stackTrace?.isNotEmpty ?? false) {
        buffer.writeln('Stack trace:\n${entry.stackTrace}');
      }
      buffer.writeln('---');
    }

    return buffer.toString();
  }

  Future<void> _add(ErrorEntry entry) async {
    if (_memoryEntries != null) {
      _memoryEntries.insert(0, entry);
      if (_memoryEntries.length > maxEntries) {
        _memoryEntries.removeRange(maxEntries, _memoryEntries.length);
      }
      return;
    }

    final box = _requireBox();
    await box.put(entry.id, entry.toJson());
    await _rotateIfNeeded();
  }

  List<ErrorEntry> _readEntries() {
    final values =
        _memoryEntries ??
        _requireBox().values
            .whereType<Map>()
            .map(
              (value) => ErrorEntry.fromJson(Map<String, dynamic>.from(value)),
            )
            .toList();

    final entries = List<ErrorEntry>.from(values)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  Future<void> _rotateIfNeeded() async {
    if (_memoryEntries != null) return;
    final box = _requireBox();
    if (box.length <= maxEntries) return;

    final entries = _readEntries();
    final toKeep = entries.take(maxEntries).map((entry) => entry.id).toSet();
    final keysToDelete = box.keys
        .where((key) => !toKeep.contains(key))
        .toList();
    await box.deleteAll(keysToDelete);
  }

  Box _requireBox() {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('ErrorLogService.init() must be called before use.');
    }
    return box;
  }
}
