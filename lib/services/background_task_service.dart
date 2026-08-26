import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../core/domain/background_task.dart';

class BackgroundTaskService {
  BackgroundTaskService({Uuid uuid = const Uuid()}) : _uuid = uuid;

  final Uuid _uuid;
  Box<Map>? _box;
  StreamSubscription<BoxEvent>? _subscription;
  final ValueNotifier<List<BackgroundTask>> tasks = ValueNotifier(const []);

  Future<void> init() async {
    if (_box != null) return;
    _box = await Hive.openBox<Map>(AppConstants.backgroundTasksBoxName);
    await _recoverInterruptedTasks();
    _refresh();
    _subscription = _box!.watch().listen((_) => _refresh());
  }

  List<BackgroundTask> get snapshot => List.unmodifiable(tasks.value);

  BackgroundTask? find(String id) {
    final raw = _box?.get(id);
    return raw == null
        ? null
        : BackgroundTask.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<BackgroundTask> create({
    required BackgroundTaskType type,
    required String title,
    String phase = 'Waiting',
    String? source,
    String? destination,
    Map<String, dynamic> metadata = const {},
  }) async {
    await init();
    final now = DateTime.now().toUtc();
    final task = BackgroundTask(
      id: _uuid.v4(),
      type: type,
      title: title,
      state: BackgroundTaskState.queued,
      phase: phase,
      source: source,
      destination: destination,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );
    await _put(task);
    return task;
  }

  Future<BackgroundTask> start(String id, {required String phase}) => _change(
      id,
      (task) => task.copyWith(
            state: BackgroundTaskState.running,
            phase: phase,
            updatedAt: DateTime.now().toUtc(),
            clearFailure: true,
          ));

  Future<BackgroundTask> report(
    String id, {
    required String phase,
    int? completedUnits,
    int? totalUnits,
    double? progress,
    Map<String, dynamic>? metadata,
  }) =>
      _change(id, (task) {
        final normalized = progress?.clamp(0.0, 1.0);
        return task.copyWith(
          state: BackgroundTaskState.running,
          phase: phase,
          progress: normalized,
          completedUnits: completedUnits,
          totalUnits: totalUnits,
          metadata: metadata == null ? null : {...task.metadata, ...metadata},
          updatedAt: DateTime.now().toUtc(),
        );
      });

  Future<BackgroundTask> complete(
    String id, {
    String phase = 'Completed',
    String? destination,
    Map<String, dynamic>? metadata,
  }) =>
      _change(
          id,
          (task) => task.copyWith(
                state: BackgroundTaskState.completed,
                phase: phase,
                progress: 1,
                destination: destination,
                metadata:
                    metadata == null ? null : {...task.metadata, ...metadata},
                updatedAt: DateTime.now().toUtc(),
                clearFailure: true,
              ));

  Future<BackgroundTask> fail(
    String id, {
    required String message,
    required String action,
    String? details,
  }) =>
      _change(
          id,
          (task) => task.copyWith(
                state: BackgroundTaskState.failed,
                phase: 'Needs attention',
                failure: TaskFailure(
                  message: message,
                  action: action,
                  details: details,
                ),
                updatedAt: DateTime.now().toUtc(),
              ));

  Future<BackgroundTask> cancel(String id) => _change(id, (task) {
        if (task.isTerminal) return task;
        return task.copyWith(
          state: BackgroundTaskState.cancelled,
          phase: 'Cancelled',
          updatedAt: DateTime.now().toUtc(),
        );
      });

  Future<BackgroundTask> retry(String id) => _change(id, (task) {
        if (task.state != BackgroundTaskState.failed &&
            task.state != BackgroundTaskState.interrupted &&
            task.state != BackgroundTaskState.cancelled) {
          throw StateError('Only stopped tasks can be retried.');
        }
        return task.copyWith(
          state: BackgroundTaskState.queued,
          phase: 'Waiting to retry',
          retryCount: task.retryCount + 1,
          updatedAt: DateTime.now().toUtc(),
          clearFailure: true,
          clearProgress: true,
        );
      });

  Future<void> remove(String id) async {
    await init();
    final task = find(id);
    if (task != null &&
        !task.isTerminal &&
        task.state != BackgroundTaskState.interrupted) {
      throw StateError('Stop the task before removing it.');
    }
    await _box!.delete(id);
  }

  Future<void> _recoverInterruptedTasks() async {
    for (final key in _box!.keys.toList()) {
      final raw = _box!.get(key);
      if (raw == null) continue;
      final task = BackgroundTask.fromJson(Map<String, dynamic>.from(raw));
      if (task.state == BackgroundTaskState.running ||
          task.state == BackgroundTaskState.queued ||
          task.state == BackgroundTaskState.paused) {
        await _put(task.copyWith(
          state: BackgroundTaskState.interrupted,
          phase: 'Interrupted by app restart',
          failure: const TaskFailure(
            message: 'This task stopped when the app closed.',
            action: 'Retry to continue from safely saved work.',
          ),
          updatedAt: DateTime.now().toUtc(),
        ));
      }
    }
  }

  Future<BackgroundTask> _change(
    String id,
    BackgroundTask Function(BackgroundTask task) update,
  ) async {
    await init();
    final current = find(id);
    if (current == null) throw StateError('Task $id was not found.');
    final next = update(current);
    await _put(next);
    return next;
  }

  Future<void> _put(BackgroundTask task) => _box!.put(task.id, task.toJson());

  void _refresh() {
    final box = _box;
    if (box == null) return;
    final values = box.values
        .map((raw) => BackgroundTask.fromJson(Map<String, dynamic>.from(raw)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    tasks.value = List.unmodifiable(values);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    tasks.dispose();
  }
}
