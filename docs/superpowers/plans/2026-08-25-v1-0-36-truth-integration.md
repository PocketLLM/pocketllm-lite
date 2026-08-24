# PocketLLM Lite v1.0.36 Truth & Integration Implementation Plan

> **For agentic workers:** Execute each checkbox in order and preserve exact verification evidence.

**Goal:** Ship v1.0.36+36 as a materially more trustworthy local-first assistant with coherent runtime integration and no misleading success paths.

**Architecture:** Add one generation orchestration boundary and one policy-aware network boundary. Reuse Cactus, Ollama, Hive CE, secure storage, and Material 3 components already in the repository.

**Tech Stack:** Flutter 3.41.9, Dart 3.11.5, Riverpod 3, Hive CE, Cactus 1.3, Android platform channels, authenticated cryptography.

## Global Constraints

- Preserve Material 3 seed `#6750A4` and custom M3 widgets.
- Preserve existing user data and add migration paths.
- Never claim or return success without real execution.
- All outbound requests pass through network policy.
- Release version is `1.0.36+36`.

### Task 1: Evidence-based product audit

- [ ] Inventory every feature, service, UI route, persistence path, test, and outbound request.
- [ ] Record advertised versus implemented behavior in `docs/V1_0_36_PRODUCT_AUDIT.md`.
- [ ] Run and record untouched baseline format/analyze/test/build state.
- [ ] Search every shipping path for placeholder and hardcoded-success patterns.

### Task 2: Runtime and agent orchestration

- [ ] Add `GenerationPipeline` with dependency-injected inference, context, memory/RAG, tools, cancellation, and measured results.
- [ ] Add strict canonical JSON tool models, schema validation, safe calculator parsing, real system information, and bounded tool rounds.
- [ ] Route Chat and the OpenAI server through the pipeline and remove XML-only execution from shipping paths.
- [ ] Add unit and integration tests for valid, malformed, unknown, timed-out, and repeated tool calls.

### Task 3: Persistence, retrieval, and documents

- [ ] Persist memory records with schema versioning, deduplication, sensitivity rejection, and restart tests.
- [ ] Replace simulated retrieval with actual embeddings, cosine similarity, BM25, rank fusion, and MMR.
- [ ] Persist document chunks and embeddings with stable source/page metadata.
- [ ] Integrate retrieved memories and document citations into pipeline context under an explicit budget.

### Task 4: Privacy and device truth

- [ ] Disable Cactus telemetry before runtime initialization.
- [ ] Add a policy-aware `NetworkGateway` and migrate every app-owned HTTP/Dio call.
- [ ] Read Android RAM, storage, ABI, cores, thermal status, and acceleration capability through a native channel.
- [ ] Return unknown values on unsupported platforms instead of estimates and test failure behavior.

### Task 5: OCR, audio, and backups

- [ ] Replace canned transcription with Cactus Whisper input processing and explicit model-download errors.
- [ ] Process actual image input with supported on-device OCR or disable the entry point per platform.
- [ ] Implement password KDF plus AES-256-GCM backup envelopes with random salt/nonce and authenticated restore.
- [ ] Test that plaintext is absent and wrong passwords/corruption fail.

### Task 6: Models and providers

- [ ] Add a dated `ModelManifest` populated only from runtime/trusted primary metadata.
- [ ] Audit Cactus, Ollama, Hugging Face GGUF discovery, downloads, checksums, secure tokens, and remote OpenAI-compatible endpoints.
- [ ] Remove invented benchmark/capability claims and block impossible load actions.
- [ ] Add hardware-profile recommendation tests independent of native probing.

### Task 7: Product UX and tests

- [ ] Verify every button/toggle and remove or explain dead controls.
- [ ] Use M3AppBar, M3EmptyState, M3SectionHeader, theme colors, 48dp targets, and responsive layouts in modified screens.
- [ ] Add `integration_test/` coverage for pipeline, tools, persistence, documents, offline policy, backup, and OpenAI routes where CI-safe.
- [ ] Smoke test on the available Android emulator in light/dark mode and representative sizes.

### Task 8: Release and publication

- [ ] Update README, CHANGELOG, RELEASE_NOTES, version references, audit, decisions, limitations, competitor analysis, and verification matrix from measured results.
- [ ] Run `dart format .`, `flutter analyze`, `flutter test`, supported integration tests, and release build.
- [ ] Produce `PocketLLM-Lite-v1.0.36-android.apk` and `SHA256SUMS.txt`; verify package/version/install/launch.
- [ ] Commit logical batches, push the release branch, tag `v1.0.36`, publish the GitHub release, and attach verified artifacts.

## Final execution status

- Tasks 1, 4, and 5 completed with source, negative-path tests, and release/device evidence.
- Task 2 completed for shared inference, memory preparation, canonical tools, and Chat's bounded loop. Central tool execution for non-Chat clients remains deferred and documented.
- Task 3 completed for persistent memories and real retrieval algorithms. Existing document storage/RAG paths remain, but universal citation quality is not claimed.
- Task 6 removed displayed invented metadata and retained runtime discovery. A dated signed model manifest remains deferred.
- Task 7 completed automated coverage and an Android emulator install/launch/visual pass. Physical-device inference, OCR, Whisper, and exhaustive button traversal were unavailable.
- Task 8 completed documentation, clean format, zero-issue analysis, 96 tests, obfuscated universal/split release builds, checksum, package inspection, and emulator smoke. Production tag/release publication is blocked because the repository has no production signing configuration and the artifact verifies as Android Debug signed.
