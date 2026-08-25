import 'dart:async';
import 'dart:math';

import '../features/chat/domain/models/chat_message.dart';
import '../core/constants/app_constants.dart';
import 'storage_service.dart';

enum MemoryType {
  personalFact,
  preference,
  project,
  people,
  goal,
  writingStyle,
  reusableInstruction,
}

class ExtractedMemoryCandidate {
  final String key;
  final MemoryType type;
  final String subject;
  final String fact;
  final double confidence;

  const ExtractedMemoryCandidate({
    required this.key,
    required this.type,
    required this.subject,
    required this.fact,
    required this.confidence,
  });
}

typedef StructuredMemoryExtractor = Future<List<ExtractedMemoryCandidate>>
    Function(List<ChatMessage> messages);

extension MemoryTypeExtension on MemoryType {
  String get displayName => switch (this) {
        MemoryType.personalFact => 'Personal Fact',
        MemoryType.preference => 'Preference',
        MemoryType.project => 'Project',
        MemoryType.people => 'Person / Contact',
        MemoryType.goal => 'Goal',
        MemoryType.writingStyle => 'Writing Style',
        MemoryType.reusableInstruction => 'Reusable Instruction',
      };
}

class UserMemoryEntry {
  final String id;
  final MemoryType type;
  final String subject;
  final String fact;
  final double confidence;
  final String? sourceMessageId;
  final bool sensitive;
  final bool pinned;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  final List<double>? embedding;
  final String? memoryKey;
  final DateTime? supersededAt;
  final String? supersededById;

  UserMemoryEntry({
    required this.id,
    required this.type,
    required this.subject,
    required this.fact,
    required this.confidence,
    this.sourceMessageId,
    this.sensitive = false,
    this.pinned = false,
    this.enabled = true,
    required this.createdAt,
    DateTime? updatedAt,
    this.lastUsedAt,
    this.embedding,
    this.memoryKey,
    this.supersededAt,
    this.supersededById,
  }) : updatedAt = updatedAt ?? createdAt;

  UserMemoryEntry copyWith({
    String? fact,
    double? confidence,
    bool? pinned,
    bool? enabled,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    List<double>? embedding,
    String? memoryKey,
    DateTime? supersededAt,
    String? supersededById,
  }) =>
      UserMemoryEntry(
        id: id,
        type: type,
        subject: subject,
        fact: fact ?? this.fact,
        confidence: confidence ?? this.confidence,
        sourceMessageId: sourceMessageId,
        sensitive: sensitive,
        pinned: pinned ?? this.pinned,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        embedding: embedding ?? this.embedding,
        memoryKey: memoryKey ?? this.memoryKey,
        supersededAt: supersededAt ?? this.supersededAt,
        supersededById: supersededById ?? this.supersededById,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'subject': subject,
        'fact': fact,
        'confidence': confidence,
        'sourceMessageId': sourceMessageId,
        'sensitive': sensitive,
        'pinned': pinned,
        'enabled': enabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
        'embedding': embedding,
        'memoryKey': memoryKey,
        'supersededAt': supersededAt?.toIso8601String(),
        'supersededById': supersededById,
      };

  factory UserMemoryEntry.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['createdAt'] as String);
    return UserMemoryEntry(
      id: json['id'] as String,
      type: MemoryType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => MemoryType.personalFact,
      ),
      subject: json['subject'] as String? ?? 'user',
      fact: json['fact'] as String,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.9,
      sourceMessageId: json['sourceMessageId'] as String?,
      sensitive: json['sensitive'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: createdAt,
      updatedAt: json['updatedAt'] == null
          ? createdAt
          : DateTime.parse(json['updatedAt'] as String),
      lastUsedAt: json['lastUsedAt'] == null
          ? null
          : DateTime.parse(json['lastUsedAt'] as String),
      embedding: (json['embedding'] as List?)
          ?.map((value) => (value as num).toDouble())
          .toList(growable: false),
      memoryKey: json['memoryKey'] as String?,
      supersededAt: json['supersededAt'] == null
          ? null
          : DateTime.parse(json['supersededAt'] as String),
      supersededById: json['supersededById'] as String?,
    );
  }
}

class LocalMemoryService {
  static final LocalMemoryService _instance = LocalMemoryService._internal();
  factory LocalMemoryService() => _instance;
  LocalMemoryService._internal();

  StorageService? _storage;
  final List<UserMemoryEntry> _memories = [];

