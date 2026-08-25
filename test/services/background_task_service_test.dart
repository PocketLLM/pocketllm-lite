import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pocketllm_lite/core/constants/app_constants.dart';
import 'package:pocketllm_lite/core/domain/background_task.dart';
import 'package:pocketllm_lite/services/background_task_service.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pocketllm_tasks_');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('persists measured task progress and completion', () async {
    final service = BackgroundTaskService();
    await service.init();
    final task = await service.create(
      type: BackgroundTaskType.modelDownload,
      title: 'Download fixture',
    );
    await service.start(task.id, phase: 'Downloading');
    await service.report(
      task.id,
      phase: 'Downloading',
      completedUnits: 25,
      totalUnits: 100,
      progress: 0.25,
    );
    await service.complete(task.id, destination: '/models/fixture');

    final saved = service.find(task.id)!;
    expect(saved.state, BackgroundTaskState.completed);
    expect(saved.progress, 1);
    expect(saved.completedUnits, 25);
    expect(saved.destination, '/models/fixture');
  });

  test('normalizes a running task to interrupted after restart', () async {
    final first = BackgroundTaskService();
    await first.init();
    final task = await first.create(
      type: BackgroundTaskType.documentIndex,
      title: 'Index fixture',
    );
    await first.start(task.id, phase: 'Creating embeddings');
    await first.dispose();
    await Hive.box<Map>(AppConstants.backgroundTasksBoxName).close();

    final restarted = BackgroundTaskService();
    await restarted.init();
    final recovered = restarted.find(task.id)!;
    expect(recovered.state, BackgroundTaskState.interrupted);
    expect(recovered.failure?.action, contains('Retry'));
  });
}
