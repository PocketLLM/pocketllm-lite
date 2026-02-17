# Changelog

All notable changes to PocketLLM - Lite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-18

### Changed
- **UI Overhaul**: Refactored entire application to strictly follow Material 3 design principles.
- **M3 Elements**: Replaced all legacy `AppBar`s with the new `M3AppBar` component for consistent headers.
- **Theming**: Replaced hardcoded colors in dialogs, menus, and widgets with dynamic theme-aware colors (`ColorScheme`).
- **Standardization**: Unified styling across all Settings sub-pages, Tag Management, and Profile screens.
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
