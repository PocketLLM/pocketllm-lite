import 'dart:async';

import '../features/chat/domain/models/chat_message.dart';
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
  }) : updatedAt = updatedAt ?? createdAt;

  UserMemoryEntry copyWith({
    String? fact,
    double? confidence,
    bool? pinned,
    bool? enabled,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    List<double>? embedding,
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
    );
  }
}

class LocalMemoryService {
  static const _storageKey = 'local_memory_records_v2';
  static final LocalMemoryService _instance = LocalMemoryService._internal();
  factory LocalMemoryService() => _instance;
  LocalMemoryService._internal();

  StorageService? _storage;
  final List<UserMemoryEntry> _memories = [];

  Future<void> init(StorageService storage) async {
    _storage = storage;
    _memories.clear();
    final raw = storage.getSetting(_storageKey, defaultValue: const []);
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
  }) =>
      _memories
          .where((memory) =>
              (!enabledOnly || memory.enabled) &&
              (type == null || memory.type == type))
          .toList(growable: false);

  Future<bool> saveMemory(UserMemoryEntry entry) async {
    if (isSensitive(entry.fact)) return false;
    final normalized = _normalize(entry.fact);
    final index = _memories.indexWhere((memory) =>
        memory.id == entry.id ||
        (memory.type == entry.type &&
            memory.subject.toLowerCase() == entry.subject.toLowerCase() &&
            _normalize(memory.fact) == normalized));
    if (index >= 0) {
      final current = _memories[index];
      _memories[index] = entry.copyWith(
        confidence: entry.confidence > current.confidence
            ? entry.confidence
            : current.confidence,
        updatedAt: DateTime.now(),
      );
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
    List<ChatMessage> messages,
  ) async {
    final extracted = <UserMemoryEntry>[];
    for (final message in messages.where((item) => item.role == 'user')) {
      final lower = message.content.toLowerCase();
      final type = lower.contains('i prefer ') ||
              lower.contains('i like ') ||
              lower.contains('always write ')
          ? MemoryType.preference
          : lower.contains('my name is ') ||
                  lower.contains("i'm a ") ||
                  lower.contains('i live in ')
              ? MemoryType.personalFact
              : null;
      if (type == null || isSensitive(message.content)) continue;
      final memory = UserMemoryEntry(
        id: 'mem_${message.timestamp.microsecondsSinceEpoch}',
        type: type,
        subject: 'user',
        fact: message.content.trim(),
        confidence: type == MemoryType.personalFact ? 0.92 : 0.88,
        sourceMessageId: message.timestamp.microsecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
      );
      if (await saveMemory(memory)) extracted.add(memory);
    }
    return extracted;
  }

  Future<void> _persist() async {
    final storage = _storage;
    if (storage == null) return;
    await storage.saveSetting(
      _storageKey,
      _memories.map((memory) => memory.toJson()).toList(growable: false),
    );
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
