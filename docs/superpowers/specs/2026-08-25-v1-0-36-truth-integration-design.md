# PocketLLM Lite v1.0.36 Truth & Integration Design

## Outcome

PocketLLM Lite v1.0.36 will route user-visible AI work through one orchestration boundary, remove false-success behavior, persist expected local state, enforce network policy before outbound I/O, and describe only verified capabilities. The existing Flutter/Material 3 product and storage formats remain in place; migrations are additive.

## Architecture

`GenerationPipeline` becomes the shared entry point for Chat, Prompt Lab, comparisons, and the OpenAI-compatible server. It composes model-aware prompts and context, invokes an `InferenceService`, runs validated tools through a bounded agent loop, and returns structured output and measured usage. Existing Cactus and Ollama adapters remain backend implementations.

`NetworkGateway` becomes the only application-owned HTTP boundary. It evaluates `NetworkPolicyService` before opening a request and records allowed or blocked attempts without prompt bodies or credentials. Loopback behavior remains explicit and auditable.

Persistent memories, document chunks, embeddings, tool history, and server credentials use existing local storage or secure storage. Schema changes are versioned and do not clear existing chats or settings.

## Truthfulness policy

- Real implementation is preferred when the existing runtime supports it.
- A feature that cannot be safely verified is disabled with a structured unavailable error and a visible explanation.
- No API or UI may return canned success, invented hardware, simulated similarity, fake encryption, fake transcript, or fabricated OCR.
- Model capability claims are sourced from runtime discovery or a dated trusted manifest.

## P0 behavior

- Cactus telemetry is disabled before any Cactus object is created.
- Audio files are transcribed with Cactus Whisper; no speaker labels, summaries, or tasks are invented.
- OCR processes the supplied image on supported mobile platforms; unsupported platforms return `OcrUnavailableError`.
- Backups use password-derived authenticated encryption and reject wrong passwords or corruption.
- OpenAI endpoints call `GenerationPipeline`, list actual models, stream SSE, authenticate with a random securely stored key, and default to loopback.
- Device telemetry comes from native/platform APIs. Unavailable metrics are reported as unknown, never estimated.
- Tool calls use one canonical JSON representation, strict schema validation, bounded execution, structured errors, and real handlers only.
- Memories survive restart and are retrieved into the generation context when enabled.

## Error handling

Service failures use typed exceptions with user-actionable messages. Network policy failures occur before I/O. Unsupported functionality is distinct from runtime failure. Logs redact secrets and user prompt bodies by default.

## Testing

Each repaired service gets negative-path tests that prove the old false-success behavior cannot recur. Integration coverage exercises the pipeline, tool loop, persistence, network blocking, encrypted backup, and OpenAI routes. Device-only checks are recorded as pass, fail, blocked, or not supported with exact evidence.

## Release boundary

The release is publishable only after format, analysis, unit tests, supported integration tests, release APK build, checksum generation, and available emulator smoke tests. GitHub publication follows only if those gates pass; signing limitations are disclosed.

## Implemented variance

The final v1.0.36 implementation shares inference and memory preparation through `GenerationPipeline`, but Chat still owns its bounded tool-response loop. The developer API therefore performs generation without executing tool requests. This is documented as follow-up work rather than represented as complete orchestration. Backup envelopes are authenticated as a whole before restore, while subsequent Hive record writes are per-record and are not described as atomic.
