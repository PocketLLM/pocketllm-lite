# Changelog

All notable changes to PocketLLM - Lite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Versioning Guide
We use a specific versioning pattern:
- Increment the 3rd number (patch) by 1 for each update.
- The 3rd number goes up to 100 (e.g., 1.0.99 -> 1.0.100).
- Once the 3rd number reaches 100, the next version resets it to 0 and increments the 2nd number (minor). For example: 1.0.100 becomes 1.1.0.
- Similarly, 1.1.100 becomes 1.2.0.

## [1.0.30] - 2026-07-04

### Added
- **Model Loading Status Indicator**: Introduced a dynamic loading message (*Loading model, please wait...*) in the chat bubble during offline local model initialization, providing clear visual feedback when a model is being loaded into memory.

## [1.0.29] - 2026-07-04

### Added
- **Dynamic Model Selection for Benchmark**: Replaced the static, non-interactive "Active Model" header card on the Inference Benchmark screen with a fully interactive model selector dropdown. Users can now choose any local GGUF model or connected Ollama instance to test against.

### Changed
- **Fixed Empty State Overflow**: Removed the height-constrained `SizedBox` wrapping the benchmark history's `M3EmptyState` widget, preventing a RenderFlex vertical layout crash when the device height is restricted.

## [1.0.28] - 2026-07-04

### Changed
- **Bypassed Connection Prompts for Local Models**: Completely bypassed the "Ollama Not Connected" check popup and SnackBar alert when a local downloaded model is selected, allowing full offline messaging and offline prompt enhancement.
- **Fixed App Bar Dropdown Overflows**: Wrapped the dropdown title selector in a `ConstrainedBox` capped at 180px and set `isExpanded: true` on `DropdownButton` to automatically truncate long model names with an ellipsis, preventing RenderFlex horizontal layout crashes.

## [1.0.27] - 2026-07-04

### Added
- **Unified Chat Model Selector**: Created a single unified dropdown menu in the chat app bar that displays both local downloaded GGUF models and active Ollama servers. Features clear visual icons (`📁` for local, `☁️` for cloud/remote) and highlights if a model is currently loaded in RAM.
- **On-demand RAM Auto-loading**: Selecting a local downloaded model from the chat dropdown automatically triggers background memory mapping and RAM preparation context during generation, removing the need to manually load models via the catalog before chatting.

### Changed
- **Dio Custom GGUF Downloader**: Replaced `background_downloader` package dependencies with a standard `Dio`-based stream downloader inside `ModelDownloadService`, delivering accurate download speeds, progress percentages, and time-remaining calculations.
- **Disabled Cancel Button for Catalog Downloads**: Greyed-out/disabled the download "Cancel" button for Cactus catalog models, as the SDK doesn't natively support download cancellation, leaving it active only for custom GGUFs.

### Removed
- **Removed background_downloader dependency**: Cleaned up and removed the `background_downloader` package and all its associated vestigial listener, tracking, and startup cleanup code from the notifier systems.

## [1.0.26] - 2026-07-04

### Added
- **Dynamic Cactus AI Engine**: Replaced the fake FFI service and mock completion loop with a genuine Cactus SDK integration (`CactusLM`), enabling true on-device LLM inference.
- **Dynamic Model Discovery**: Integrated dynamic model catalog queries directly from the Cactus edge API (`Supabase.fetchModels`), automatically aligning names, capabilities, and file sizes with supported device slugs.

### Changed
- **Unified Local Storage**: Re-routed local model directories to target the documents `models/` sandbox folder, aligning custom imports and downloaded zip packages under a single unified path.
- **Robust Download Pipeline**: Migrated the download manager to Cactus native downloads, adding an automated watchdog timer to recover from stuck states and clear stalled download flags after 45 seconds of silence.
- **Accurate Model Performance Metrics**: Switched the catalog inference test dialog to execute live on-device Cactus generation, returning genuine prompt latency (time-to-first-token) and tokens-per-second values.

### Removed
- **Fake FFI simulator and Native Build Chains**: Removed the canned-response simulation FFI code, the unused `android/app/CMakeLists.txt` build configuration, and the native iOS `pocketllm_lite.podspec` helper.

## [1.0.25] - 2026-05-25

