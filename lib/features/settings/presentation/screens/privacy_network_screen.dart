import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';
import '../../../../models/network_audit_log.dart';
import '../../../../services/network_policy_service.dart';
import '../../../../core/utils/url_validator.dart';
import '../../../../core/widgets/m3_app_bar.dart';
import '../../../../services/openai_compatible_inference_service.dart';
import '../../../../services/openai_server_service.dart';
import '../../../../services/remote_provider_registry.dart';
import '../../../chat/presentation/providers/models_provider.dart';

class PrivacyNetworkScreen extends ConsumerStatefulWidget {
  const PrivacyNetworkScreen({super.key});

  @override
  ConsumerState<PrivacyNetworkScreen> createState() =>
      _PrivacyNetworkScreenState();
}

class _PrivacyNetworkScreenState extends ConsumerState<PrivacyNetworkScreen> {
  final TextEditingController _ollamaUrlController = TextEditingController();
  final TextEditingController _serverPortController =
      TextEditingController(text: '8080');
  List<RemoteProviderConfig> _remoteProviders = const [];
  bool _serverLocalhostOnly = true;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    final urlVal = storage.getSetting(
      AppConstants.ollamaBaseUrlKey,
      defaultValue: AppConstants.defaultOllamaBaseUrl,
    );
    _ollamaUrlController.text =
        urlVal is String ? urlVal : AppConstants.defaultOllamaBaseUrl;
    _loadRemoteProviders();
  }

  Future<void> _loadRemoteProviders() async {
    final providers = await ref.read(remoteProviderRegistryProvider).load();
    if (mounted) setState(() => _remoteProviders = providers);
  }

  Future<void> _showRemoteProviderDialog(
      {RemoteProviderConfig? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final baseUrl = TextEditingController(text: existing?.baseUrl ?? '');
    final apiKey = TextEditingController(text: existing?.apiKey ?? '');
    final modelId = TextEditingController(text: existing?.modelId ?? '');
    final headers = TextEditingController(
      text: existing == null || existing.customHeaders.isEmpty
          ? ''
          : const JsonEncoder.withIndent('  ').convert(existing.customHeaders),
    );
    final contextLength = TextEditingController(
      text: (existing?.contextLength ?? 8192).toString(),
    );
    var supportsVision = existing?.supportsVision ?? false;
    var supportsTools = existing?.supportsTools ?? false;
    var streaming = existing?.streaming ?? true;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final border = OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
            );
            return AlertDialog(
              title: Text(existing == null
                  ? 'Add OpenAI-compatible provider'
                  : 'Edit remote provider'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        decoration: InputDecoration(
                          labelText: 'Provider name',
                          border: border,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: baseUrl,
                        decoration: InputDecoration(
                          labelText: 'Base URL',
                          hintText: 'http://127.0.0.1:1234',
                          border: border,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: apiKey,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'API key (optional)',
                          border: border,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: modelId,
                        decoration: InputDecoration(
                          labelText: 'Model ID',
                          border: border,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contextLength,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Context length',
                          border: border,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: headers,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Custom headers (JSON, optional)',
                          hintText: '{"X-Project": "local"}',
                          border: border,
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Streaming'),
                        value: streaming,
                        onChanged: (value) =>
                            setDialogState(() => streaming = value),
                      ),
                      SwitchListTile(
                        title: const Text('Vision support'),
                        subtitle: const Text('Enable only if verified.'),
                        value: supportsVision,
                        onChanged: (value) =>
                            setDialogState(() => supportsVision = value),
                      ),
                      SwitchListTile(
                        title: const Text('Tool support'),
                        subtitle: const Text('Enable only if verified.'),
                        value: supportsTools,
                        onChanged: (value) =>
                            setDialogState(() => supportsTools = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final uri = Uri.tryParse(baseUrl.text.trim());
                      if (name.text.trim().isEmpty ||
                          modelId.text.trim().isEmpty ||
                          uri == null ||
                          !UrlValidator.isHttpUrlString(baseUrl.text.trim())) {
                        throw const FormatException(
                          'Name, HTTP(S) Base URL, and Model ID are required.',
                        );
                      }
                      final parsedHeaders = headers.text.trim().isEmpty
                          ? const <String, String>{}
                          : Map<String, String>.from(
                              jsonDecode(headers.text) as Map,
                            );
                      final parsedContext = int.tryParse(contextLength.text);
                      if (parsedContext == null || parsedContext < 512) {
                        throw const FormatException(
                          'Context length must be at least 512.',
                        );
                      }
                      if (!NetworkPolicyService().isLoopback(uri)) {
                        final trusted = await showDialog<bool>(
                          context: dialogContext,
                          builder: (context) => AlertDialog(
                            title: const Text('Confirm remote data transfer'),
                            content: Text(
                              'Prompts, attachments, and model parameters may '
                              'be sent to ${uri.host}. Continue only if you '
                              'trust this operator and its data policy.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Trust and test'),
                              ),
                            ],
                          ),
                        );
                        if (trusted != true) return;
                      }
                      final id = existing?.id ??
                          name.text
                              .trim()
                              .toLowerCase()
                              .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                      final config = RemoteProviderConfig(
                        id: id,
                        name: name.text.trim(),
                        baseUrl: baseUrl.text.trim(),
                        apiKey: apiKey.text.trim(),
                        modelId: modelId.text.trim(),
                        customHeaders: parsedHeaders,
                        contextLength: parsedContext,
                        supportsVision: supportsVision,
                        supportsTools: supportsTools,
                        streaming: streaming,
                      );
                      final models = await OpenAiCompatibleInferenceService(
                        config,
                      ).listModels();
                      if (!models.any(
                        (model) => model.id == config.selectionId,
                      )) {
                        throw FormatException(
                          'The endpoint did not report model ${config.modelId}.',
                        );
                      }
                      await ref
                          .read(remoteProviderRegistryProvider)
                          .save(config);
                      ref.invalidate(unifiedModelsProvider);
                      await _loadRemoteProviders();
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (error) {
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Provider validation failed: $error'),
                          backgroundColor:
                              Theme.of(dialogContext).colorScheme.error,
                        ),
                      );
                    }
                  },
                  child: const Text('Test and save'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      name.dispose();
      baseUrl.dispose();
      apiKey.dispose();
      modelId.dispose();
      headers.dispose();
      contextLength.dispose();
    }
  }

  @override
  void dispose() {
    _ollamaUrlController.dispose();
    _serverPortController.dispose();
    super.dispose();
  }

  Future<void> _toggleLocalApiServer(bool enabled) async {
    final server = ref.read(openAiServerServiceProvider);
    if (!enabled) {
      await server.stopServer();
      if (mounted) setState(() {});
      return;
    }
    final port = int.tryParse(_serverPortController.text);
    if (port == null || port < 0 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid TCP port (0–65535).')),
      );
      return;
    }
    if (!_serverLocalhostOnly) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Expose API on the local network?'),
          content: const Text(
            'Other devices may reach PocketLLM on this port. Keep the API key '
            'private, use a trusted network, and configure your device firewall.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Expose with API key'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await server.startServer(
        OpenAiServerConfig(
          enabled: true,
          port: port,
          localhostOnly: _serverLocalhostOnly,
        ),
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Local API server could not start: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _updateOllamaEndpoint(String newUrl) async {
    final storage = ref.read(storageServiceProvider);
    final normalizedUrl = newUrl.trim();
    if (!UrlValidator.isHttpUrlString(normalizedUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid HTTP or HTTPS URL.')),
      );
      return;
    }
    final uri = Uri.parse(normalizedUrl);

    final isLoopback = NetworkPolicyService().isLoopback(uri);

    if (!isLoopback) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              const Text('Remote Endpoint Warning'),
            ],
          ),
          content: Text(
            'You are connecting to a remote Ollama server at:\n\n$newUrl\n\n'
            'Chat messages and prompt content will be transmitted across your local network or the Internet to this host. '
            'Ensure you trust this server operator.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I Trust & Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        final urlVal = storage.getSetting(
          AppConstants.ollamaBaseUrlKey,
          defaultValue: AppConstants.defaultOllamaBaseUrl,
        );
        _ollamaUrlController.text =
            urlVal is String ? urlVal : AppConstants.defaultOllamaBaseUrl;
        return;
      }
    }

    ref.read(ollamaServiceProvider).updateBaseUrl(normalizedUrl);
    await storage.saveSetting(AppConstants.ollamaBaseUrlKey, normalizedUrl);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated Ollama endpoint to $normalizedUrl')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);
    final networkService = NetworkPolicyService();
    final localApiServer = ref.watch(openAiServerServiceProvider);

    final strictOfflineVal = storage.getSetting(
      AppConstants.strictOfflineModeKey,
      defaultValue: false,
    );
    final strictOffline = strictOfflineVal is bool ? strictOfflineVal : false;

    final autoUpdateVal = storage.getSetting(
      AppConstants.autoUpdateCheckKey,
      defaultValue: false,
    );
    final autoUpdate = autoUpdateVal is bool ? autoUpdateVal : false;

    final onlineModelsVal = storage.getSetting(
      AppConstants.onlineModelBrowsingKey,
      defaultValue: true,
    );
    final onlineModels = onlineModelsVal is bool ? onlineModelsVal : true;

    final tavilyEnabledVal = storage.getSetting(
      AppConstants.tavilySearchEnabledKey,
      defaultValue: true,
    );
    final tavilyEnabled = tavilyEnabledVal is bool ? tavilyEnabledVal : true;

    final githubSkillsVal = storage.getSetting(
      AppConstants.githubSkillsEnabledKey,
      defaultValue: true,
    );
    final githubSkillsEnabled =
        githubSkillsVal is bool ? githubSkillsVal : true;

    final ollamaUrlVal = storage.getSetting(
      AppConstants.ollamaBaseUrlKey,
      defaultValue: AppConstants.defaultOllamaBaseUrl,
    );
    final currentOllamaUrl = ollamaUrlVal is String
        ? ollamaUrlVal
        : AppConstants.defaultOllamaBaseUrl;

    final ollamaUri = Uri.tryParse(currentOllamaUrl) ??
        Uri.parse(AppConstants.defaultOllamaBaseUrl);
    final isOllamaLocal = networkService.isLoopback(ollamaUri);

    return Scaffold(
      appBar: const M3AppBar(title: 'Privacy & Network Centre'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status Banner ──
          Card(
            color: strictOffline
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: fieldDecoration(theme),
            ),
          ),
          const SizedBox(height: 16),

          // ── Strict Offline Mode ──
          Card(
            child: SwitchListTile(
              secondary: Icon(
                Icons.cloud_off_rounded,
                color: strictOffline
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              title: const Text('Strict Offline Mode',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(
                'Blocks every non-loopback connection at application level. No external network request will be permitted.',
              ),
              value: strictOffline,
              onChanged: (val) async {
                await storage.saveSetting(
                    AppConstants.strictOfflineModeKey, val);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Ollama Server Endpoint ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dns_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ollama destination',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isOllamaLocal ? 'On device' : 'Network host',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isOllamaLocal
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ollamaUrlController,
                    decoration: InputDecoration(
                      labelText: 'Ollama Base URL',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check_circle_rounded),
                        onPressed: () =>
                            _updateOllamaEndpoint(_ollamaUrlController.text),
                      ),
                    ),
                    onSubmitted: _updateOllamaEndpoint,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOllamaLocal
                        ? 'Local inference: Prompts stay on your machine.'
                        : 'Remote inference: Prompts sent to $currentOllamaUrl',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Generic OpenAI-compatible providers ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hub_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'OpenAI-compatible providers',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: strictOffline
                            ? null
                            : () => _showRemoteProviderDialog(),
                        tooltip: 'Add provider',
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  Text(
                    'Optional endpoints such as LM Studio, llama.cpp, vLLM, '
                    'SGLang, LocalAI, Groq, or private gateways. Credentials '
                    'and headers are stored in secure storage.',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (_remoteProviders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('No remote providers configured.'),
                    )
                  else
                    ..._remoteProviders.map(
                      (provider) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.cloud_outlined),
                        title: Text(provider.name),
                        subtitle: Text(
                          '${provider.modelId}\n${provider.baseUrl}',
                        ),
                        isThreeLine: true,
                        onTap: strictOffline
                            ? null
                            : () => _showRemoteProviderDialog(
                                  existing: provider,
                                ),
                        trailing: IconButton(
                          tooltip: 'Delete provider',
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () async {
                            await ref
                                .read(remoteProviderRegistryProvider)
                                .delete(provider.id);
                            ref.invalidate(unifiedModelsProvider);
                            await _loadRemoteProviders();
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.api_rounded),
                    title: const Text('OpenAI-compatible local API'),
                    subtitle: Text(
                      localApiServer.isRunning
                          ? 'Listening on ${_serverLocalhostOnly ? "127.0.0.1" : "0.0.0.0"}:${localApiServer.boundPort}'
                          : 'Expose actual PocketLLM models through /v1/models, '
                              '/v1/chat/completions, and /v1/embeddings.',
                    ),
                    value: localApiServer.isRunning,
                    onChanged: _toggleLocalApiServer,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _serverPortController,
                          enabled: !localApiServer.isRunning,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Port',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('Localhost only'),
                          value: _serverLocalhostOnly,
                          onChanged: localApiServer.isRunning
                              ? null
                              : (value) => setState(
                                    () => _serverLocalhostOnly = value,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  if (localApiServer.isRunning &&
                      localApiServer.activeApiKey != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.key_rounded),
                      title: const Text('Server API key'),
                      subtitle: const Text(
                        'Stored securely. Tap copy; do not share it in logs or screenshots.',
                      ),
                      trailing: IconButton(
                        tooltip: 'Copy API key',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text: localApiServer.activeApiKey!,
                            ),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('API key copied.')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Transparent Feature Permission Toggles ──
          Text('External Connections & Services',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.system_update_rounded),
                  title: const Text('Automatic GitHub Update Check'),
                  subtitle: const Text(
                      'Checks GitHub Releases for new APK builds (Default: Off). Sends no user content.'),
                  value: autoUpdate,
                  onChanged: strictOffline
                      ? null
                      : (val) async {
                          await storage.saveSetting(
                              AppConstants.autoUpdateCheckKey, val);
                          setState(() {});
                        },
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.explore_rounded),
                  title: const Text('Hugging Face Model Discovery'),
                  subtitle: const Text(
                      'Allows searching and downloading GGUF models from huggingface.co'),
                  value: onlineModels,
                  onChanged: strictOffline
                      ? null
                      : (val) async {
                          await storage.saveSetting(
                              AppConstants.onlineModelBrowsingKey, val);
                          setState(() {});
                        },
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.search_rounded),
                  title: const Text('Tavily Web Search'),
                  subtitle: const Text(
                      'Sends user search queries to api.tavily.com when web search is enabled.'),
                  value: tavilyEnabled,
                  onChanged: strictOffline
                      ? null
                      : (val) async {
                          await storage.saveSetting(
                              AppConstants.tavilySearchEnabledKey, val);
                          setState(() {});
                        },
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.extension_rounded),
                  title: const Text('GitHub Skill Installation'),
                  subtitle: const Text(
                      'Downloads skill Markdown manifests from GitHub user repositories.'),
                  value: githubSkillsEnabled,
                  onChanged: strictOffline
                      ? null
                      : (val) async {
                          await storage.saveSetting(
                              AppConstants.githubSkillsEnabledKey, val);
                          setState(() {});
                        },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.font_download_off_rounded),
                  title: const Text('Network Fonts Status'),
                  subtitle: const Text(
                      'Disabled runtime fetching. Fonts are strictly bundled local assets.'),
                  trailing: Chip(
                    label: const Text('Local Assets Only'),
                    backgroundColor: theme.colorScheme.secondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── External Connection Audit History ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'Network audit',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                onPressed: () => setState(() {}),
              ),
            ],
          ),
          Text(
            'Allowed and blocked connection attempts only. General app actions are recorded separately in Activity History.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<NetworkAuditEntry>>(
            stream: networkService.auditLogStream,
            initialData: networkService.auditLog,
            builder: (context, snapshot) {
              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'No external connections recorded in this session.'),
                  ),
                );
              }
              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length > 20 ? 20 : logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        log.allowed
                            ? Icons.check_circle_outline_rounded
                            : Icons.block_rounded,
                        color: log.allowed
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        size: 20,
                      ),
                      title: Text('${log.domain} (${log.purpose})'),
                      subtitle: Text(
                          '${log.trigger} • Sent: ${log.infoSent}${log.blockReason != null ? " • ${log.blockReason}" : ""}'),
                      trailing: Text(
                        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget fieldDecoration(ThemeData theme) {
    final strictVal = ref.read(storageServiceProvider).getSetting(
          AppConstants.strictOfflineModeKey,
          defaultValue: false,
        );
    final strict = strictVal is bool ? strictVal : false;
    return Row(
      children: [
        Icon(
          strict ? Icons.shield_rounded : Icons.security_rounded,
          size: 32,
          color: strict
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strict
                    ? 'Strict Offline Mode Active'
                    : 'Local-First Inference Active',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                strict
                    ? 'All outbound non-loopback connections are blocked.'
                    : 'Chats remain local when using on-device or local Ollama endpoints.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
