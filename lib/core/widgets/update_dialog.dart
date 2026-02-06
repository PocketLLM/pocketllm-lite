import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/update_service.dart';


/// Dialog to show update information and download progress
class UpdateDialog extends StatefulWidget {
  final AppRelease release;
  final VoidCallback? onDismissed;
  final VoidCallback? onSkipVersion;

  const UpdateDialog({
    super.key,
    required this.release,
    this.onDismissed,
    this.onSkipVersion,
  });

  /// Show the update dialog
  static Future<void> show(
    BuildContext context,
    AppRelease release, {
    VoidCallback? onDismissed,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          UpdateDialog(release: release, onDismissed: onDismissed),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with SingleTickerProviderStateMixin {
  final UpdateService _updateService = UpdateService();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _status = '';
  String? _error;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    if (widget.release.apkDownloadUrl == null) {
      setState(() {
        _error = 'No APK download URL available';
      });
      return;
    }

    setState(() {
      _isDownloading = true;
      _status = 'Preparing download...';
      _error = null;
    });

    HapticFeedback.mediumImpact();

    String? checksum;
    if (widget.release.checksumUrl != null &&
        widget.release.apkFilename != null) {
      setState(() => _status = 'Verifying update security...');
      try {
        final content = await _updateService.fetchChecksum(
          widget.release.checksumUrl!,
        );
        if (content != null) {
          checksum = _updateService.extractChecksum(
            content,
            widget.release.apkFilename!,
          );
          if (checksum == null) {
            if (mounted) {
              setState(() {
                _error =
                    'Security check failed: Checksum not found for ${widget.release.apkFilename}';
                _isDownloading = false;
              });
            }
            return;
          }
        } else {
          if (mounted) {
            setState(() {
              _error = 'Security check failed: Could not fetch verification file';
              _isDownloading = false;
            });
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Security verification error: $e';
            _isDownloading = false;
          });
        }
        return;
      }
    }

    setState(() => _status = 'Starting download...');

    try {
      _updateService
          .downloadAndInstallUpdate(
            widget.release.apkDownloadUrl!,
            sha256checksum: checksum,
          )
          .listen(
            (event) {
              setState(() {
                switch (event.status) {
                  case OtaStatus.DOWNLOADING:
                    _status = 'Downloading update...';
                    _downloadProgress =
                        double.tryParse(event.value ?? '0') ?? 0;
                    _downloadProgress = _downloadProgress / 100;
                    break;
                  case OtaStatus.INSTALLING:
                    _status = 'Installing update...';
                    _downloadProgress = 1.0;
                    break;
                  case OtaStatus.INSTALLATION_DONE:
                    _status = 'Installation complete!';
                    _isDownloading = false;
                    // Close the dialog after successful installation
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                    break;
                  case OtaStatus.ALREADY_RUNNING_ERROR:
                    _error = 'Download already in progress';
                    _isDownloading = false;
                    break;
                  case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                    _error =
                        'Permission denied. Please enable "Install from unknown sources" in settings.';
                    _isDownloading = false;
                    break;
                  case OtaStatus.INTERNAL_ERROR:
                    _error = 'An error occurred: ${event.value}';
                    _isDownloading = false;
                    break;
                  case OtaStatus.DOWNLOAD_ERROR:
                    _error = 'Download failed. Please check your connection.';
                    _isDownloading = false;
                    break;
                  case OtaStatus.CHECKSUM_ERROR:
                    _error = 'File verification failed. Please try again.';
                    _isDownloading = false;
                    break;
                  case OtaStatus.INSTALLATION_ERROR:
                    _error = 'Installation failed. Please try again.';
                    _isDownloading = false;
                    break;
                  case OtaStatus.CANCELED:
                    _error = 'Download was canceled.';
                    _isDownloading = false;
                    break;
                }
              });
            },
            onError: (e) {
              setState(() {
                _error = 'Error: $e';
                _isDownloading = false;
              });
            },
          );
    } catch (e) {
      setState(() {
        _error = 'Failed to start download: $e';
        _isDownloading = false;
      });
    }
  }

  Future<void> _openReleasePage() async {
    final url = Uri.parse(_updateService.getLatestReleaseUrl());
    HapticFeedback.lightImpact();
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _dismissUpdate() {
    HapticFeedback.lightImpact();
    widget.onDismissed?.call();
    Navigator.of(context).pop();
  }

  Future<void> _skipThisVersion() async {
    HapticFeedback.mediumImpact();
    await _updateService.setDismissedVersion(widget.release.version);
    widget.onSkipVersion?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.1),
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.system_update,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Available!',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'v${widget.release.version}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isDownloading)
                    IconButton(
                      onPressed: _dismissUpdate,
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.release.body.isNotEmpty) ...[
                      Text(
                        "What's New",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: MarkdownBody(
                          data: widget.release.body,
                          styleSheet: MarkdownStyleSheet.fromTheme(theme)
                              .copyWith(
                                p: theme.textTheme.bodyMedium,
                                listBullet: theme.textTheme.bodyMedium,
                              ),

                        ),
                      ),
                    ],
                    if (widget.release.apkDownloadUrl == null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No APK available for direct download. You can download from GitHub releases.',
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: theme.colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Download Progress
            if (_isDownloading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _status,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        minHeight: 8,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  if (!_isDownloading) ...[
                    Row(
                      children: [
                        if (widget.release.apkDownloadUrl != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _startDownload,
                              icon: const Icon(Icons.download),
                              label: const Text('Download & Install'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _openReleasePage,
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open GitHub Releases'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _dismissUpdate,
                            child: const Text('Later'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            onPressed: _skipThisVersion,
                            child: const Text('Skip This Version'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'Please wait while the update is being downloaded...',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
