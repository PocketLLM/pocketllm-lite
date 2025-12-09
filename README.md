# Pocket LLM Lite

A privacy-first, offline AI chat application for Android/iOS, integrating with Ollama via Termux.

## Features
- **Offline AI**: Chats processed locally on-device via Ollama.
- **Vision Support**: Upload images to compatible models (e.g., Llava) for analysis.
- **History**: Local chat history storage using Hive NoSQL database.
- **Privacy**: No data leaves your device.
- **Settings**: Configure Ollama endpoint (default: `http://localhost:11434`) and manage models.

## Setup

### Prerequisites
1. **Flutter SDK** installed.
2. **Android/iOS Device** or Emulator.
3. For local AI on Android: **Termux** app + **Ollama**.

### Termux Setup (Android)
1. Install Termux from F-Droid.
2. Update packages: `pkg update && pkg upgrade`
3. Install Ollama: `pkg install ollama`
4. Start Ollama Server: `ollama serve`
5. In a new Termux session, pull a model (e.g., Llama 3): `ollama run llama3`
6. Keep `ollama serve` running in the background.

### Building the App
1. Clone this repo.
2. Install dependencies: `flutter pub get`
3. Generate Hive adapters: `dart run build_runner build --delete-conflicting-outputs`
4. Run: `flutter run`
5. Build APK: `flutter build apk --release`

## Architecture
- **State Management**: Riverpod (NotifierProvider)
- **Local Database**: Hive (Persistence)
- **Routing**: GoRouter (ShellRoute for Bottom Navigation)
- **Networking**: `http` with Streaming support
- **UI**: Material 3 with Dark/Light mode support

## Project Structure
- `lib/core`: Global constants, theme, router, utilities.
- `lib/features`: Feature-based folders (chat, history, settings, splash).
- `lib/services`: External services (Ollama, Storage).
