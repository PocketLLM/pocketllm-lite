import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers.dart';
import '../../../../models/network_audit_log.dart';
import '../../../../services/network_policy_service.dart';
import '../../../../core/utils/url_validator.dart';
import '../../../../core/widgets/m3_app_bar.dart';

class PrivacyNetworkScreen extends ConsumerStatefulWidget {
  const PrivacyNetworkScreen({super.key});

  @override
  ConsumerState<PrivacyNetworkScreen> createState() =>
      _PrivacyNetworkScreenState();
}

class _PrivacyNetworkScreenState extends ConsumerState<PrivacyNetworkScreen> {
  final TextEditingController _ollamaUrlController = TextEditingController();

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
  }

  @override
  void dispose() {
    _ollamaUrlController.dispose();
    super.dispose();
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
                      const Text('Inference Endpoint Status',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Chip(
                        avatar: Icon(
                          isOllamaLocal
                              ? Icons.verified_user_rounded
                              : Icons.cell_tower_rounded,
                          size: 16,
                          color: isOllamaLocal
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                        label: Text(
                          isOllamaLocal ? 'Local Loopback' : 'Remote Network',
                          style: TextStyle(
                            color: isOllamaLocal
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: (isOllamaLocal
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.errorContainer)
                            .withValues(alpha: 0.7),
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
              Text('Connection Audit Log', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                onPressed: () => setState(() {}),
              ),
            ],
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