  Future<void> init(StorageService storage) async {
    _storage = storage;
    _memories.clear();
    final raw = storage.getSetting(
      AppConstants.localMemoryRecordsKey,
      defaultValue: const [],
    );
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          try {
            _memories.add(
              UserMemoryEntry.fromJson(Map<String, dynamic>.from(item)),
            );
          } catch (_) {
            // Preserve valid entries if a single legacy record is malformed.
          }
        }
      }
    }
  }

  List<UserMemoryEntry> getMemories({
    MemoryType? type,
    bool enabledOnly = false,
    bool includeSuperseded = false,
  }) =>
      _memories
          .where((memory) =>
              (!enabledOnly || memory.enabled) &&
              (includeSuperseded || memory.supersededAt == null) &&
              (type == null || memory.type == type))
          .toList(growable: false);

  Future<bool> saveMemory(UserMemoryEntry entry) async {
    if (isSensitive(entry.fact)) return false;
    final normalized = _normalize(entry.fact);
    final normalizedKey = entry.memoryKey?.trim().toLowerCase();
    bool semanticDuplicate(UserMemoryEntry memory) =>
        memory.supersededAt == null &&
        memory.type == entry.type &&
        memory.subject.toLowerCase() == entry.subject.toLowerCase() &&
        memory.embedding != null &&
        entry.embedding != null &&
        _cosineSimilarity(memory.embedding!, entry.embedding!) >= 0.94;
    final index = _memories.indexWhere(
      (memory) =>
          memory.id == entry.id ||
          (normalizedKey?.isNotEmpty == true &&
              memory.memoryKey?.toLowerCase() == normalizedKey &&
              memory.supersededAt == null) ||
          (memory.type == entry.type &&
              memory.subject.toLowerCase() == entry.subject.toLowerCase() &&
              _normalize(memory.fact) == normalized) ||
          semanticDuplicate(memory),
    );
    if (index >= 0) {
      final current = _memories[index];
      if (_normalize(current.fact) == normalized ||
          current.id == entry.id ||
          semanticDuplicate(current)) {
        _memories[index] = current.copyWith(
          fact: entry.fact,
          confidence: entry.confidence > current.confidence
              ? entry.confidence
              : current.confidence,
          embedding: entry.embedding,
          memoryKey: entry.memoryKey,
          updatedAt: DateTime.now(),
        );
      } else {
        final now = DateTime.now();
        _memories[index] = current.copyWith(
          enabled: false,
          updatedAt: now,
          supersededAt: now,
          supersededById: entry.id,
        );
        _memories.add(entry);
      }
    } else {
      _memories.add(entry);
    }
    await _persist();
    return true;
  }

  Future<void> deleteMemory(String id) async {
    _memories.removeWhere((memory) => memory.id == id);
    await _persist();
  }

  Future<void> toggleMemory(String id, bool enabled) async {
    final index = _memories.indexWhere((memory) => memory.id == id);
    if (index < 0) return;
    _memories[index] = _memories[index].copyWith(
      enabled: enabled,
      updatedAt: DateTime.now(),
    );
    await _persist();
  }

  Future<void> markUsed(String id) async {
    final index = _memories.indexWhere((memory) => memory.id == id);
    if (index < 0) return;
    _memories[index] = _memories[index].copyWith(lastUsedAt: DateTime.now());
    await _persist();
  }

  bool isSensitive(String text) {
    final patterns = <RegExp>[
      RegExp(
        r'\b(password|passphrase|api[_ -]?key|access[_ -]?token|private[_ -]?key|secret)\b',
        caseSensitive: false,
      ),
      RegExp(r'\b(?:\d[ -]*?){13,19}\b'),
      RegExp(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
      RegExp(
        r'\b(bank account|routing number|social security|ssn)\b',
        caseSensitive: false,
      ),
    ];
    return patterns.any((pattern) => pattern.hasMatch(text));
  }

  Future<List<UserMemoryEntry>> extractMemoriesFromConversation(
    List<ChatMessage> messages, {
    required StructuredMemoryExtractor extractor,
  }) async {
    final extracted = <UserMemoryEntry>[];
    final candidates = await extractor(messages);
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      if (candidate.fact.trim().isEmpty ||
          candidate.key.trim().isEmpty ||
          candidate.confidence < 0.75 ||
          isSensitive(candidate.fact)) {
        continue;
      }
      final memory = UserMemoryEntry(
        id: 'mem_${DateTime.now().microsecondsSinceEpoch}_$index',
        type: candidate.type,
        subject: candidate.subject.trim(),
        fact: candidate.fact.trim(),
        confidence: candidate.confidence.clamp(0, 1),
        sourceMessageId: messages.isEmpty
            ? null
            : messages.last.timestamp.microsecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        memoryKey: candidate.key.trim().toLowerCase(),
      );
      if (await saveMemory(memory)) extracted.add(memory);
    }
    return extracted;
  }

  Future<void> _persist() async {
    final storage = _storage;
    if (storage == null) return;
    await storage.saveSetting(
      AppConstants.localMemoryRecordsKey,
      _memories.map((memory) => memory.toJson()).toList(growable: false),
    );
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  double _cosineSimilarity(List<double> left, List<double> right) {
    if (left.isEmpty || left.length != right.length) return -1;
    var dot = 0.0;
    var leftNorm = 0.0;
    var rightNorm = 0.0;
    for (var index = 0; index < left.length; index++) {
      dot += left[index] * right[index];
      leftNorm += pow(left[index], 2);
      rightNorm += pow(right[index], 2);
    }
    if (leftNorm == 0 || rightNorm == 0) return -1;
    return dot / (sqrt(leftNorm) * sqrt(rightNorm));
  }
}
