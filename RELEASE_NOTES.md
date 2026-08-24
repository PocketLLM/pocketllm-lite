# PocketLLM Lite v1.0.36 — Truth & Integration

## Highlights

This release replaces several demonstration paths with real execution, connects Chat to a shared generation pipeline, and makes privacy and failure behavior more explicit.

## Inference and models

- Chat now selects Cactus or Ollama through `GenerationPipeline`.
- Hugging Face GGUF browsing and downloads are policy-gated.
- Model recommendations use measured Android RAM/storage/ABI/core information when available and no longer display invented speed ranges.

## Memory and retrieval

- Local memories persist across restarts, reject common secret patterns, merge exact duplicates, and can be injected into generation context.
- Retrieval uses corpus-based BM25, real cosine similarity when embeddings exist, and actual MMR diversification. Word overlap is no longer labeled as an embedding.

## Tools and agents

- Chat requests canonical JSON tool calls.
- Tool arguments are validated before execution.
- The calculator supports precedence, parentheses, decimals, unary negatives, and divide-by-zero errors.
- The canned offline knowledge tool has been removed until a real local corpus is selected.

## Privacy and security

- Cactus telemetry is disabled before the runtime initializes.
- Backups now use PBKDF2-HMAC-SHA256 and AES-256-GCM with random salts/nonces.
- Export/Import now creates and restores password-protected `.pllm` archives; legacy plaintext JSON remains import-only for compatibility.
- Hugging Face, model downloads, Tavily, GitHub skill installs, and update checks are evaluated by network policy before outbound I/O.
- The local OpenAI server defaults to loopback and uses a generated key stored in secure storage.

## Voice and vision

- Audio files are sent to Cactus Whisper instead of returning a fixed meeting transcript.
- Android images are processed with on-device ML Kit OCR instead of returning a fixed invoice.
- The app no longer invents speakers, timestamps, meeting summaries, tasks, OCR confidence, or table data.

## Developer API

The embedded server now implements authenticated `/v1/models`, `/v1/chat/completions` (standard and SSE), and `/v1/embeddings` using real PocketLLM runtimes.

## Upgrade notes

Existing chats and settings are preserved. New memory records use a versioned settings payload. New backups use format version 2 and require a password of at least eight characters; checksum-only v1.0.35 exports are not treated as encrypted backups.

## Known limitations

- iOS OCR is not enabled.
- Cactus Whisper does not provide verified segment timestamps or diarization through the current Flutter API.
- Device-only inference performance depends on the selected model and hardware.
- Release signing and physical-device smoke results are recorded in `docs/V1_0_36_VERIFICATION.md`.
- Archive authentication completes before import, but individual Hive record writes are not one atomic transaction.
- The OpenAI-compatible service is tested as a developer API and does not yet have an in-app start/stop screen.

## Build

```bash
flutter build apk --split-per-abi --release
```
