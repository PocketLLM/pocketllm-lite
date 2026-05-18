import 'package:uuid/uuid.dart';

enum ErrorSeverity {
  info,
  warning,
  error,
  critical;

  String get label => name.toUpperCase();
}

enum ErrorCategory {
  connection,
  modelLoading,
  inference,
  storage,
  network,
  permission,
}

class ErrorEntry {
  final String id;
  final DateTime timestamp;
  final ErrorSeverity severity;
  final ErrorCategory category;
  final String message;
  final String? details;
  final String? suggestedFix;
  final String? stackTrace;

  ErrorEntry({
    String? id,
    DateTime? timestamp,
    required this.severity,
    required this.category,
    required this.message,
    this.details,
    this.suggestedFix,
    this.stackTrace,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'severity': severity.name,
      'category': category.name,
      'message': message,
      'details': details,
      'suggestedFix': suggestedFix,
      'stackTrace': stackTrace,
    };
  }

  factory ErrorEntry.fromJson(Map<String, dynamic> json) {
    return ErrorEntry(
      id: json['id']?.toString(),
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      severity: ErrorSeverity.values.firstWhere(
        (value) => value.name == json['severity'],
        orElse: () => ErrorSeverity.error,
      ),
      category: ErrorCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => ErrorCategory.storage,
      ),
      message: json['message']?.toString() ?? 'Unknown error',
      details: json['details']?.toString(),
      suggestedFix: json['suggestedFix']?.toString(),
      stackTrace: json['stackTrace']?.toString(),
    );
  }
}
