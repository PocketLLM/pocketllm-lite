import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

class Docs extends StatefulWidget {
  const Docs({super.key});

  @override
  State<Docs> createState() => _DocsState();
}

class _DocsState extends State<Docs> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hardcoded markdown content for Termux and Ollama setup
    const termuxDocs = '''
# Termux Setup Guide

## Install Termux
Download Termux from F-Droid for the latest version:
[F-Droid Termux](https://f-droid.org/en/packages/com.termux/)

## Basic Setup
Open Termux and run these commands:

```
pkg update && pkg upgrade
pkg install curl
```

## Install Ollama
```
curl -fsSL https://ollama.com/install.sh | sh
```

## Start Ollama Service
```
ollama serve
```

Keep Termux running in the background. You can minimize it, but don't swipe it away from recent apps.

## Pull a Model (Example)
```
ollama pull llama3
```

## Troubleshooting Tips
- If you get "connection refused" errors, make sure ollama serve is still running
- Some models require significant RAM. If downloads fail, try simpler models like "tinyllama"
- Use `termux-wake-lock` to prevent Termux from sleeping (optional but recommended)
''';

    const ollamaDocs = '''
# Ollama Setup Guide

## What is Ollama?
Ollama allows you to run large language models locally on your device. It's the backbone of Pocket LLM Lite.

## Installation
Visit [Ollama.com](https://ollama.com) and download the appropriate version for your system:
- Windows: Download the .exe installer
- macOS: Download the .app bundle
- Linux: Use the installation script

## Running Ollama
After installation, Ollama runs as a service:
- Windows: Runs as a background service automatically
- macOS: Runs as a background service automatically
- Linux: Start with `systemctl start ollama` or run `ollama serve` manually

## Pulling Models
Use the command line to pull models:
```
ollama pull llama3
ollama pull mistral
ollama pull tinyllama
```

## Model Directory
Models are stored in:
- Windows: `C:\\Users\\<username>\\.ollama\\models`
- macOS: `~/.ollama/models`
- Linux: `/usr/share/ollama/.ollama/models`

## API Endpoint
Pocket LLM Lite connects to Ollama at:
```
http://localhost:11434
```

This is usually detected automatically. If not, enter it manually in Settings.

## Troubleshooting
- Firewall issues: Make sure port 11434 is not blocked
- Model loading: Large models may take time to load on first use
- Memory errors: Try smaller models if you have limited RAM
''';

    return WillPopScope(
      onWillPop: () async {
        // Use GoRouter's pop method instead of Navigator.pop to avoid stack issues
        if (GoRouter.of(context).canPop()) {
          context.pop();
        } else {
          // If we can't pop, go to the settings screen directly
          context.go('/settings');
        }
        return false; // We handle the pop ourselves
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50], // User specified
        appBar: AppBar(
          backgroundColor: Colors.grey[50],
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
            onPressed: () {
              // Use GoRouter's pop method instead of Navigator.pop to avoid stack issues
              if (GoRouter.of(context).canPop()) {
                context.pop();
              } else {
                // If we can't pop, go to the settings screen directly
                context.go('/settings');
              }
            },
          ),
          title: const Text(
            'Documentation',
            style: TextStyle(
              color: Colors.black,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF8B5CF6),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF8B5CF6),
            tabs: const [
              Tab(text: 'Termux'),
              Tab(text: 'Ollama'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMarkdownTab(termuxDocs),
            _buildMarkdownTab(ollamaDocs),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownTab(String content) {
    return Markdown(
      data: content,
      selectable: true,
      padding: const EdgeInsets.all(16),
      styleSheet: MarkdownStyleSheet(
        h1: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        h2: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        h3: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        code: TextStyle(
          backgroundColor: Colors.grey[100],
          color: const Color(0xFF8B5CF6),
          fontSize: 14,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        blockquote: TextStyle(
          color: Colors.grey[800],
          fontSize: 16,
          fontStyle: FontStyle.italic,
        ),
        listBullet: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 16),
        p: const TextStyle(color: Colors.black87), // Ensure body text is black
      ),
      onTapLink: (text, url, title) {
        if (url != null) _launchUrl(url);
      },
    );
  }
}