### Added
- **Interactive Model Catalog Dashboard**: Wrapped model catalog list items in inkwell tap handlers to launch an expressive Material 3 details sheet displaying family, provider, file size, key capabilities, and standardized benchmarks.
- **Reactive Background Downloader Pipeline**: Refactored download tasks to execute as non-blocking `FileDownloader().enqueue(...)` background threads, and monitored status/progress dynamically using a reactive global stream.
- **System Notification Tray Progress**: Enabled dynamic native system notifications with active progress indicators during model downloads and completion alerts when the task finishes.
- **Method Channel Resiliency**: Added generic catch blocks to eliminate `MissingPluginException` errors, providing smooth, robust, fail-open fallback storage limits across all systems.

## [1.0.24] - 2026-05-25

### Added
- **Android APK Installer Permission Guard**: Explicitly checks and requests `REQUEST_INSTALL_PACKAGES` permission at runtime before starting in-app updates, with direct settings redirection (`openAppSettings()`) on refusal to avoid unknown-source blockages.
- **Premium Waveform Loader**: Built a state-of-the-art vertical pill-based loader utilizing staggered mathematical sine wave phase shift functions to create a fluid, beautiful glowing soundwave effect.
- **M3 Expressive Progress HUD**: Transformed the OTA download dashboard to lock and focus, featuring high-fidelity typography, monospace percentage indicators, and a physics-based, glowing gradient progress bar with custom shadows.

## [1.0.23] - 2026-05-25

### Added
- **Native Storage Platform Channels**: Integrated Kotlin `StatFs` and Swift capacity resource value APIs to query actual free storage space on device files directory, completely resolving `MissingPluginException`.
- **Settings Screen Re-Architecting**: Grouped 20+ fine-grained configuration widgets into 6 beautifully styled logical sub-page dashboards (Prompts/Templates, Models/Inference, Knowledge/Search, Chats/Data, Appearance/Themes, System/Diagnostics), making the main dashboard clean and clutter-free.
- **M3 Expressive Navigation List**: Placed categories inside a clean, modern vertical list layout without unnecessary cards, maximizing responsive whitespace and touch targets.

## [1.0.22] - 2026-05-24

### Added
- **Native llama.cpp Build Chains**: Configured `CMakeLists.txt` for Android NDK and a robust Metal-enabled CocoaPods `pocketllm_lite.podspec` for accelerated iOS execution.
- **Atomic Dio Storage System**: Built a modular, chunked downloader inside `ModelStorageService` that writes to a temporary file before atomically renaming to prevent file corruption.
- **Custom GGUF File Importers**: Native-scoped document selector picker and a custom magic byte-level verification check validating selected models before sandboxed import.
- **Local RAM Loader HUD**: Modern Material 3 model catalog screen to browse default models (Llama 3.2 1B/3B, Gemma 2, Qwen 2.5, Phi 3.5), view storage, and load/unload models on-demand.
- **WidgetsBindingObserver Protection**: Active system-wide memory warning listeners that automatically purge loaded models to protect mobile OS processes from low-memory crashes.

## [1.0.21] - 2026-05-24

### Added
- **Tavily Web Search Integration**: Built a robust native HTTP-based `web_search` tool calling handler inside `ToolCallingService` to query Tavily API for live internet references.
- **Web Search Toolbar Toggle**: Embedded a sleek browser globe toggle button (`Icons.language_rounded`) in the chat input bar.
- **Tavily API Key Verification**: Added a modern dialog prompting the user to configure their Tavily API key in the settings before using the web search feature.
- **Premium Shimmering Indicator**: Integrated a premium shimmering `🔍 Searching the web...` message bubble during live Tavily searches.
- **Inline Markdown Citations**: Conditioned local LLM prompts to cite search references using standard clickable Markdown links.

### Changed
- **Branding Update**: Replaced all existing logo assets with the new updated PocketLLM Lite design (`assets/logo.png`, website logos, and centered README header logo).
- **GitHub Actions Removal**: Completely removed the `.github/` folder and release workflows since builds and releases are handled locally, ensuring zero overhead in CI pipelines.

## [1.0.20] - 2026-05-24

### Added
- **Agent Skills (SKILL.md) System**: Comprehensive support to manage and execute custom AI skills following standard frontmatter & markdown formats.
- **GitHub URL Skill Installer**: Native capability to download, parse, preview, and install skills directly from any GitHub or raw SKILL.md URL.
- **Manual Skill CRUD**: Beautiful modal form interfaces to create, read, edit, enable/disable, and delete custom skills locally.
- **Smart Chat Input Autocomplete**: Real-time popups with horizontal Material 3 recommendation cards of matched skills as the user types `/`.
- **In-Input Highlight & Navigation**: Automatically highlights `/skill_id` in bold blue inside the text input field, and redirects the user to the skill details screen if tapped.
- **Inter-Bubble Clickable Badges**: Preprocesses message content for skill commands, rendering them as interactive clickable badges in both user and assistant conversation bubbles.
- **Dynamic Turn-Based LLM Conditioning**: Scans user query messages, fetches matching active skill instructions, and appends them to the system instructions dynamically before executing inference.

