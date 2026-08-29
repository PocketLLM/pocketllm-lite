<p align="center">
  <img src="assets/logo.png" alt="PocketLLM Lite logo" width="140" />
</p>

# PocketLLM Lite

**Local-first AI. Offline when you want it. Network access only when you allow it.**

[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter)](https://flutter.dev)
[![Version](https://img.shields.io/badge/version-1.0.38-6750A4)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-2E7D32.svg)](LICENSE)

PocketLLM Lite is a Flutter assistant for running supported models on your device with Cactus, or connecting to an Ollama server you control. Chats, preferences, personas, skills, and memories are stored locally. Optional model discovery, downloads, updates, GitHub skill installs, and Tavily search use the network only when their privacy controls allow it.

## What works in v1.0.38

- Streaming local chat through Cactus and loopback/LAN Ollama adapters.
- Persistent chat history, personas, prompts, skills, tags, settings, and local memories.
- PDF, TXT, Markdown, and CSV document ingestion with source-aware retrieval.
- Canonical JSON tool calls with strict validation, bounded continuation, safe arithmetic, measured system information, and policy-gated Tavily search.
- User-confirmed clipboard, persistent-note, reminder, email-draft, and HTTP(S) browser tools with visible execution cards.
- Hugging Face GGUF search, gated-repository token storage, file selection, and model downloads.
- On-device Android OCR using ML Kit Latin text recognition.
- On-device Whisper transcription with guided, policy-gated installation of the required Cactus model; unmanaged SDK downloads remain disabled.
- Guided prerequisites for Semantic/Hybrid document search and audio transcription show the exact model, catalog source, approximate size, and upstream license before downloading, then resume the interrupted action after verified installation.
- Password-derived AES-256-GCM backups that reject wrong passwords/corruption and roll storage plus document indexes back on restore failure.
- An authenticated, loopback-first OpenAI-compatible server with in-app host, port, key, start/stop, models, chat, SSE, embeddings, and request logs.
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

### Local GGUF with Cactus

Import a local GGUF or select a GGUF file discovered through Hugging Face. PocketLLM verifies the file header, available storage, and a published SHA-256 when source metadata provides one, then records a `ModelManifest`. A successful Cactus load confirms that exact file on the current backend/device; unknown vision, tool, reasoning, and embedding capabilities remain unknown.

The central Model Store also exposes the current Cactus Flutter 1.3 catalog.
Managed bundles download into resumable partial files only when the server proves
range support and supplies an ETag or Last-Modified validator. PocketLLM safely
extracts the archive, validates every GGUF header, and publishes the folder
atomically. If a server ignores a resume request and returns a full HTTP 200
body, PocketLLM restarts from byte zero instead of appending corrupt data.

### Ollama

1. Start Ollama on the same device or a trusted computer.
2. Pull a model with `ollama pull <model>`.
3. Set the PocketLLM endpoint, normally `http://127.0.0.1:11434` for same-device use.
4. Test the connection before starting a chat.

### Custom GGUF

Import a GGUF file from the model screen. PocketLLM validates the `GGUF` header before copying it into the app model directory. A valid header does not guarantee the installed backend supports that model architecture. Image input stays disabled unless the manifest or configured provider explicitly confirms vision support.

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
- Audio transcription requires `whisper-tiny`; the guided setup can install it from the live Cactus catalog. The current API does not expose verified segments, timestamps, or diarization.
- The Cactus Flutter repository was archived upstream in July 2026. PocketLLM disables its telemetry and unmanaged download paths, but long-term backend maintenance remains a risk.
- Android does not expose one reliable cross-vendor GPU/NPU capability probe, so accelerator status may be unknown.
- Large models can still exhaust memory. Hardware recommendations are conservative when measurements are unavailable.
- Physical-device inference, OCR quality, and Whisper speed vary by device and model and are not represented by invented benchmark numbers.
- Restore is validated before mutation and rolls app storage and document indexes back on failure; an OS kill cannot provide database-wide ACID guarantees.
- The OpenAI-compatible server has in-app controls but not trusted-host or configurable CORS allowlists; keep it on loopback unless LAN exposure is understood.
- Tool-created notes have no separate manager screen, and reminder delivery varies with device/OEM background restrictions.

See [the v1.0.36 foundation audit](docs/V1_0_36_PRODUCT_AUDIT.md), [v1.0.38 verification](docs/V1_0_38_VERIFICATION.md), [known limitations](docs/KNOWN_LIMITATIONS.md), and [security policy](SECURITY.md) for details.

## Contributing

PocketLLM Lite is open source under the [MIT License](LICENSE). Bug reports,
device/model compatibility evidence, translations, accessibility fixes,
documentation, tests, and focused code contributions are welcome. Read
[CONTRIBUTING.md](CONTRIBUTING.md), follow the
[community code of conduct](CODE_OF_CONDUCT.md), or browse
[open issues](https://github.com/PocketLLM/pocketllm-lite/issues).
