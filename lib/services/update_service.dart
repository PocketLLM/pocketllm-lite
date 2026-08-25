import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network_policy_service.dart';
import 'network_gateway.dart';

/// Model representing a GitHub release
class AppRelease {
  final String tagName;
  final String version;
  final String name;
  final String body;
  final String? apkDownloadUrl;
  final String? apkFilename;
  final String? checksumDownloadUrl;
  final String? apkSha256;
  final DateTime publishedAt;

  AppRelease({
    required this.tagName,
    required this.version,
    required this.name,
    required this.body,
    this.apkDownloadUrl,
    this.apkFilename,
    this.checksumDownloadUrl,
    this.apkSha256,
    required this.publishedAt,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    String? apkUrl;
    String? apkFilename;
    String? checksumUrl;
    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      for (final asset in assets) {
        final name = asset['name'] as String?;
        if (name != null && name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          apkFilename = name;
        }
        final lower = name?.toLowerCase() ?? '';
        if (lower == 'sha256sums.txt' || lower.endsWith('.sha256')) {
          checksumUrl = asset['browser_download_url'] as String?;
        }
      }
    }

    final tagName = json['tag_name'] as String? ?? '';
    // Extract version number from tag (e.g., "v1.0.9" -> "1.0.9")
    final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;

    return AppRelease(
      tagName: tagName,
      version: version,
      name: json['name'] as String? ?? tagName,
      body: json['body'] as String? ?? '',
      apkDownloadUrl: apkUrl,
      apkFilename: apkFilename,
      checksumDownloadUrl: checksumUrl,
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }

  AppRelease withApkSha256(String checksum) => AppRelease(
        tagName: tagName,
        version: version,
        name: name,
        body: body,
        apkDownloadUrl: apkDownloadUrl,
        apkFilename: apkFilename,
        checksumDownloadUrl: checksumDownloadUrl,
        apkSha256: checksum,
        publishedAt: publishedAt,
      );

  /// Check if this release is newer than the current app version
  bool isNewerThan(String currentVersion) {
    try {
      final current = _parseVersion(currentVersion);
      final release = _parseVersion(version);

      for (int i = 0; i < 3; i++) {
        if (release[i] > current[i]) return true;
        if (release[i] < current[i]) return false;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error comparing versions: $e');
      }
      return false;
    }
  }

  List<int> _parseVersion(String version) {
    final parts = version.split('.');
    return [
      parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      parts.length > 2 ? int.tryParse(parts[2].split('+').first) ?? 0 : 0,
    ];
  }
}

/// Result of an update check
class UpdateCheckResult {
  final bool updateAvailable;
  final AppRelease? release;
  final String? error;

  UpdateCheckResult({required this.updateAvailable, this.release, this.error});
}

/// Service to handle in-app updates from GitHub releases
class UpdateService {
  static const String _githubRepo = 'PocketLLM/pocketllm-lite';
  static const String _releasesApiUrl =
      'https://api.github.com/repos/$_githubRepo/releases/latest';
  static const String _lastUpdateCheckKey = 'last_update_check';
  static const String _dismissedVersionKey = 'dismissed_update_version';

  // Singleton pattern
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();
  final NetworkGateway _network = NetworkGateway();

  /// Check if auto-update is enabled (disabled by default)
  Future<bool> isAutoUpdateEnabled() async =>
      NetworkPolicyService().isAutoUpdateCheckEnabled;

  /// Set auto-update preference
  Future<void> setAutoUpdateEnabled(bool enabled) =>
      NetworkPolicyService().setAutoUpdateCheckEnabled(enabled);

