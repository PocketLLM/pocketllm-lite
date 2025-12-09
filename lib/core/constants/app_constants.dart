class AppConstants {
  static const String appName = 'Pocket LLM Lite';
  static const String defaultOllamaBaseUrl = 'http://127.0.0.1:11434';

  // Hive Boxes
  static const String chatBoxName = 'chats';
  static const String settingsBoxName = 'settings';
  static const String systemPromptsBoxName = 'system_prompts';

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
  // Test IDs (use these for development)
  static const String admobAppIdAndroid =
      'ca-app-pub-3940256099942544~3347511713';
  static const String admobAppIdIos = 'ca-app-pub-3940256099942544~1458002511';

  // Test Ad Unit IDs (REPLACE with your production IDs from console.google.com/admob)
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

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
}
