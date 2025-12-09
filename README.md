# Pocket LLM Lite

A premium, privacy-first, offline AI chat application for Android/iOS, integrating with Ollama via Termux. Experience powerful AI models directly on your device with a beautiful, customizable interface.

## 🚀 Key Features

*   **Offline AI**: Zero data latency. All chats processed locally via Ollama.
*   **Multimedia Support**: Vision-capable chat (e.g., Llama 3.2 Vision, Llava).
*   **Premium Customization**:
    *   **Live Preview**: Theme your chat bubbles, create presets, and adjust corner radius.
    *   **Dynamic Chat History**: Rename, bulk delete, and organize chats.
    *   **System Prompts**: 15+ rich presets (Productivity Coach, Fitness Trainer, etc.).
*   **Interactive UI**: Haptic feedback, smooth animations, and a focused menu for messages.
*   **Markdown Support**: Full rendering for code blocks, tables, and links.
*   **Privacy Centric**: History stored locally using secure Hive database.

## 🛠 Prerequisites

1.  **Flutter SDK** (Channel stable).
2.  **Android Device** (Recommended for Ollama/Termux) or Emulator.
3.  **Termux** (For running Ollama server on Android).

## 📱 Termux & Ollama Setup (Android)

To run the AI engine locally on your phone:

1.  **Install Termux**: Download from F-Droid (Google Play version is outdated).
2.  **Install Ollama**:
    ```bash
    pkg update && pkg upgrade
    pkg install ollama
    ```
3.  **Start Server**:
    ```bash
    ollama serve
    ```
4.  **Download a Model** (Open a new session):
    ```bash
    ollama pull llama3.2    # Or any other model
    ```

**Note**: Ensure `ollama serve` is running in the background while using the app.

## 💻 Build Instructions

1.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
2.  **Generate Code** (required for Hive adapters):
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
3.  **Run Application**:
    ```bash
    flutter run
    ```
4.  **Build Release APK**:
    ```bash
    flutter build apk --release
    ```

## 🏗 Architecture & Tech Stack

*   **Framework**: Flutter (Dart)
*   **State Management**: Riverpod (Providers & Notifiers)
*   **Storage**: Hive (NoSQL, box-based persistence)
*   **Navigation**: GoRouter
*   **Theme**: Material 3 (Dynamic Color Support)
*   **Integration**: Custom HTTP client for Ollama Streaming API

## 📂 Project Structure

```
lib/
├── core/               # Global constants, themes, router
│   ├── constants/      # App-wide constants and presets
│   ├── theme/          # Theme definitions and providers
│   ├── widgets/        # Shared UI components
│   └── router.dart     # Application routing configuration
├── features/           # Feature modules
│   ├── chat/           # Chat logic, UI, and bubbles
│   │   ├── domain/     # Data models and business logic
│   │   └── presentation/ # Screens, widgets, and providers
│   ├── history/        # Chat history management
│   ├── onboarding/     # First-time user experience
│   ├── settings/       # App configuration and customization
│   └── splash/         # Initial loading screen
├── services/           # OllamaService, StorageService
└── main.dart           # Application entry point
```

## 🎯 Core Features

### Chat Interface
- Real-time streaming responses from Ollama models
- Support for multimodal inputs (text and images)
- Interactive message bubbles with copy/share options
- Markdown rendering for rich text formatting
- System prompt integration for specialized behaviors

### Chat History
- Persistent local storage using Hive
- Organize chats with custom names and tags
- Bulk operations for managing multiple conversations
- Search functionality to find specific conversations

### Customization
- Dynamic theme switching (light/dark mode)
- Adjustable chat bubble appearance (colors, radius, opacity)
- Font size customization
- Avatar visibility toggle
- Background color options

### Settings Management
- Ollama endpoint configuration
- Default model selection
- System prompt management
- Privacy controls
- Haptic feedback preferences

### Prompt Enhancer
- AI-powered prompt improvement using any Ollama model
- Fixed system prompt optimized for best enhancement results
- 5 free enhancements per 24 hours (watch ad to unlock more)

## 💰 Monetization (AdMob)

The app includes Google AdMob integration for monetization through banner and rewarded ads.

### Setup for Production

