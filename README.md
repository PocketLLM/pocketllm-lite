<p align="center">
  <img src="assets/logo.png" alt="PocketLLM Lite logo" width="140" />
</p>

# PocketLLM Lite

**Local-first AI. Offline when you want it. Network access only when you allow it.**

[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter)](https://flutter.dev)
[![Version](https://img.shields.io/badge/version-1.0.36-6750A4)](CHANGELOG.md)

PocketLLM Lite is a Flutter assistant for running supported models on your device with Cactus, or connecting to an Ollama server you control. Chats, preferences, personas, skills, and memories are stored locally. Optional model discovery, downloads, updates, GitHub skill installs, and Tavily search use the network only when their privacy controls allow it.

## What works in v1.0.36

- Streaming local chat through Cactus and loopback/LAN Ollama adapters.
- Persistent chat history, personas, prompts, skills, tags, settings, and local memories.
- PDF, TXT, Markdown, and CSV document ingestion with source-aware retrieval.
- Canonical JSON tool calls with strict argument validation, bounded execution, safe arithmetic, system time information, and policy-gated Tavily search.
- Hugging Face GGUF search, gated-repository token storage, file selection, and model downloads.
- On-device Android OCR using ML Kit Latin text recognition.
- On-device Whisper transcription through Cactus; the model is downloaded on first use when policy permits.
- Password-derived AES-256-GCM backups that reject wrong passwords and corruption.
- An authenticated, loopback-first OpenAI-compatible server for models, chat completions, SSE streaming, and embeddings.
- Strict Offline controls and a network audit log for app-owned update, discovery, download, skill, search, and remote-inference paths.
- Material 3 light/dark themes and six localization resource sets.

## Local and optional online behavior

Local inference, local files, memories, and persisted chats do not require a cloud account. These features can use the network when enabled:

| Feature | Destination | Data category |
|---|---|---|
| Hugging Face browser/download | `huggingface.co` | Search terms, model IDs, optional access token |
| Tavily web search | `api.tavily.com` | Search query and API key |
| GitHub skill install | User-selected GitHub/raw URL | Skill URL |
| Update check | GitHub Releases API | App version and HTTP metadata |
| Ollama / remote endpoint | User-configured host | Prompts and model responses |

Strict Offline blocks non-loopback requests before application-owned HTTP I/O. Loopback is allowed so a local Ollama server remains usable; review the network center before enabling LAN endpoints.

## Model setup

### Cactus on-device models

Open the model browser, choose a model returned by the installed Cactus runtime, download it, and load it. Capability labels come from runtime metadata; model availability may change upstream.

### Ollama

1. Start Ollama on the same device or a trusted computer.
2. Pull a model with `ollama pull <model>`.
3. Set the PocketLLM endpoint, normally `http://127.0.0.1:11434` for same-device use.
4. Test the connection before starting a chat.

### Custom GGUF

Import a GGUF file from the model screen. PocketLLM validates the `GGUF` header before copying it into the app model directory. A valid header does not guarantee the installed backend supports that model architecture.

## Development

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze
flutter test
flutter run
```

Release APK command:

```bash
flutter build apk --split-per-abi --release
```

## Known limitations

- Android OCR is implemented; iOS OCR is not enabled in this release.
- Cactus 1.3 transcription returns text and performance metrics, but not verified word/segment timestamps or speaker diarization. PocketLLM does not invent them.
- Cactus model downloads are supplied by the upstream runtime. Availability and compatibility depend on that catalog and the device.
- Android does not expose one reliable cross-vendor GPU/NPU capability probe, so accelerator status may be unknown.
- Large models can still exhaust memory. Hardware recommendations are conservative when measurements are unavailable.
- Physical-device inference, OCR quality, and Whisper speed vary by device and model and are not represented by invented benchmark numbers.
- Encrypted archives are authenticated before import, but the subsequent per-record Hive writes are not one atomic database transaction.
- The OpenAI-compatible server service has verified localhost routes but no in-app start/stop screen in v1.0.36.

See [the v1.0.36 audit](docs/V1_0_36_PRODUCT_AUDIT.md), [verification matrix](docs/V1_0_36_VERIFICATION.md), [known limitations](docs/KNOWN_LIMITATIONS.md), and [security policy](SECURITY.md) for details.

## License status

This repository does not currently contain a license file. No open-source license grant is implied by this README.
