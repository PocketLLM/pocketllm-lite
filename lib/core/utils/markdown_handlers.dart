import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Centralized handlers for Markdown rendering to ensure security and privacy.
class MarkdownHandlers {
  /// Custom image builder that blocks network images to prevent IP leakage.
  ///
  /// This is a privacy measure for "Offline First" apps. Loading images from
  /// arbitrary URLs in LLM output allows remote servers to track user IPs.
  static Widget imageBuilder(Uri uri, String? title, String? alt) {
    final scheme = uri.scheme.toLowerCase();

    // Block network images
    if (scheme == 'http' || scheme == 'https') {
      return Tooltip(
        message: 'Network image blocked for privacy',
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  alt ?? 'Image blocked',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // We don't expect local assets or file images from LLM output in this app context.
    // If we did (e.g. generated images saved to disk), we would handle 'file' scheme here
    // with strict path validation. For now, block everything else too.
    return const SizedBox.shrink();
  }
}
