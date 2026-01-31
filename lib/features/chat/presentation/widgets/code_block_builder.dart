import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
// ignore: depend_on_referenced_packages
import 'package:markdown/markdown.dart' as md;

/// A builder for rendering code blocks in Markdown with a copy button.
class CodeBlockBuilder extends MarkdownElementBuilder {
  final BuildContext context;

  CodeBlockBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Determine language from class attribute (e.g. language-dart)
    var language = '';
    if (element.attributes['class'] != null) {
      final lg = element.attributes['class'] as String;
      if (lg.startsWith('language-')) {
        language = lg.substring(9);
      }
    }

    if (language.isEmpty &&
        element.children != null &&
        element.children!.isNotEmpty) {
      final child = element.children!.first;
      if (child is md.Element && child.attributes['class'] != null) {
        final lg = child.attributes['class'] as String;
        if (lg.startsWith('language-')) {
          language = lg.substring(9);
        }
      }
    }

    // Get the code content
    final text = element.textContent.trimRight();
    if (text.isEmpty) return const SizedBox.shrink();

    // Heuristic: If it's a 'code' tag (inline) without language or newlines,
    // assume it's inline code and let default renderer handle it.
    if (element.tag == 'code' && language.isEmpty && !text.contains('\n')) {
      return null;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark background for code
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with language and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: const BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Semantics(
                  label: 'Copy Code',
                  button: true,
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: text));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Code copied to clipboard'),
                          duration: Duration(milliseconds: 1500),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy, size: 14, color: Colors.white70),
                          SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scrollable code area
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.white, // White text for code
              ),
            ),
          ),
        ],
      ),
    );
  }
}
