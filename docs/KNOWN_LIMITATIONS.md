# Known Limitations

Applies to PocketLLM Lite v1.0.37.

- Local model compatibility, quality, speed, and memory use depend on the exact file, quantization, context, backend, device, and thermal state. A valid GGUF header is not a compatibility guarantee.
- Automatic task-based model routing and hardcoded model-family profiles were removed. Model switching is manual until verified manifests and measured load results can support reliable routing.
- Image attachment is available only when the selected local manifest or configured remote provider explicitly confirms vision input. Ollama's tags response does not establish this capability, so PocketLLM fails closed there.
- Android device telemetry measures RAM, storage, ABI, CPU cores, battery, and thermal status where APIs expose them. Cross-vendor GPU/NPU evidence and several iOS measurements remain unavailable and display as unknown.
- Android OCR uses the bundled ML Kit Latin recognizer. iOS OCR, additional scripts, table reconstruction, and OCR of scanned PDF pages are not enabled.
- Text PDFs, TXT, Markdown, and CSV are supported. Encrypted, malformed, or image-only PDFs return errors; layout/table preservation is best effort.
- Keyword retrieval works without an embedding model. Semantic and hybrid retrieval require one of the verified Cactus embedding catalog entries to be installed; model compatibility and download availability still depend on the upstream catalog and device.
- Model and embedding downloads retain validated partial files and durable task records across restart, but an interrupted transfer resumes when the user retries it; the app does not keep a background network worker alive after the process is terminated.
- Audio transcription requires an installed compatible Cactus Whisper bundle. The current SDK path returns transcript text and runtime metrics but not verified segments, timestamps, diarization, summaries, or task extraction.
- Cactus Flutter 1.3 is archived upstream as of July 2026. Telemetry is disabled and the dependency is isolated behind adapters, but maintenance and future Android/iOS compatibility are risks.
- Tool reminders compile and schedule through the OS with permission and reboot receivers, but delivery varies with OEM background restrictions and was not verified on a physical device. Inexact scheduling may not fire at the exact second.
- Tool-created notes are persistent and backed up but do not yet have a dedicated note-management screen.
- The canonical tool representation is model-independent JSON with a legacy XML adapter. Dedicated Qwen/LFM prompt-template adapters are not shipped because the installed backend does not yet expose verified per-model template metadata.
- Qwen3.5, LFM2.5, Gemma 3n, SmolLM3, BGE small, and EmbeddingGemma were researched but are not bundled or compatibility-certified. Official upstream format/benchmark claims do not prove Cactus loading, phone memory fit, templates, projections, or license acceptance in PocketLLM.
- Ollama officially documents macOS, Windows, and Linux. PocketLLM accepts a user-configured HTTP endpoint, but Android/Termux Ollama builds are community/experimental and are not certified by this project.
- Strict Offline is an application-level boundary, not a device firewall. Loopback is intentionally allowed. OS components invoked after an allowed action, such as the package installer, browser, or email composer, are outside PocketLLM's transport.
- The embedded OpenAI-compatible server supports authenticated models, chat, SSE, and embeddings with in-app host/port/start controls. It does not yet implement trusted-host or configurable CORS allowlists; LAN mode therefore shows a warning.
- Legacy plaintext JSON import remains for compatibility. New `.pllm` backups use authenticated encryption and application-level rollback, but an OS/process kill during low-level file replacement cannot provide a database-wide ACID guarantee.
- No production Android signing key is configured in this checkout. A release-mode debug-signed artifact may be used for engineering verification only and must not be published as the production upgrade.
- Physical-phone local inference, Whisper quality, reminder delivery, Bluetooth/audio behavior, low-memory pressure, and upgrade preservation were not available for final verification.
