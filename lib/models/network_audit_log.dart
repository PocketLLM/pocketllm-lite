class NetworkAuditEntry {
  final DateTime timestamp;
  final String domain;
  final String purpose;
  final String trigger;
  final String infoSent;
  final bool allowed;
  final String? blockReason;

  const NetworkAuditEntry({
    required this.timestamp,
    required this.domain,
    required this.purpose,
    required this.trigger,
    required this.infoSent,
    required this.allowed,
    this.blockReason,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'domain': domain,
        'purpose': purpose,
        'trigger': trigger,
        'infoSent': infoSent,
        'allowed': allowed,
        'blockReason': blockReason,
      };

  factory NetworkAuditEntry.fromJson(Map<String, dynamic> json) {
    return NetworkAuditEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      domain: json['domain'] as String,
      purpose: json['purpose'] as String,
      trigger: json['trigger'] as String,
      infoSent: json['infoSent'] as String,
      allowed: json['allowed'] as bool,
      blockReason: json['blockReason'] as String?,
    );
  }
}