## [1.0.19] - 2026-05-18

### Fixed
- **Local LLM Model Load Timeout**: Increased the HTTP apiConnectionTimeout to 120 seconds and apiGenerationTimeout to 180 seconds in AppConstants. This prevents the client-side socket from aborting requests early when local LLMs (like Gemma or Llama) take more than 10 seconds to spin up, allocate layers, and offload to CUDA/CPU.

## [1.0.18] - 2026-05-18

### Fixed
- **CI/CD SDK animations Compatibility**: Downgraded the `animations` package version to `^2.0.11`. This avoids the newer `animations 2.2.0` package which strictly requires a Dart SDK of `^3.9.0` (causing build failure on the runner's Dart SDK 3.6.0 environment).

## [1.0.17] - 2026-05-18

### Fixed
- **CI/CD Build System Dependency Compatibility**: Broadened the `intl` package version constraint to `">=0.19.0 <0.21.0"`. This resolves a version solver conflict in the GitHub Actions runner where the runner's Flutter SDK has `flutter_localizations` pinned to `intl 0.19.0`, while keeping support for `intl 0.20.2` in local development environment.

## [1.0.16] - 2026-05-18

### Added
- **Immediate Generation Loading Indicator**: Configured the chat timeline to render the assistant's typing indicator bubble (pulsing three bouncing dots animation) immediately from the moment the prompt is sent, rather than waiting for the first token stream to arrive. This provides seamless offline visual feedback to the user during local model loading and context processing.

### Changed
- **Clean Model Dropdown UI**: Removed the `smart_toy` robot icon inside the top app bar's model dropdown button and popups, displaying a clean, minimal text representation showing only the name of the active local LLM model.

## [1.0.15] - 2026-05-18

### Changed
- **Gemini-Style Personalized Empty State**: Refactored the empty chat screen to use a personalized "Hi [Name], what's on your mind?" header, which dynamically adjusts to the user's name set in Profile settings, or falls back to "Hi, what's on your mind?".
- **Premium Suggestion Cards**: Replaced old wrap-style suggestion chips with a clean vertical list of high-fidelity rounded card containers with modern sparkle search icons, matching the sleek Gemini-inspired design mockup.

## [1.0.14] - 2026-05-18

### Changed
- **SST Dictation & Waveform Relocation**: Relocated the dynamic voice input waveform animation next to the microphone icon in the bottom toolbar row. This keeps the primary message TextField always visible during Speech-to-Text, allowing real-time transcription/dictation to be visible in the main chat input field as the user speaks.

## [1.0.13] - 2026-05-18

### Changed
- **Premium Capsule Chat Input**: Completely refactored the chat input to a floating rounded capsule container (`BorderRadius.circular(28)`) with minimalist outline action buttons, a sleek contrast 40x40 circular send button (`Icons.send_rounded`), and a center-aligned interactive disclaimer block (`This is A.I. and not a real person...`) as shown in the design mockup.
- **Embedded Persona Quick-Picker**: Added a dynamic, clickable persona indicator displaying the active emoji avatar that opens a custom modal bottom sheet selection panel for instant active persona swaps.

## [1.0.12] - 2026-05-18

### Added
- **Dynamic Persona System**: Premium architecture to create, edit, and use AI personas with distinct custom emoji avatars, system instructions, temperature overrides, and default model associations.
- **Horizontal Persona Picker HUD**: Implemented an elegant scrollable selector HUD at the top of empty chat states for lightning-fast persona switches with haptic selections.
- **Native Tool/Function Calling System**: Built a robust native `ToolCallingService` allowing local models to query local math calculators, search system/time info, and browse simulated mock offline knowledge databases.
- **Adaptive Tool UI Cards**: Beautiful custom Material 3 cards rendered within the chat list to visualize tool calls and returning response data dynamically.
- **Multi-Model Thinking Accordion Parsing**: Integrated a universal thinking token parser capable of handling `<think>`, `<thought>`, `<thinking>`, `[thought]` blocks, and custom CoT headers across any open-source model (DeepSeek, Gemma, Kimi, etc.).

## [1.0.11] - 2026-05-18

### Added
- **Ad-Free Privacy Focus**: Aggressively purged all legacy Google Mobile Ads monetization SDK dependencies, rewarded triggers, and banner constraints for a pure privacy-first offline experience.
- **DeepSeek R1 thinking parsing & UI rendering**: Added direct stream parsing for <think> tags and a beautifully designed collapsible reasoning bubble with live-pulsing state transitions.
- **Knowledge Base RAG Toggle**: Integrated a document augmentation toggle inside the Chat Settings dialog to query local vector stores.
- **Interactive Performance Benchmarker**: Built a beautiful M3 screen to profile, graph, and compare generation speeds (tokens/sec) and Time to First Token (TTFT) latency.
- **Offline Text-to-Speech (TTS)**: Added a "Speak/Stop" action chip to any message bubble to read AI responses aloud.
- **Speech-to-Text (STT) Voice Input**: Integrated voice typing directly into the Chat Input bar with a premium pulsing mic feedback loop.

## [1.0.10] - 2026-02-18

### Added
- **System Prompt Management**: Dedicated screen to create, save, and select different system prompts.
- **Usage Statistics Dashboard**: Visual breakdown of token usage and model activity.
- **Advanced Appearance Settings**: 
  - Live preview for chat bubble customization.
  - Granular control over font sizes and border radius.
  - New preset themes.

### Changed
- **Material 3 Expressive Redesign**: Refactored entire application to strictly follow Material 3 design principles.
- **M3 Elements**: Replaced all legacy `AppBar`s with the new `M3AppBar` component for consistent headers.
- **Theming**: Replaced hardcoded colors in dialogs, menus, and widgets with dynamic theme-aware colors (`ColorScheme`).
- **Standardization**: Unified styling across all Settings sub-pages, Tag Management, and Profile screens.
- **Build System**: Improved Android release build configuration (robust keystore handling).

### Fixed
- **Code Quality**: Fixed various lint issues including unused imports and async context usage.

## [1.0.9] - 2026-01-20

### Added
- **In-App Updates**: Users can now update the app directly from GitHub releases without leaving the app
- **Auto-Update Check**: App automatically checks for updates on launch (can be disabled in Settings > Updates)
- **Manual Update Check**: Added "Check for Updates Now" option in Settings
- **Update Dialog**: Beautiful Material 3 update dialog showing changelog and download progress
- **Version Skip**: Users can skip a specific version if they don't want to update
- **GitHub Releases Page**: Direct link to view all releases in Settings

### Changed
- Improved ad loading with better retry logic and refresh controls
- Updated banner ad size configuration for better reliability
- Enhanced ad service error handling and test device configuration
- Fixed typo in Flutter build command in README

### CI/CD
- Added GitHub Actions workflow for automatic bi-weekly releases
- Workflow runs on 1st and 15th of every month
- Supports manual trigger with version type selection (major/minor/patch)
- Automatic changelog generation from git commits
- APK automatically signed and uploaded to GitHub Releases

### Security
- Added REQUEST_INSTALL_PACKAGES permission for APK installation
- Implemented FileProvider for secure file sharing during updates

## [1.0.2] - 2026-01-15

### Added
- Initial public release
- Offline AI chat using Ollama via Termux
- Vision-capable chat support (Llama 3.2 Vision, Llava)
- Premium customization options
  - Live preview for theme customization
  - Adjustable chat bubble colors and radius
  - Dynamic chat history management
- 15+ system prompt presets
- Interactive UI with haptic feedback
- Full Markdown support for code blocks, tables, and links
- Secure local storage using Hive database

### Features
- Real-time streaming responses from Ollama models
- Multimodal inputs (text and images)
- Prompt Enhancer with AI-powered improvements
- Token-based usage system
- AdMob integration (banner and rewarded ads)
- Theme switching (light/dark/system)

---

## Download

You can download the latest APK from [GitHub Releases](https://github.com/PocketLLM/pocketllm-lite/releases).

## In-App Updates

Starting from v1.0.9, the app supports in-app updates:

1. When you open the app, it will check for new versions automatically
2. If an update is available, you'll see a dialog with release notes
3. Tap "Download & Install" to update directly in the app
4. You may need to enable "Install from unknown sources" for your device

To disable automatic update checks, go to **Settings > Updates** and toggle off "Auto-check for Updates".
