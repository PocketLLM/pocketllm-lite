# PocketLLM Lite marketing website redesign

This package is designed to drop into the existing `PocketLLM/pocketllm-lite` repository without changing the current static-site deployment model.

## Important: keep your existing logo

[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter)](https://flutter.dev)
[![Version](https://img.shields.io/badge/version-1.0.38-6750A4)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-2E7D32.svg)](LICENSE)

`pocketllm-website/assets/logo.png`

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


```text
pocketllm-lite/
├─ index.html                         ← replace
├─ 404.html                           ← add
├─ pocketllm-website/
│  ├─ styles.css                      ← replace
│  ├─ site.js                         ← add
│  ├─ releases.html                   ← add
│  ├─ changelog.html                  ← add
│  ├─ docs.html                       ← add
│  ├─ privacy.html                    ← replace
│  ├─ terms.html                      ← replace
│  └─ assets/
│     ├─ logo.png                     ← KEEP your existing real logo
│     ├─ hero-local-ai.webp           ← add
│     ├─ workspace-sunrise.webp       ← add
│     ├─ runtime-journey.webp         ← add
│     ├─ cloud-transition.webp        ← add
│     ├─ developer-night.webp         ← add
│     ├─ footer-night.webp            ← add
│     └─ feature-collage.webp         ← add
```

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
