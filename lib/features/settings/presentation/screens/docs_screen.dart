import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/url_validator.dart';
import '../../../../core/utils/markdown_handlers.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../services/external_navigation_service.dart';

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

  Future<void> _openExternalLink(String url) async {
    if (!UrlValidator.isSecureUrlString(url)) return;
    final uri = Uri.parse(url);
    try {
      await ExternalNavigationService().openHttpUrl(
        uri,
        trigger: 'in_app_documentation_link',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    // File Overview:
    // - Purpose: Fullscreen documentation view duplicating the app bar docs tabs.
    // - Backend Migration: Replace hardcoded markdown with backend-served
    //   documentation sources.
    const termuxDocs = '''
# Termux Setup Guide

## What Termux Is
Termux provides an Android terminal and Linux package environment without requiring root. It is an advanced, separately maintained app; PocketLLM Lite does not install, update, or control it.

## Install from an Official Source

- Use the [Termux F-Droid listing](https://f-droid.org/packages/com.termux/) or [official GitHub releases](https://github.com/termux/termux-app/releases).
- Follow the current release notes instead of an APK filename copied from this guide.
- Install Termux and every Termux plugin from the same source. Their signing keys differ across sources and mixed installations are incompatible.
- Android 7 or newer is required for current package support.

## Initial Setup

Update the package index after installation:

```bash
pkg update
pkg upgrade
```

Only request shared-storage access if you need it:

```bash
termux-setup-storage
```

This grants Termux access to shared device storage; it is not required merely to connect PocketLLM Lite to a server.

## Useful Commands

- Install a package: `pkg install <package-name>`
- Search packages: `pkg search <query>`
- Update installed packages: `pkg upgrade`
- Check storage: `df -h`
- Change mirrors if repository access fails: `termux-change-repo`

## Important Boundary

Ollama's official documentation lists macOS, Windows, and Linux. It does not document Android or Termux as a supported platform. Any Termux build is therefore a community or experimental setup whose commands and compatibility may change. PocketLLM Lite can connect to a working HTTP endpoint, but it does not certify a Termux Ollama build.

## More Information

- [Official Termux app repository](https://github.com/termux/termux-app)
- [Termux packages repository](https://github.com/termux/termux-packages)
''';

    const ollamaDocs = '''
# Connect to Ollama

## Supported Host Platforms

Ollama's official quickstart supports macOS, Windows, and Linux. Install it on a trusted computer from the [official Ollama documentation](https://docs.ollama.com/quickstart), start it, and verify the host can list its installed models:

```bash
ollama list
```

PocketLLM Lite discovers the models actually returned by your chosen endpoint. It does not hardcode a recommended catalog because model availability, memory needs, formats, and capabilities change.

## Connect PocketLLM Lite

1. Open **Settings > Providers > Ollama**.
2. Enter the base URL, normally `http://HOST_IP:11434`.
3. Use the connection test before starting a chat.
4. Refresh models and choose one returned by the endpoint.

`localhost` and `127.0.0.1` refer to the Android device itself. Use the computer's private LAN address when Ollama runs on another machine.

## Allow LAN Access Carefully

Ollama binds to `127.0.0.1:11434` by default. Its official FAQ documents `OLLAMA_HOST` for network exposure. Restrict access with your operating-system firewall and use only a trusted network; the plain HTTP endpoint is not an Internet-safe authentication boundary.

PocketLLM Lite sends prompts, conversation context, and requested embedding text to the endpoint you configure. These requests appear in the app's network audit. **Strict Offline Mode blocks non-loopback Ollama endpoints**, including private LAN hosts.

## Model and Resource Guidance

- Inspect installed models with `ollama list`; add or remove models using current Ollama documentation.
- Model size alone does not predict whether a model will run well. Context length, quantization, available RAM, backend support, and thermal limits all matter.
- Begin with a small quantized model that fits the host, then verify output quality and latency on your own hardware.
- Ollama may offer cloud features. Consult its current privacy and local-only settings if you require a local-only host.

## Troubleshooting

- Confirm Ollama is running on the host.
- Confirm the phone and host can reach each other on the selected network.
- Check the host firewall and bind address.
- Do not use `localhost` for a server running on another device.
- Temporarily review Strict Offline Mode and the network audit; do not disable it without understanding the connection.

## More Information

- [Ollama quickstart](https://docs.ollama.com/quickstart)
- [Ollama API reference](https://docs.ollama.com/api/introduction)
- [Ollama networking FAQ](https://docs.ollama.com/faq)
''';

    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Use GoRouter's pop method instead of Navigator.pop to avoid stack issues
        if (GoRouter.of(context).canPop()) {
          context.pop();
        } else {
          // If we can't pop, go to the settings screen directly
          context.go('/settings');
        }
      },
      child: Scaffold(
        appBar: M3AppBar(
          title: 'Documentation',
          onBack: () {
            // Use GoRouter's pop method instead of Navigator.pop to avoid stack issues
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              // If we can't pop, go to the settings screen directly
              context.go('/settings');
            }
          },
          bottom: TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
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
    final theme = Theme.of(context);
    return Markdown(
      data: content,
      selectable: true,
      padding: const EdgeInsets.all(16),
      // ignore: deprecated_member_use
      imageBuilder: MarkdownHandlers.imageBuilder,
      styleSheet: MarkdownStyleSheet(
        h1: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        h2: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        h3: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        code: TextStyle(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          color: theme.colorScheme.primary,
          fontSize: 14,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        blockquote: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 16,
          fontStyle: FontStyle.italic,
        ),
        listBullet: TextStyle(color: theme.colorScheme.primary, fontSize: 16),
        p: TextStyle(color: theme.colorScheme.onSurface),
      ),
      onTapLink: (text, url, title) {
        if (url != null) _openExternalLink(url);
      },
    );
  }
}