  /// Get the dismissed version (if user dismissed an update notification)
  Future<String?> getDismissedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dismissedVersionKey);
  }

  /// Set dismissed version to avoid showing the same update again
  Future<void> setDismissedVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
  }

  /// Clear dismissed version (called when user wants to see updates again)
  Future<void> clearDismissedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedVersionKey);
  }

  /// Get the last update check time
  Future<DateTime?> getLastUpdateCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastUpdateCheckKey);
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Check for updates from GitHub releases
  Future<UpdateCheckResult> checkForUpdates({bool force = false}) async {
    try {
      // Check if auto-update is enabled (skip if force is true)
      if (!force) {
        final autoUpdateEnabled = await isAutoUpdateEnabled();
        if (!autoUpdateEnabled) {
          return UpdateCheckResult(updateAvailable: false);
        }
      }

      final uri = Uri.parse(_releasesApiUrl);
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (kDebugMode) {
        print('Current app version: $currentVersion');
      }

      // Fetch latest release from GitHub
      final response = await _network.get(
        uri,
        purpose: force
            ? ConnectionPurpose.manualUpdateCheck
            : ConnectionPurpose.updateCheck,
        trigger: force ? 'manual_update_check' : 'auto_update_check',
        infoSent: 'App version and standard HTTP headers; no user content',
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          updateAvailable: false,
          error: 'Failed to fetch releases: ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      var release = AppRelease.fromJson(json);
      release = await _resolveChecksum(release, manual: force);

      // Save last update check time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastUpdateCheckKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      // Check if newer version is available
      if (release.isNewerThan(currentVersion)) {
        // Check if this version was dismissed by the user
        final dismissedVersion = await getDismissedVersion();
        if (!force && dismissedVersion == release.version) {
          if (kDebugMode) {
            print('Update ${release.version} was previously dismissed');
          }
          return UpdateCheckResult(updateAvailable: false);
        }

        if (kDebugMode) {
          print('New version available: ${release.version}');
        }

        return UpdateCheckResult(updateAvailable: true, release: release);
      }

      if (kDebugMode) {
        print('No update available. Latest: ${release.version}');
      }

      return UpdateCheckResult(updateAvailable: false);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking for updates: $e');
      }
      return UpdateCheckResult(updateAvailable: false, error: e.toString());
    }
  }

  Future<AppRelease> _resolveChecksum(
    AppRelease release, {
    required bool manual,
  }) async {
    final checksumUrl = release.checksumDownloadUrl;
    final filename = release.apkFilename;
    if (checksumUrl == null || filename == null) return release;
    final response = await _network.get(
      Uri.parse(checksumUrl),
      purpose: manual
          ? ConnectionPurpose.manualUpdateCheck
          : ConnectionPurpose.updateCheck,
      trigger: 'release_checksum_verification',
      infoSent: 'Requested checksum asset; no user content',
      headers: {'Accept': 'text/plain'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return release;
    final match = RegExp(
      '^([a-fA-F0-9]{64})\\s+\\*?${RegExp.escape(filename)}\\s*\$',
      multiLine: true,
    ).firstMatch(response.body);
    return match == null ? release : release.withApkSha256(match.group(1)!);
  }

  /// Download and install the APK update
  /// Returns a stream of download progress (0.0 to 1.0)
  Stream<OtaEvent> downloadAndInstallUpdate(
    String downloadUrl, {
    required String? sha256,
  }) {
    final checksum = sha256?.trim().toLowerCase();
    if (checksum == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum)) {
      return Stream.error(
        StateError(
          'Direct installation is disabled because this release has no '
          'verified APK SHA-256 checksum.',
        ),
      );
    }
    final decision = NetworkPolicyService().evaluateConnection(
      uri: Uri.parse(downloadUrl),
      purpose: ConnectionPurpose.updateDownload,
      trigger: 'user_confirmed_ota_download',
      infoSent: 'Requested APK asset; no user content',
    );
    if (!decision.allowed) {
      return Stream.error(
        NetworkPolicyError(decision.reason ?? 'Update download blocked.'),
      );
    }
    if (kDebugMode) {
      print('Starting download from: $downloadUrl');
    }

    return OtaUpdate().execute(
      downloadUrl,
      destinationFilename: 'pocketllm_lite_update.apk',
      sha256checksum: checksum,
    );
  }

  /// Get the GitHub releases page URL for manual download
  String getReleasesPageUrl() {
    return 'https://github.com/$_githubRepo/releases';
  }

  /// Get direct download URL for latest release
  String getLatestReleaseUrl() {
    return 'https://github.com/$_githubRepo/releases/latest';
  }
}
