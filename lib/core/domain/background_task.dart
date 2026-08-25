enum BackgroundTaskType { documentIndex, modelDownload, transcription }

enum BackgroundTaskState {
  queued,
  running,
  paused,
  completed,
  failed,
  cancelled,
  interrupted,
}

class TaskFailure {
  final String message;
  final String action;
  final String? details;

  const TaskFailure({
    required this.message,
    required this.action,
    this.details,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'action': action,
        if (details != null) 'details': details,
      };

  factory TaskFailure.fromJson(Map<String, dynamic> json) => TaskFailure(
        message: json['message'] as String? ?? 'The task failed.',
        action: json['action'] as String? ?? 'Retry the task.',
        details: json['details'] as String?,
      );
}

class BackgroundTask {
  final String id;
  final BackgroundTaskType type;
  final String title;
  final BackgroundTaskState state;
  final String phase;
  final double? progress;
  final int completedUnits;
  final int? totalUnits;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int retryCount;
  final String? source;
  final String? destination;
  final Map<String, dynamic> metadata;
  final TaskFailure? failure;

  const BackgroundTask({
    required this.id,
    required this.type,
    required this.title,
    required this.state,
    required this.phase,
    required this.createdAt,
    required this.updatedAt,
    this.progress,
    this.completedUnits = 0,
    this.totalUnits,
    this.retryCount = 0,
    this.source,
    this.destination,
    this.metadata = const {},
    this.failure,
  });

  bool get isTerminal => switch (state) {
        BackgroundTaskState.completed ||
        BackgroundTaskState.failed ||
        BackgroundTaskState.cancelled =>
          true,
        _ => false,
      };

  BackgroundTask copyWith({
    BackgroundTaskState? state,
    String? phase,
    double? progress,
    bool clearProgress = false,
    int? completedUnits,
    int? totalUnits,
    DateTime? updatedAt,
    int? retryCount,
    String? destination,
    Map<String, dynamic>? metadata,
    TaskFailure? failure,
    bool clearFailure = false,
  }) =>
      BackgroundTask(
        id: id,
        type: type,
        title: title,
        state: state ?? this.state,
        phase: phase ?? this.phase,
        progress: clearProgress ? null : progress ?? this.progress,
        completedUnits: completedUnits ?? this.completedUnits,
        totalUnits: totalUnits ?? this.totalUnits,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        retryCount: retryCount ?? this.retryCount,
        source: source,
        destination: destination ?? this.destination,
        metadata: metadata ?? this.metadata,
        failure: clearFailure ? null : failure ?? this.failure,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'id': id,
        'type': type.name,
        'title': title,
        'state': state.name,
        'phase': phase,
        if (progress != null) 'progress': progress,
        'completedUnits': completedUnits,
        if (totalUnits != null) 'totalUnits': totalUnits,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'retryCount': retryCount,
        if (source != null) 'source': source,
        if (destination != null) 'destination': destination,
        'metadata': metadata,
        if (failure != null) 'failure': failure!.toJson(),
      };

  factory BackgroundTask.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((value) => value.name == name).firstOrNull ?? fallback;
    final failure = json['failure'];
    return BackgroundTask(
      id: json['id'] as String,
      type: enumValue(
        BackgroundTaskType.values,
        json['type'] as String?,
        BackgroundTaskType.documentIndex,
      ),
      title: json['title'] as String? ?? 'Background task',
      state: enumValue(
        BackgroundTaskState.values,
        json['state'] as String?,
        BackgroundTaskState.interrupted,
      ),
      phase: json['phase'] as String? ?? 'Waiting',
      progress: (json['progress'] as num?)?.toDouble(),
      completedUnits: (json['completedUnits'] as num?)?.toInt() ?? 0,
      totalUnits: (json['totalUnits'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      source: json['source'] as String?,
      destination: json['destination'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      failure: failure is Map
          ? TaskFailure.fromJson(Map<String, dynamic>.from(failure))
          : null,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
