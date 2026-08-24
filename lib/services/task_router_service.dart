import 'device_spec_service.dart';
import 'model_recommendation_engine.dart';

enum UserTaskCategory {
  fastChat,
  bestReasoning,
  coding,
  documentAnalysis,
  creativeWriting,
  vision,
  lowBattery,
  longContext,
}

extension UserTaskCategoryExtension on UserTaskCategory {
  String get displayName {
    switch (this) {
      case UserTaskCategory.fastChat:
        return 'Fast Chat';
      case UserTaskCategory.bestReasoning:
        return 'Best Reasoning';
      case UserTaskCategory.coding:
        return 'Coding & Technical';
      case UserTaskCategory.documentAnalysis:
        return 'Document Analysis';
      case UserTaskCategory.creativeWriting:
        return 'Creative Writing';
      case UserTaskCategory.vision:
        return 'Vision & OCR';
      case UserTaskCategory.lowBattery:
        return 'Low Battery';
      case UserTaskCategory.longContext:
        return 'Long Context';
    }
  }

  String get description {
    switch (this) {
      case UserTaskCategory.fastChat:
        return 'Prioritizes maximum response speed & low latency';
      case UserTaskCategory.bestReasoning:
        return 'Selects models with deep logic & thinking capabilities';
      case UserTaskCategory.coding:
        return 'Requires code instruction models with >= 8K context';
      case UserTaskCategory.documentAnalysis:
        return 'Optimized for large document RAG & context retention';
      case UserTaskCategory.creativeWriting:
        return 'Higher creativity & storytelling fluency';
      case UserTaskCategory.vision:
        return 'Requires multimodal image understanding';
      case UserTaskCategory.lowBattery:
        return 'Uses lightweight <= 2B models to save energy';
      case UserTaskCategory.longContext:
        return 'Requires 16K-32K window support';
    }
  }
}

class CandidateModelSpec {
  final String modelId;
  final double parameterCountB;
  final String quantization;
  final int contextLength;
  final bool supportsVision;
  final bool supportsTools;
  final bool supportsReasoning;
  final bool isCodeModel;

  const CandidateModelSpec({
    required this.modelId,
    required this.parameterCountB,
    required this.quantization,
    required this.contextLength,
    this.supportsVision = false,
    this.supportsTools = false,
    this.supportsReasoning = false,
    this.isCodeModel = false,
  });
}

class TaskRouterResult {
  final String selectedModelId;
  final UserTaskCategory task;
  final bool isManualOverride;
  final String selectionReason;

  const TaskRouterResult({
    required this.selectedModelId,
    required this.task,
    required this.isManualOverride,
    required this.selectionReason,
  });
}

class TaskRouterService {
  static final TaskRouterService _instance = TaskRouterService._internal();
  factory TaskRouterService() => _instance;
  TaskRouterService._internal();

  TaskRouterResult routeTask({
    required UserTaskCategory task,
    required List<CandidateModelSpec> availableModels,
    required DeviceHardwareProfile profile,
    String? manualOverrideModelId,
  }) {
    if (manualOverrideModelId != null && manualOverrideModelId.isNotEmpty) {
      final exists =
          availableModels.any((m) => m.modelId == manualOverrideModelId);
      if (exists) {
        return TaskRouterResult(
          selectedModelId: manualOverrideModelId,
          task: task,
          isManualOverride: true,
          selectionReason:
              'User manual override active ($manualOverrideModelId)',
        );
      }
    }

    if (availableModels.isEmpty) {
      return TaskRouterResult(
        selectedModelId: 'qwen3:1.7b',
        task: task,
        isManualOverride: false,
        selectionReason: 'Default fallback model selected',
      );
    }

    CandidateModelSpec bestCandidate = availableModels.first;
    double bestScore = -1.0;
    String reason = 'Matched task criteria';

    for (final candidate in availableModels) {
      final rec = ModelRecommendationEngine().evaluateModel(
        profile: profile,
        parameterCountB: candidate.parameterCountB,
        quantization: candidate.quantization,
        contextLength: candidate.contextLength,
        supportsVision: candidate.supportsVision,
        supportsTools: candidate.supportsTools,
        supportsReasoning: candidate.supportsReasoning,
        targetTask: task.name,
      );

      // Skip models that will crash
      if (rec.badge == RecommendationBadge.tooLarge) continue;

      double taskScore = rec.compatibilityScore;

      switch (task) {
        case UserTaskCategory.fastChat:
          if (candidate.parameterCountB <= 2.0) taskScore += 0.35;
          break;

        case UserTaskCategory.bestReasoning:
          if (candidate.supportsReasoning) taskScore += 0.40;
          if (candidate.parameterCountB >= 7.0) taskScore += 0.20;
          break;

        case UserTaskCategory.coding:
          if (candidate.isCodeModel) taskScore += 0.40;
          if (candidate.contextLength >= 8192) taskScore += 0.20;
          break;

        case UserTaskCategory.documentAnalysis:
        case UserTaskCategory.longContext:
          if (candidate.contextLength >= 16384) taskScore += 0.40;
          break;

        case UserTaskCategory.vision:
          if (candidate.supportsVision) {
            taskScore += 0.50;
          } else {
            taskScore -= 0.80; // Disfavor non-vision models for vision task
          }
          break;

        case UserTaskCategory.lowBattery:
          if (candidate.parameterCountB <= 2.0) taskScore += 0.45;
          break;

        case UserTaskCategory.creativeWriting:
          if (candidate.parameterCountB >= 7.0) taskScore += 0.30;
          break;
      }

      if (taskScore > bestScore) {
        bestScore = taskScore;
        bestCandidate = candidate;
        reason =
            'Selected ${candidate.modelId} (Score: ${taskScore.toStringAsFixed(2)}) for ${task.displayName}';
      }
    }

    return TaskRouterResult(
      selectedModelId: bestCandidate.modelId,
      task: task,
      isManualOverride: false,
      selectionReason: reason,
    );
  }
}
