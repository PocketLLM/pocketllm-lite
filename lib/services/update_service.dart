import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper for OtaUpdate to facilitate testing
class OtaUpdateWrapper {
  Stream<OtaEvent> execute(
    String url, {
    required String destinationFilename,
    String? sha256checksum,
  }) {
    return OtaUpdate().execute(
      url,
      destinationFilename: destinationFilename,
      sha256checksum: sha256checksum,
    );
  }
}

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
        if (name == null || url == null) continue;

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

  http.Client _client = http.Client();
  OtaUpdateWrapper _otaUpdate = OtaUpdateWrapper();

  /// Visible for testing
  @visibleForTesting
  set client(http.Client client) => _client = client;

  /// Visible for testing
  @visibleForTesting
  set otaUpdate(OtaUpdateWrapper otaUpdate) => _otaUpdate = otaUpdate;

  // Singleton pattern
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

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

  /// Download and install the APK update
  /// Returns a stream of download progress (0.0 to 1.0)
  Stream<OtaEvent> downloadAndInstallUpdate(AppRelease release) async* {
    final downloadUrl = release.apkDownloadUrl;
    if (downloadUrl == null) {
      yield OtaEvent(
        OtaStatus.INTERNAL_ERROR,
        'No APK download URL available',
      );
      return;
    }

    if (kDebugMode) {
      print('Starting download from: $downloadUrl');
    }

    String? checksum;
    if (release.checksumUrl != null && release.apkFilename != null) {
      yield OtaEvent(OtaStatus.DOWNLOADING, '0');
      try {
        if (kDebugMode) {
          print('Fetching checksum from: ${release.checksumUrl}');
        }
        checksum = await _fetchChecksum(
          release.checksumUrl!,
          release.apkFilename!,
        );
      } catch (e) {
        if (kDebugMode) {
          print('Failed to fetch/parse checksum: $e');
        }
        yield OtaEvent(
          OtaStatus.CHECKSUM_ERROR,
          'Failed to verify update integrity: $e',
        );
        return;
      }
    }

    yield* _otaUpdate.execute(
      downloadUrl,
      destinationFilename: 'pocketllm_lite_update.apk',
      sha256checksum: checksum,
    );
  }

  /// Fetch and parse the checksum file
  Future<String?> _fetchChecksum(String url, String filename) async {
    final response = await _client.get(Uri.parse(url)).timeout(
      const Duration(seconds: 10),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download checksum file: ${response.statusCode}',
      );
    }

    // Parse the checksum file (lines like "HASH  filename" or "HASH *filename")
    // GitHub releases often use `sha256sum` output format
    final lines = const LineSplitter().convert(response.body);
    for (final line in lines) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final hash = parts[0];
        // The filename part might contain '*' for binary mode or be just the name
        // We join the rest just in case, but usually it's just the name
        var nameInFile = parts.sublist(1).join(' ');
        if (nameInFile.startsWith('*')) {
          nameInFile = nameInFile.substring(1);
        }

        if (nameInFile == filename) {
          return hash;
        }
      }
    }

    throw Exception('Checksum for $filename not found in checksum file');
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
