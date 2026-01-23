class AppConstants {
  static const String appName = 'Pocket LLM Lite';
  static const String defaultOllamaBaseUrl = 'http://127.0.0.1:11434';

  // Hive Boxes
  static const String chatBoxName = 'chats';
  static const String settingsBoxName = 'settings';
  static const String systemPromptsBoxName = 'system_prompts';
  static const String activityLogBoxName = 'activity_logs';

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

  // Model Settings
  static const String modelSettingsPrefixKey = 'model_settings_';

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
      '''You are an expert prompt engineer. Your task is to take the user's input text, which is a prompt intended for an AI model, and enhance it by applying best practices: Make it more specific, descriptive, and structured; add context if implied; use delimiters like ### or """ for sections; encourage step-by-step reasoning if appropriate; preserve the original intent. Output ONLY the enhanced prompt text—no introductions, explanations, conclusions, or additional text.''';

  // ============ AdMob Configuration ============
  // App IDs are configured in AndroidManifest.xml (via build.gradle) and Info.plist
  // Pass Unit IDs via --dart-define or use defaults (Test IDs)

  // Production Ad Unit IDs (Defaults to Google Test IDs)
  static const String bannerAdUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const String rewardedAdUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const String deletionRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_DELETION_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const String promptEnhancementRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_ENHANCEMENT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const String chatCreationRewardedAdUnitId = String.fromEnvironment(
    'ADMOB_CHAT_CREATION_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );

  // ============ Usage Limits ============
  // Token System
  static const String tokenBalanceKey = 'token_balance';
  static const String totalTokensUsedKey = 'total_tokens_used';
  static const String lastTokenAdUnlockKey = 'last_token_ad_unlock';
  static const int initialTokenBalance = 10000;
  static const int tokensPerAdWatch = 10000;

  // Prompt Enhancer Limits
  static const String enhancerUsesTodayKey = 'enhancer_uses_today';
  static const String lastEnhancerResetKey = 'last_enhancer_reset';
  static const int freeEnhancementsPerDay = 5;
  static const int enhancementsPerAdWatch = 5;

  // Chat Limits
  static const String totalChatsCreatedKey = 'total_chats_created';
  static const int freeChatsAllowed = 5;
  static const int chatsPerAdWatch = 5;

  // Security Limits
  static const int maxInputLength = 50000;
  static const Duration apiConnectionTimeout = Duration(seconds: 10);
  static const Duration apiGenerationTimeout = Duration(seconds: 30);
}
