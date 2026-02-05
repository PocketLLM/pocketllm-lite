import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model representing a GitHub release
class AppRelease {
  final String tagName;
  final String version;
  final String name;
  final String body;
  final String? apkDownloadUrl;
  final String? checksumUrl;
  final String? apkFilename;
  final DateTime publishedAt;

  AppRelease({
    required this.tagName,
    required this.version,
    required this.name,
    required this.body,
    this.apkDownloadUrl,
    this.checksumUrl,
    this.apkFilename,
    required this.publishedAt,
  });

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    String? apkUrl;
    String? checksumUrl;
    String? apkFilename;

    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      for (final asset in assets) {
        final name = asset['name'] as String?;
        final url = asset['browser_download_url'] as String?;

        if (name != null && url != null) {
          if (name.endsWith('.apk')) {
            apkUrl = url;
            apkFilename = name;
          } else if (name.endsWith('.sha256') ||
              name.endsWith('.sha256sum') ||
              name == 'checksums.txt') {
            checksumUrl = url;
          }
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
      checksumUrl: checksumUrl,
      apkFilename: apkFilename,
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }

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
  static const String _autoUpdateKey = 'auto_update_enabled';
  static const String _lastUpdateCheckKey = 'last_update_check';
  static const String _dismissedVersionKey = 'dismissed_update_version';

  // Singleton pattern
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  http.Client _client = http.Client();

  @visibleForTesting
  set client(http.Client client) => _client = client;

  /// Check if auto-update is enabled
  Future<bool> isAutoUpdateEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoUpdateKey) ?? true; // Enabled by default
  }

  /// Set auto-update preference
  Future<void> setAutoUpdateEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoUpdateKey, enabled);
  }

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

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (kDebugMode) {
        print('Current app version: $currentVersion');
      }

      // Fetch latest release from GitHub
      final response = await _client
          .get(
            Uri.parse(_releasesApiUrl),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          updateAvailable: false,
          error: 'Failed to fetch releases: ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final release = AppRelease.fromJson(json);

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

  /// Fetch and parse the SHA256 checksum for the APK
  Future<String?> _fetchChecksum(String url, String apkFilename) async {
    try {
      if (kDebugMode) {
        print('Fetching checksum from: $url');
      }

      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('Failed to fetch checksum: ${response.statusCode}');
        }
        return null;
      }

      final content = response.body;
      final lines = LineSplitter.split(content);

      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        // Standard format: HASH  FILENAME
        if (parts.length >= 2) {
          final hash = parts[0];
          // Check if it looks like a SHA256 hash (64 hex chars)
          if (hash.length != 64) continue;

          final filename = parts.sublist(1).join(' ');
          // Match filename (handle potential leading '*' for binary mode)
          if (filename == apkFilename || filename == '*$apkFilename') {
            return hash;
          }
        }
        // Single hash format (if file is specific to the APK)
        else if (parts.length == 1 && parts[0].length == 64) {
          // Only return if we are fairly sure (e.g. only one line in file)
          if (lines.length == 1) {
            return parts[0];
          }
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching checksum: $e');
      }
      return null;
    }
  }

  /// Download and install the APK update
  /// Returns a stream of download progress (0.0 to 1.0)
  Stream<OtaEvent> downloadAndInstallUpdate(AppRelease release) async* {
    if (release.apkDownloadUrl == null) {
      yield OtaEvent(OtaStatus.INTERNAL_ERROR, 'No APK download URL');
      return;
    }

    String? checksum;
    if (release.checksumUrl != null && release.apkFilename != null) {
      checksum = await _fetchChecksum(
        release.checksumUrl!,
        release.apkFilename!,
      );
    }

    if (kDebugMode) {
      print('Starting download from: ${release.apkDownloadUrl}');
      if (checksum != null) {
        print('Using checksum: $checksum');
      }
    }

    yield* OtaUpdate().execute(
      release.apkDownloadUrl!,
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
