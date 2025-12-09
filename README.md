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

1.  **Clone Repository**:
    ```bash
    git clone https://github.com/PocketLLM/pocketllm-lite.git
    cd pocketllm-lite
    ```
2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Generate Code** (required for Hive adapters):
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
4.  **Run Application**:
    ```bash
    flutter run
    ```
5.  **Build Release APK**:
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
├── core/            # Global constants, themes, router
├── features/        # Feature modules
│   ├── chat/        # Chat logic, UI, and bubbles
│   ├── settings/    # Appearance, connection, legal
│   └── splash/      # Logic for app initialization
├── services/        # OllamaService, StorageService
└── main.dart
```

## 📜 License

This project is licensed under the MIT License - see the `LICENSE` file for details.
