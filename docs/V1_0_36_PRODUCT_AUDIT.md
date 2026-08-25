# PocketLLM Lite v1.0.36 Product Audit

Audit date: 2026-08-25. Baseline commit: `f6d779a`. Baseline verification: Flutter 3.41.9 / Dart 3.11.5, `flutter analyze` passed, and 78 tests passed. A passing baseline test did not establish that a user-facing feature performed real work.

Status meanings: **Verified** has direct automated or emulator evidence; **Implemented** has a real runtime path but lacks representative device evidence; **Constrained** is deliberately unavailable unless capability is confirmed; **Removed** means a misleading path was deleted.

| Feature | UI | Real service/runtime | Persistence | Test evidence | Final status / failure behavior |
|---|---|---|---|---|---|
| New chat, history, edit, regenerate | Yes | Shared `GenerationPipeline` | Hive CE | Unit/widget and integration persistence flow | Verified; backend failures become visible assistant errors |
| Model selection and switching | Yes | Local GGUF, Ollama, configured OpenAI-compatible providers | Settings/session | Provider deadline test and final release emulator check | Verified; unreachable discovery is bounded and unavailable providers are not selectable |
| Local model load/unload and streaming | Yes | Cactus context adapter | Manifest and app model directory | Adapter/pipeline integration harness | Implemented; no physical-model performance claim |
| Stop generation | Yes | Shared cancellation token | N/A | Pipeline cancellation tests | Verified for cooperative backends |
| Markdown, code, copy, share, delete, stars, tags | Yes | Flutter presentation/storage services | Hive CE | Existing widget/storage tests | Implemented |
| Personas, prompts, skills | Yes | `PromptComposer` injects enabled context | Hive CE | Pipeline and storage tests | Verified for prompt composition; skill bodies do not grant undeclared native access |
| Image attachments | Capability-gated | Passed only to a model/provider declaring vision support | Chat session | Provider encoding tests | Constrained; control disabled and send fails closed when vision is unverified |
| Text-file attachments | Yes | Bounded TXT/MD/JSON/CSV/log content injection | Chat session | Chat/storage tests | Implemented; 200 KB limit |
| Voice dictation and TTS | Yes | Platform speech and TTS plugins | Settings | Existing tests/build | Implemented; platform engine availability varies |
| Context budgeting and long chats | Indirect | Family-aware estimator, explicit response reservation, local rolling summary | Versioned summary setting | Boundary and oversized-input tests | Verified; an oversized newest message is rejected instead of silently truncated |
| Prompt Lab and model comparison | Yes | Shared generation pipeline and actual runtime metrics where returned | Local run history | Pipeline tests | Implemented; estimated rates are labeled `≈` |
| Tool registry/parser | Tool cards/toggle | Canonical JSON, strict schema, multi-call parsing, legacy XML adapter | Tool events in chat | Parser/validation/multi-round tests | Verified; malformed, unknown, or extra arguments are rejected |
| Tool loop | Yes | Inside `GenerationPipeline`, maximum five rounds, cancellation and tool events | Chat history | Calculator end-to-end integration flow | Verified |
| Calculator | Via tools | Precedence-aware safe parser | N/A | Unary, parentheses, decimal, divide-by-zero tests | Verified |
| System information | Via tools/settings | Android native RAM/storage/ABI/cores/battery/thermal; unknown elsewhere | Benchmark records | Native service and emulator integration | Verified on Android emulator; unavailable values remain unknown |
| Clipboard | Confirmation dialog | Real platform clipboard write | OS clipboard | Adapter/confirmation unit test | Implemented; denied calls do not execute |
| Notes | Confirmation dialog | Real app-private note record | Hive CE and encrypted backup | Restart/backup test | Verified; no separate notes manager UI in this release |
| Reminders | Confirmation + OS permission | Timezone-aware local notification, inexact scheduling, reboot receiver | OS pending notifications | Schema/denial tests and release manifest build | Implemented; representative device delivery not run |
| Draft email | Confirmation dialog | Opens system `mailto` composer; never sends | External composer only | Adapter/confirmation tests | Implemented; fails if no composer exists |
| Open URL | Confirmation dialog | HTTP(S)-only external browser launch after network-policy evaluation | Audit log | Policy tests | Implemented; Strict Offline blocks before launch |
| Web search | Toggle/tool card | Tavily through central gateway | Secure key storage, audit log | Gateway/policy/tool tests | Verified pre-I/O controls; requires configured key |
| Offline knowledge search | No | No selected local corpus | N/A | Regression assertion | Removed; canned answers deleted |
| Memory extraction | Inspector/settings | Structured local-model JSON extraction with validation | Versioned Hive settings payload | Persistence/sensitivity/extraction tests | Verified with test backend; requires a capable selected runtime |
| Memory update/deduplication | Inspector | Exact/semantic dedupe, subject supersession, confidence and stale handling | Persistent | Restart, duplicate, contradiction tests | Verified |
| Memory retrieval in prompts | Debug inspector/chat | Query embedding when available plus lexical fallback | Last-used metadata | Pipeline injection tests | Verified; fallback is not called embedding similarity |
| PDF/TXT/Markdown/CSV ingestion | Document workspace | Syncfusion PDF page extraction and structure-aware paragraph chunks | Document archive and vector index | Generated two-page PDF integration flow | Verified for text PDFs and listed text formats |
| Scanned-PDF OCR | No misleading control | Not connected | N/A | Error-path test | Not supported; no-text PDFs report an actionable error |
| Dense/lexical/hybrid retrieval | RAG toggle | Persisted vectors, cosine, Okapi BM25, normalized fusion, MMR | Versioned vector archive with backup | Unit and document integration tests | Verified with deterministic test embeddings; production embedding depends on selected backend |
| Source metadata/citations | Chat context | Stable document, page, chunk metadata | Vector archive | Correct page-2 citation integration assertion | Verified |
| Android OCR | Service/integration surface | Actual input bytes through bundled ML Kit Latin recognizer | No fabricated result cache | Generated-image emulator integration | Verified on Android emulator |
| iOS OCR / additional scripts / table extraction | No false success | Not implemented | N/A | Unsupported-path tests | Not supported |
| Audio-file transcription | Audio workspace | Actual selected file passed to installed Cactus Whisper context | Result in current view/exported text | Input propagation unit test | Implemented; no model fixture/device transcription run |
| Audio timestamps, diarization, summary/tasks | No controls | Current SDK returns only transcript text and metrics | N/A | Empty-SRT regression test | Constrained; no timestamps, speakers, summary, or tasks are invented |
| Model discovery/import/download | Yes | Hugging Face API, LFS metadata, GGUF header/SHA/storage validation | App model directory + manifest | Download/storage tests | Implemented; Cactus public discovery/implicit download disabled |
| Download progress/retry/resume | Yes | Dio range/resume path and explicit errors | Partial file | Service tests | Implemented; gated repositories require a user token |
| Model metadata/capabilities/licenses | Catalog/detail | `ModelManifest` from backend or source evidence | Versioned registry | Serialization/truth tests | Constrained; unknown fields stay unknown and load success marks compatibility |
| Hardcoded catalog/benchmarks/router profiles | No | Deleted | N/A | Regression search/test | Removed; no filename-based capability or speed claims |
| Ollama | Settings/chat | Official chat, embeddings, pull stream, and final token stats endpoints | Endpoint setting | HTTP/service tests | Verified with mock server; remote hosts obey policy |
| Generic OpenAI-compatible providers | Privacy/network UI | Secure registry, endpoint model confirmation, chat/vision/embeddings | Secure storage | Live mock endpoint tests | Verified; capabilities are user-configured, not inferred |
| Embedded OpenAI server | Privacy/network UI | Authenticated models, chat, SSE and embeddings through PocketLLM runtimes | Secure generated key | Live localhost socket tests | Verified; loopback default and explicit LAN warning |
| Server concurrency/rate/cancellation/audit | UI/log | Concurrency cap, rate limit, disconnect cancellation, request log | Current process | Service tests | Implemented; no trusted-host/CORS allowlist yet |
| Strict Offline | Privacy/network UI | Central gateway and preflight for app-owned HTTP/Dio/URL launch | Setting + audit log | Every-purpose pre-I/O denial tests | Verified at app boundary; loopback intentionally allowed |
| Tavily/provider/server secrets | Settings | Flutter secure storage | OS keystore/keychain | Migration tests | Verified; legacy Tavily plaintext is deleted |
| OTA update | Dialog/settings | Manual/automatic policy split, APK plus published SHA-256 requirement | Preferences | Metadata/hash and merged-manifest tests | Verified fail-closed metadata path; installer UX remains OS-controlled |
| Backup export/encryption | Settings | PBKDF2-HMAC-SHA256 (600,000) + AES-256-GCM, schema 3 | `.pllm` archive | Round-trip/tamper/plaintext tests | Verified |
| Backup restore/migration | Settings | Full validation, wrong-password rejection, storage/document rollback | Hive + document index | Fault-injection and integration restore tests | Verified application-level atomic rollback |
| Android permissions | OS | Required manifest; legacy storage and privileged `INSTALL_PACKAGES` removed; user-consent `REQUEST_INSTALL_PACKAGES` retained for verified OTA handoff | N/A | Merged release manifest and final APK permission dump | Verified |
| Version/docs/release artifact | Repository | v1.0.36+36 | Git/artifacts | 127 tests, six Android flows, clean release builds, hash, install, launch, UI, and signer inspection | Engineering candidate verified; production publication blocked by debug signing |

## False-success paths found and disposition

- Fixed invoice OCR was replaced with real Android input processing.
- The fixed 14-second meeting transcript and invented metadata were removed.
- Checksum-only plaintext backup was replaced with authenticated encryption and rollback.
- The OpenAI echo server was connected to real inference and secured with a generated key.
- Simulated embedding/BM25 names were replaced by real algorithms and persistent vectors.
- Fixed hardware and benchmark values were replaced by measurements, labeled estimates, or unknown states.
- Duplicate XML/typed tool systems were unified; inert mobile actions and canned knowledge were deleted.
- Hardcoded model profiles and task routing were removed because the repository lacked verified metadata to support them.

## Release boundary

A separately managed production signing identity is absent. Release-mode artifacts may use Gradle's debug-signing fallback for engineering verification, but must not be tagged or published as a production release. Physical-device local-model performance, Whisper quality, reminder delivery, and iOS-specific paths remain explicit limitations.
