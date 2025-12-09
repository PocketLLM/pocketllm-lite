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
}
