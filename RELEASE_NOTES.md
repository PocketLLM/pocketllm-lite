# PocketLLM Lite v1.0.36 — Truth & Integration

## Highlights

This release connects previously separate AI paths to one generation pipeline and replaces demonstration results with real execution or an honest unavailable state. It focuses on data safety, runtime evidence, and predictable failure behavior.

## Local inference and models

- Chat, Prompt Enhancer, Prompt Lab, model comparison, and the developer API now share context, memory, retrieval, tools, cancellation, and backend selection.
- Installed local models are real GGUF files with structured manifests. Hugging Face discovery uses published LFS size/SHA metadata when present; downloads check space, checksum, and the GGUF header.
- Ollama supports chat, embeddings, pull progress, and runtime token statistics through its documented APIs.
- Generic OpenAI-compatible providers can be configured and stored securely. Endpoint model discovery must succeed before a remote model becomes selectable.
- Hardcoded model benchmarks, filename-derived capabilities, automatic task routing, and unverified model profiles were removed.

## Memory and documents

- Structured memories persist across restarts, reject common secret patterns, merge duplicates, supersede contradictory facts, and enter chat context only when enabled and relevant.
- PDF, TXT, Markdown, and CSV files produce persistent structure-aware chunks with stable document/page metadata.
- Retrieval uses numeric cosine similarity, Okapi BM25, normalized fusion, and MMR. A generated two-page PDF integration test verifies the correct page citation.
- Image-only/scanned PDFs report that no extractable text was found; scanned-page OCR is not claimed.

## Tools and agent execution

- Canonical JSON tool calls use strict schemas, structured errors, timeouts, multiple calls, a five-round limit, cancellation, and visible call/result cards.
- Calculator and measured system information run locally.
- Clipboard writes, persistent local notes, local notification reminders, email drafts, and HTTP(S) browser launches require one-shot confirmation.
- Reminder scheduling requests OS notification permission, survives reboot through registered receivers, and does not request exact-alarm privileges.
- Tavily web search is explicit, secure-key backed, and blocked by Strict Offline before transport. Canned offline knowledge responses were removed.

## Privacy, security, and recovery

- Cactus telemetry is disabled. Its unmanaged public discovery and model-download paths are not used.
- Tavily and remote-provider secrets use platform secure storage; a legacy plaintext Tavily value is migrated and deleted.
- `.pllm` backup schema 3 uses PBKDF2-HMAC-SHA256 (600,000 iterations) and AES-256-GCM with random salt/nonce. Wrong passwords, tampering, and malformed archives fail before restore.
- Restore covers chats, settings, prompts, personas, skills, memories, local notes, and the document/vector archive, with rollback after injected failure.
- Strict Offline covers app-owned HTTP, Dio downloads, and external URL launches. Loopback remains available for same-device Ollama and the embedded API.
- Direct OTA installation now requires a release APK paired with a valid published SHA-256 checksum. Legacy storage and privileged install permissions were removed.

## Voice and vision

- Android OCR processes the supplied image through bundled ML Kit Latin recognition. The emulator integration fixture verifies expected text.
- Audio transcription passes the selected file to an already-installed Cactus Whisper model. Automatic model download is disabled because the SDK path bypasses central network policy.
- PocketLLM no longer invents OCR confidence, invoice fields, transcript timestamps, speakers, summaries, tasks, or SRT cues.
- Chat image input is disabled unless the selected manifest/provider explicitly confirms vision capability.

## Developer API

The Privacy & Network screen controls the authenticated embedded service: host, port, generated key, start/stop, and logs. `/v1/models`, `/v1/chat/completions` (JSON and SSE), and `/v1/embeddings` invoke real configured PocketLLM runtimes. Loopback is the default; LAN mode shows a warning.

## Upgrade notes

- Version: `1.0.36+36`.
- Existing chats/settings are preserved. Legacy plaintext JSON remains import-only; new portable backups are encrypted `.pllm` schema 3 archives and require at least eight password characters.
- Models without confirmed vision metadata no longer show an image-input control.
- The previous automatic router/profile UI and simulated mobile-action state were removed. Real supported actions now execute through confirmation-gated tools.
- Audio transcription requires an existing `whisper-tiny` model directory; there is no first-use automatic download.

## Known limitations

- Production Android publication is blocked until the project supplies its existing production signing identity and completes physical-device upgrade validation.
- Android OCR is Latin-script only; iOS OCR and scanned-PDF OCR are not enabled.
- Physical-device local-model inference, Whisper accuracy/performance, and notification delivery were not verified in this environment.
- The archived Cactus Flutter dependency is a maintenance risk.
- The embedded server has no trusted-host or configurable CORS allowlist.
- Model-family-native Qwen/LFM tool templates are not enabled without authoritative installed-model metadata.

## Release build

```bash
flutter build apk --split-per-abi --release
```

Exact artifact, checksum, signer, test, emulator, and publication status are recorded in `docs/V1_0_36_VERIFICATION.md`.
