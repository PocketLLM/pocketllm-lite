import 'dart:async';
import '../core/constants/app_constants.dart';
import '../models/network_audit_log.dart';
import 'storage_service.dart';

enum ConnectionPurpose {
  updateCheck,
  modelSearch,
  modelDownload,
  webSearch,
  skillInstall,
  remoteInference,
  fontDownload,
}

class NetworkPolicyResult {
  final bool allowed;
  final String? reason;

  const NetworkPolicyResult({required this.allowed, this.reason});
}

class NetworkPolicyService {
  static final NetworkPolicyService _instance =
      NetworkPolicyService._internal();
  factory NetworkPolicyService() => _instance;
  NetworkPolicyService._internal();

  StorageService? _storageService;
  final List<NetworkAuditEntry> _auditLog = [];
  final StreamController<List<NetworkAuditEntry>> _auditLogController =
      StreamController<List<NetworkAuditEntry>>.broadcast();

  Stream<List<NetworkAuditEntry>> get auditLogStream =>
      _auditLogController.stream;
  List<NetworkAuditEntry> get auditLog => List.unmodifiable(_auditLog);

  void init(StorageService storageService) {
    _storageService = storageService;
  }

  bool isLoopback(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '::1' ||
        host == '0.0.0.0';
  }

  bool get isStrictOfflineMode {
    if (_storageService == null) return false;
    final val = _storageService!.getSetting(
      AppConstants.strictOfflineModeKey,
      defaultValue: false,
    );
    return val is bool ? val : false;
  }

  bool get isAutoUpdateCheckEnabled {
    if (_storageService == null) return false;
    final val = _storageService!.getSetting(
      AppConstants.autoUpdateCheckKey,
      defaultValue: false,
    );
    return val is bool ? val : false;
  }

  bool get isOnlineModelBrowsingEnabled {
    if (_storageService == null) return true;
    final val = _storageService!.getSetting(
      AppConstants.onlineModelBrowsingKey,
      defaultValue: true,
    );
    return val is bool ? val : true;
  }

  bool get isTavilySearchEnabled {
    if (_storageService == null) return true;
    final val = _storageService!.getSetting(
      AppConstants.tavilySearchEnabledKey,
      defaultValue: true,
    );
    return val is bool ? val : true;
  }

  bool get isGithubSkillsEnabled {
    if (_storageService == null) return true;
    final val = _storageService!.getSetting(
      AppConstants.githubSkillsEnabledKey,
      defaultValue: true,
    );
    return val is bool ? val : true;
  }

  NetworkPolicyResult evaluateConnection({
    required Uri uri,
    required ConnectionPurpose purpose,
    required String trigger,
    required String infoSent,
  }) {
    final domain = uri.host.isEmpty ? uri.toString() : uri.host;
    final loopback = isLoopback(uri);

    if (loopback) {
      _logAudit(
        domain: domain,
        purpose: purpose.name,
        trigger: trigger,
        infoSent: infoSent,
        allowed: true,
      );
      return const NetworkPolicyResult(allowed: true);
    }

    if (isStrictOfflineMode) {
      const reason = 'Blocked by Strict Offline Mode';
      _logAudit(
        domain: domain,
        purpose: purpose.name,
        trigger: trigger,
        infoSent: infoSent,
        allowed: false,
        blockReason: reason,
      );
      return const NetworkPolicyResult(allowed: false, reason: reason);
    }

    switch (purpose) {
      case ConnectionPurpose.updateCheck:
        if (!isAutoUpdateCheckEnabled) {
          const reason = 'Automatic update checks disabled';
          _logAudit(
            domain: domain,
            purpose: purpose.name,
            trigger: trigger,
            infoSent: infoSent,
            allowed: false,
            blockReason: reason,
          );
          return const NetworkPolicyResult(allowed: false, reason: reason);
        }
        break;

      case ConnectionPurpose.modelSearch:
      case ConnectionPurpose.modelDownload:
        if (!isOnlineModelBrowsingEnabled) {
          const reason = 'Online model browsing disabled';
          _logAudit(
            domain: domain,
            purpose: purpose.name,
            trigger: trigger,
            infoSent: infoSent,
            allowed: false,
            blockReason: reason,
          );
          return const NetworkPolicyResult(allowed: false, reason: reason);
        }
        break;

      case ConnectionPurpose.webSearch:
        if (!isTavilySearchEnabled) {
          const reason = 'Tavily web search disabled';
          _logAudit(
            domain: domain,
            purpose: purpose.name,
            trigger: trigger,
            infoSent: infoSent,
            allowed: false,
            blockReason: reason,
          );
          return const NetworkPolicyResult(allowed: false, reason: reason);
        }
        break;

      case ConnectionPurpose.skillInstall:
        if (!isGithubSkillsEnabled) {
          const reason = 'GitHub skill installation disabled';
          _logAudit(
            domain: domain,
            purpose: purpose.name,
            trigger: trigger,
            infoSent: infoSent,
            allowed: false,
            blockReason: reason,
          );
          return const NetworkPolicyResult(allowed: false, reason: reason);
        }
        break;

      case ConnectionPurpose.fontDownload:
        const reason =
            'Runtime font downloading is disabled (fonts bundled locally)';
        _logAudit(
          domain: domain,
          purpose: purpose.name,
          trigger: trigger,
          infoSent: infoSent,
          allowed: false,
          blockReason: reason,
        );
        return const NetworkPolicyResult(allowed: false, reason: reason);

      case ConnectionPurpose.remoteInference:
        break;
    }

    _logAudit(
      domain: domain,
      purpose: purpose.name,
      trigger: trigger,
      infoSent: infoSent,
      allowed: true,
    );
    return const NetworkPolicyResult(allowed: true);
  }

  void _logAudit({
    required String domain,
    required String purpose,
    required String trigger,
    required String infoSent,
    required bool allowed,
    String? blockReason,
  }) {
    final entry = NetworkAuditEntry(
      timestamp: DateTime.now(),
      domain: domain,
      purpose: purpose,
      trigger: trigger,
      infoSent: infoSent,
      allowed: allowed,
      blockReason: blockReason,
    );
    _auditLog.insert(0, entry);
    if (_auditLog.length > 100) {
      _auditLog.removeLast();
    }
    _auditLogController.add(List.unmodifiable(_auditLog));
  }
}
