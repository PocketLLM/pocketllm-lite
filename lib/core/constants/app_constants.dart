class AppConstants {
  static const String appName = 'Pocket LLM Lite';
  static const String defaultOllamaBaseUrl = 'http://127.0.0.1:11434';

  // Hive Boxes
  static const String chatBoxName = 'chats';
  static const String settingsBoxName = 'settings';
  static const String systemPromptsBoxName = 'system_prompts';
  static const String activityLogBoxName = 'activity_logs';
  static const String errorLogBoxName = 'error_logs';
  static const String personasBoxName = 'chat_personas';
  static const String skillsBoxName = 'skills';

  // Keys
  static const String isFirstLaunchKey = 'is_first_launch';
  static const String ollamaBaseUrlKey = 'ollama_base_url';
  static const String themeModeKey = 'theme_mode';
  static const String autoSaveChatsKey = 'auto_save_chats';
  static const String hapticFeedbackKey = 'haptic_feedback';
  static const String defaultModelKey = 'default_model';
  static const String userMsgColorKey = 'user_msg_color';
  static const String aiMsgColorKey = 'ai_msg_color';
  static const String bubbleRadiusKey = 'bubble_radius';
  static const String fontSizeKey = 'font_size';
  static const String pinnedChatsKey = 'pinned_chats';
  static const String archivedChatsKey = 'archived_chats';
  static const String chatTagsKey = 'chat_tags';
  static const String messageTemplatesKey = 'message_templates';
  static const String chatDraftsKey = 'chat_drafts';
  static const String starredMessagesKey = 'starred_messages';
  static const String profileNameKey = 'profile_name';
  static const String profileBioKey = 'profile_bio';
  static const String profileAvatarColorKey = 'profile_avatar_color';
  static const String profileAvatarImageKey = 'profile_avatar_image';

  // Model Settings
  static const String modelSettingsPrefixKey = 'model_settings_';

  // Tavily API Key
  static const String tavilyApiKeyKey = 'tavily_api_key';

  // Network & Privacy Control Keys
  static const String autoUpdateCheckKey = 'auto_update_check';
  static const String onlineModelBrowsingKey = 'online_model_browsing';
  static const String strictOfflineModeKey = 'strict_offline_mode';
  static const String tavilySearchEnabledKey = 'tavily_search_enabled';
  static const String githubSkillsEnabledKey = 'github_skills_enabled';
  static const String autoMemoryExtractionKey = 'auto_memory_extraction';
  static const String networkAuditLogKey = 'network_audit_log_v1';
  static const String localMemoryRecordsKey = 'local_memory_records_v2';
  static const String rollingSummaryPrefixKey =
      'rolling_conversation_summary_v1_';
  static const String modelManifestRegistryKey = 'model_manifest_registry_v1';
  static const String localNotesKey = 'local_notes_v1';

  // New Appearance Keys
  static const String chatPaddingKey = 'chat_padding';
  static const String showAvatarsKey = 'show_avatars';
  static const String bubbleElevationKey =
      'bubble_elevation'; // Use boolean or double?
  static const String msgOpacityKey = 'msg_opacity';
  static const String customBgColorKey = 'custom_bg_color'; // Optional

  // Prompt Enhancer
  static const String promptEnhancerModelKey = 'prompt_enhancer_model';

  // Fixed System Prompt for Enhancer
  static const String promptEnhancerSystemPrompt =
      '''You are an expert prompt engineer. Improve the user's prompt while preserving its intent. Make requirements specific, structured, and testable; add only context that is clearly implied; use delimiters such as headings where useful; and request concise verification rationale when appropriate without asking for hidden chain-of-thought. Output only the enhanced prompt, with no introduction or commentary.''';

  // Security Limits
  static const int maxInputLength = 50000;
  static const Duration apiConnectionTimeout = Duration(seconds: 120);
  static const Duration apiGenerationTimeout = Duration(seconds: 180);
  static const int maxTextFileAttachmentBytes = 200 * 1024;
}
