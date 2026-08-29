# PocketLLM Lite v1.0.38 — Guided Model Setup

## Highlights

v1.0.38 removes the “you needed a model” dead end from document and audio
workflows. PocketLLM now explains the exact required model before work starts,
downloads it through the audited Model Store, verifies the installation, and
continues the action the user originally requested.

## Knowledge Base

- First-run setup now comes before file import.
- Keyword mode uses real BM25 and needs no embedding model.
- Semantic mode uses real local embeddings and cosine similarity.
- Hybrid mode combines BM25 and cosine scores before MMR selection.
- The two embedding entries verified in the pinned Cactus catalog are offered:
  Qwen3 0.6B Embed and Nomic2 Embed 300M.
- Missing Semantic/Hybrid prerequisites show Download now, Choose another, and
  Not now instead of a raw red error. A successful download continues to the
  document picker automatically.
- PDF, TXT, Markdown, and CSV processing reports real page/chunk work through a
  persistent task and commits the index only after the entire job succeeds.
- Document details preserve source name, page count, chunk count, mode, model,
  size, and indexing time.
- Responses use stable filename/page citations; retrieval diagnostics retain the
  actual keyword, semantic, fused, and selected scores.

## Audio Workspace

- Record or Upload audio.
- Recording supports start, pause, resume, stop, cancel, elapsed time, measured
  amplitude, 16 kHz mono WAV save, playback, rename, and replace.
- Missing Whisper Tiny opens the same guided setup with source, size, license,
  progress, retry, and cancel controls. A successful install resumes the
  selected audio transcription automatically.
- Auto Detect plus English, Spanish, Chinese, Japanese, Korean, Hindi, German,
  and French selections persist and are passed to the local Whisper prompt.
- Transcription jobs and successful whole-text results persist as durable tasks.
- Cactus 1.3 does not return verified segment timing, so PocketLLM does not
  invent timestamps, speakers, summaries, or SRT cues.

## Model Store

- One Model Store presents the live policy-gated Cactus on-device and Whisper
  catalogs, live Hugging Face GGUF search, installed models, and Browse Files.
- Search and runtime filters distinguish chat/embedding models from speech
  models. Managed models always mean files in private on-device app storage;
  Ollama host models remain separate.
- Model details show exact catalog ID, source, catalog size, quantization,
  declared capabilities, and known upstream weight licenses. Unknown license
  metadata remains explicitly unknown.
- Download tasks survive navigation and app restart. Exact byte progress is
  persisted. Cancellation retains partial data only when the server proves
  byte-range support and provides an ETag or Last-Modified validator.
- If a resumed Range request receives a full HTTP 200 response, the partial is
  discarded and restarted once rather than corrupting the archive by appending.
- ZIP extraction rejects traversal paths and symbolic links, validates every
  GGUF header, quarantines a conflicting broken folder, and atomically publishes
  a fully extracted model folder.
- Hugging Face downloads continue to validate published LFS size/SHA metadata
  and the GGUF header when those values are available.

## Open-source contributors

- PocketLLM Lite is now explicitly licensed under MIT.
- The repository includes focused bug and feature issue forms, a pull-request
  checklist, a community code of conduct, and CI for formatting, analysis, and
  tests.
- The contribution guide calls out useful first contributions in localization,
  accessibility, device evidence, documentation, tests, and model compatibility.

## Chat, providers, and privacy

- Each chat now stores both system prompt ID and content. Existing chats are
  migrated by exact content match, and reopening/restarting/switching chats
  restores the correct prompt selection used by the central generation path.
- Ollama shows checking, connected, or disconnected behavior. Reachability is
  checked before its model list is requested, with endpoint-aware retry copy.
- Settings now exposes clear Model Store, Providers & Ollama, Knowledge Base,
  Audio Workspace, Privacy & Network, and System destinations.
- Privacy & Network uses responsive endpoint labels and explicitly identifies
  its Network Audit as connection attempts, separate from Activity History.
- Strict Offline still blocks catalogs, remote providers, downloads, search,
  updates, skills, fonts, and external browser links before transport. Local
  files, recording, keyword retrieval, installed inference, and loopback remain
  available.

## Complete capability summary

- Local GGUF chat through the pinned Cactus runtime, user-configured Ollama, and
  generic OpenAI-compatible providers.
- Streaming chat, persisted history, per-chat sampling/system prompts, personas,
  templates, prompt enhancement, Prompt Lab, comparison, cancellation, and
  measured runtime metrics.
- Persistent structured memory with sensitivity filtering and contradiction
  handling.
- Real local document retrieval and citations.
- Typed schema-validated calculator, system, clipboard, note, reminder, email,
  URL, and optional Tavily web-search tools with risk-based confirmation.
- Android ML Kit image OCR without fabricated confidence or fields.
- Authenticated PBKDF2/AES-256-GCM portable backups with rollback.
- Authenticated embedded OpenAI-compatible models/chat/SSE/embeddings server.
- Material 3 light/dark UI, localization resources, responsive compact layouts,
  network controls, activity/error logs, statistics, benchmarks, and verified
  checksum-gated OTA handoff.

## Upgrade notes

- Version: `1.0.38+38`.
- Existing Hive data is preserved. Chat prompt identity is an additive field;
  old prompt content remains authoritative if no exact template match exists.
- New durable task records normalize unfinished processes to Interrupted after
  restart and provide an honest retry action.
- Android now requests microphone permission only when recording is started.
- `record` 6.2 is used because Cactus Flutter 1.3 constrains the compatible
  package major version.

## Known limitations

- Production Android signing material is not stored in the repository. A build
  made without it is debug-certificate signed and cannot replace an installed
  production-signed app.
- Physical-device microphone quality, large-model performance, reminder wake
  delivery, and production-certificate upgrade preservation require hardware
  and signing evidence outside this repository.
- Android OCR is Latin-script only; iOS OCR and scanned-PDF OCR are not enabled.
- Cactus Flutter 1.3 was archived upstream and remains a maintenance risk.
- The embedded server has no trusted-host or configurable CORS allowlist.
- Cactus catalog responses do not provide complete upstream license metadata;
  shown Qwen, Nomic, and Whisper licenses come from their upstream projects.

## Release build

```bash
flutter build apk --split-per-abi --release
```

Exact artifact, checksum, signer, test, and publication truth is recorded in
`docs/V1_0_38_VERIFICATION.md`.
