# PocketLLM Lite v1.0.36 Product Audit

Audit started 2026-08-25 from clean commit `f6d779a` on Flutter 3.41.9 / Dart 3.11.5. Baseline: `flutter analyze` PASS in 99.7s; `flutter test` PASS, 78 tests. Passing baseline tests do not validate production truth where noted below.

| Feature | UI | Service | Real runtime | Persistence | Tests | Initial status | Required repair |
|---|---|---|---|---|---|---|---|
| Chat / local inference | Yes | Cactus + Ollama | Partial | Chats yes | Ollama unit tests | Disconnected subsystems | Route through GenerationPipeline |
| Tool loop | Yes | XML and typed services | Partial | History partial | Shallow typed tests | Duplicate/inconsistent | Canonical JSON registry, validation, real handlers |
| Calculator | Yes | String split | No for precedence | No | Basic only | Misleading | Safe parser and structured divide-by-zero |
| System info | Yes | Typed service | No | No | No | Canned values | Native/platform telemetry |
| Memory | Inspector | In-memory singleton | No restart survival | No | In-memory test | Misleading persistence claim | Versioned persistent store and chat integration |
| Hybrid retrieval | Indirect | Keyword overlap | No embeddings/BM25 | No | Tests simulation | Misnamed algorithms | Real embeddings, BM25, fusion, MMR |
| Documents/RAG | Yes | Two overlapping services | Partial | Metadata partial | Keyword tests | Incoherent | Stable chunks, embeddings, citations, persistence |
| OCR | Indirect | `LocalOcrService` | No; fixed invoice | No | None | False success | Real input OCR or unavailable error |
| Audio files | Yes | `AudioTranscriptionService` | No; fixed 14s transcript | No | Test expects canned data | False success | Cactus Whisper or unavailable error |
| Backup | Settings path | SHA-256 checksum JSON | No encryption/restore | File only | Test expects checksum | Security claim false | Password KDF + AEAD + atomic restore |
| OpenAI server | Settings route | Embedded HTTP | Fixed response/model/key | Logs memory only | None | False success/insecure default | Pipeline, real models/embeddings/SSE, random key |
| Strict Offline | Yes | Policy evaluator | Partial | Setting yes | Evaluator tests | Bypassable | Central gateway and migrate all HTTP/Dio |
| Device profile | Comparison UI | Estimated constants | No | Cached memory | Recommendation-only | Invented | Native measurements and unknown states |
| Model catalog | Yes | Cactus + hardcoded registry | Partial | Downloads yes | Recommendation tests | Claims unverified | Runtime/trusted manifests and dated metadata |
| Mobile actions | Indirect | Pending/executed lists | No native action | No | None | False success | Implement supported handlers or disable |
| README | Yes | N/A | N/A | N/A | No truth test | Stale v1.0.29 and absolute offline claims | Rewrite from verified release state |

## Baseline false-success evidence

- `local_ocr_service.dart` ignores bytes and returns invoice `#1029` with confidence `0.96`.
- `audio_transcription_service.dart` ignores the file and returns a fixed 14-second meeting with invented speakers and tasks.
- `backup_migration_service.dart` stores readable JSON plus an unkeyed SHA-256 checksum and performs no restore.
- `openai_server_service.dart` lists a fixed model, uses a fixed default key, and echoes a canned completion.
- `hybrid_retrieval_service.dart` names keyword overlap `computeSimulatedEmbedding`.
- `device_spec_service.dart` returns fixed RAM, storage, GPU, and thermal values.
- `typed_tool_calling_service.dart` returns `PocketLLM Native Core` and generic success for unimplemented tools.
- HTTP clients in Hugging Face, model download, Tavily, update, and skill installation paths can bypass a central transport boundary.

## Audit status

This is a working document. Rows and evidence are updated only after implementation and direct verification.

