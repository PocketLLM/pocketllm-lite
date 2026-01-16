import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'url_validator.dart';

class MarkdownHandlers {
  /// Handles link taps by validating the scheme before launching.
  static void onTapLink(String? text, String? href, String? title) async {
    if (href != null) {
      final uri = Uri.tryParse(href);
      if (UrlValidator.isSecureUrl(uri) && await canLaunchUrl(uri!)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Custom image builder that blocks external network images for privacy.
  static Widget imageBuilder(Uri uri, String? title, String? alt) {
    // Block network images (http/https) to prevent IP leakage/tracking.
    // This supports the "Privacy-First" and "Offline" philosophy.
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return Tooltip(
        message: 'External images blocked for privacy',
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.withValues(alpha: 0.1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  alt ?? 'External Image Blocked',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // For other schemes (assets, file, etc.), we fall back to default behavior.
    // However, MarkdownBody doesn't expose a "default" builder easily to call.
    // So we must return a widget.
    // Since this app shouldn't be loading local files via markdown paths (security risk),
    // it's safer to just return generic placeholder for everything unless explicitly allowed.
    // But for now, let's just return a standard Image.network/file/asset if we wanted to support them?
    // Actually, flutter_markdown's default builder handles all this.
    // If we return a Widget, we override it.

    // If we want to ONLY block http/https, we can't easily "super" the default builder.
    // But since we are offline-first, maybe we only support data uris?
    // Let's stick to blocking http/s and showing a placeholder.
    // For other schemes, if any, we'll show a generic icon to be safe.

    return Tooltip(
      message: 'Image blocked',
      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.withValues(alpha: 0.5)),
    );
  }
}