1. **Get AdMob IDs**: Create an account at [AdMob Console](https://admob.google.com/)
2. **Update Constants**: Replace test IDs in `lib/core/constants/app_constants.dart`:
   ```dart
   // Replace these with your production AdMob IDs
   static const String admobAppIdAndroid = 'YOUR_ANDROID_APP_ID';
   static const String bannerAdUnitId = 'YOUR_BANNER_AD_UNIT_ID';
   static const String rewardedAdUnitId = 'YOUR_REWARDED_AD_UNIT_ID';
   ```
3. **Update AndroidManifest**: Replace the test app ID in `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.android.gms.ads.APPLICATION_ID"
       android:value="YOUR_ANDROID_APP_ID"/>
   ```
4. **iOS Setup**: Add `GADApplicationIdentifier` to `ios/Runner/Info.plist`

### Usage Limits
- **Prompt Enhancements**: 5 free per 24 hours, watch rewarded ad for 5 more
- **Token System**: 10,000 initial tokens, watch rewarded ad for +10,000
- **Banner Ads**: Displayed at bottom of Settings screen

**Note**: Test IDs are pre-configured for development. Always use test IDs during development to avoid policy violations.

## ⚙️ Configuration Options

### Ollama Connection
- **Endpoint**: Default `http://127.0.0.1:11434` (configurable in settings)
- **Model Management**: Pull, delete, and list available models
- **API Integration**: Direct HTTP communication with Ollama REST API

### Appearance Settings
- **Theme Mode**: Light/Dark/System preference
- **Chat Styling**: 
  - User/AI message colors
  - Bubble corner radius (0-20)
  - Font size (12-24)
  - Message opacity (0.5-1.0)
  - Bubble elevation (shadow effect)
- **Layout Options**:
  - Chat padding adjustment
  - Avatar visibility toggle
  - Background color customization

### Behavior Settings
- **Auto-save**: Toggle automatic chat saving
- **Haptic Feedback**: Enable/disable tactile responses
- **Default Model**: Set primary model for new chats

## 🔧 Technical Implementation Details

### State Management
The application uses Riverpod for state management with a combination of:
- `NotifierProvider` for complex state logic
- `FutureProvider` for asynchronous data loading
- `StateProvider` for simple state values

### Data Persistence
Hive is used for all local data storage:
- **ChatBox**: Stores chat sessions and messages
- **SettingsBox**: Persists user preferences
- **SystemPromptsBox**: Manages custom system prompts

### Routing
GoRouter with ShellRoute provides:
- Bottom navigation between main sections
- Nested routes for settings sub-screens
- Type-safe navigation with path parameters

### Networking
Custom HTTP client implementation for:
- Streaming responses from Ollama chat API
- Model listing and management
- Connection health checks

## 🧪 Usage Examples

### Starting a Chat
1. Navigate to the Chat tab
2. Select a model from the dropdown
3. Type your message or attach an image
4. Press send to initiate the conversation

### Customizing Appearance
1. Go to Settings > Customization
2. Adjust sliders for bubble radius, font size, and opacity
3. Use color pickers to set message colors
4. Toggle avatar visibility and other layout options

### Managing Chat History
1. Visit the History tab
2. Long-press on chats for bulk operations
3. Use the search bar to find specific conversations
4. Tap the rename icon to customize chat titles

### Configuring Ollama
1. Access Settings > Connection
2. Update the Ollama endpoint URL if needed
3. Select your preferred default model
4. Test the connection to verify settings

## 📱 Platform Support

- **Android**: Primary target platform with Termux integration
- **iOS**: Supported with manual Ollama setup
- **Desktop**: Experimental support via Flutter desktop

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

The MIT License is a permissive open-source license that allows for commercial use, modification, distribution, and patent use, with the only requirement being that the original copyright notice and license text be included in all copies or substantial portions of the software.

## 📞 Support

For support, feature requests, or bug reports, please:
1. Contact the development team
2. Include your platform, Flutter version, and steps to reproduce

## 🙏 Acknowledgments

- Thanks to the Ollama team for enabling local AI inference
- Gratitude to the Flutter community for excellent documentation and packages
- Appreciation to all contributors and early adopters