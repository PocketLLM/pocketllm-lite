# Contributing to PocketLLM Lite 🚀

First off, thank you for considering contributing to PocketLLM Lite! It's people like you who make it a great tool for the local AI community.

## 🏗️ Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable channel)
- [Dart SDK](https://dart.dev/get-started/sdk)
- [Ollama](https://ollama.ai/) (For local testing)

### Setup
1. **Fork the repository** on GitHub.
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/pocketllm-lite.git
   ```
3. **Install dependencies**:
   ```bash
   flutter pub get
   ```
4. **Generate code** (Hive adapters and other generated files):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

## 🛠️ Development Workflow

1. **Create a branch**:
   ```bash
   git checkout -b feature/amazing-feature
   ```
2. **Make your changes**. Ensure you follow the project's coding style and architecture.
3. **Run tests**:
   ```bash
   flutter test
   ```
4. **Commit your changes**:
   ```bash
   git commit -m "feat: add an amazing feature"
   ```
5. **Push to your fork**:
   ```bash
   git push origin feature/amazing-feature
   ```
6. **Open a Pull Request**.

## 🎨 Coding Standards
- Use `flutter_lints` and follow the official [Dart Style Guide](https://dart.dev/guides/language/evolutionary-style).
- Ensure all new features are accompanied by relevant tests.
- Keep UI components reusable and follow Material 3 guidelines.

## 🐞 Bug Reports & Feature Requests
- Use the provided GitHub issue templates.
- Be as descriptive as possible. For bugs, include steps to reproduce and device information.

## 📜 License
By contributing, you agree that your contributions will be licensed under its [MIT License](LICENSE).
