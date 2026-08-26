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

- [x] Inventory every feature, service, UI route, persistence path, test, and outbound request.
- [x] Record advertised versus implemented behavior in `docs/V1_0_36_PRODUCT_AUDIT.md`.
- [x] Run and record untouched baseline format/analyze/test/build state.
- [x] Search every shipping path for placeholder and hardcoded-success patterns.

### Task 2: Runtime and agent orchestration

- [x] Add `GenerationPipeline` with dependency-injected inference, context, memory/RAG, tools, cancellation, and measured results.
- [x] Add strict canonical JSON tool models, schema validation, safe calculator parsing, real system information, and bounded tool rounds.
- [x] Route Chat and the OpenAI server through the pipeline and remove XML-only execution from shipping paths.
- [x] Add unit and integration tests for valid, malformed, unknown, timed-out, and repeated tool calls.

### Task 3: Persistence, retrieval, and documents

- [x] Persist memory records with schema versioning, deduplication, sensitivity rejection, and restart tests.
- [x] Replace simulated retrieval with actual embeddings, cosine similarity, BM25, rank fusion, and MMR.
- [x] Persist document chunks and embeddings with stable source/page metadata.
- [x] Integrate retrieved memories and document citations into pipeline context under an explicit budget.

### Task 4: Privacy and device truth

- [x] Disable Cactus telemetry before runtime initialization.
- [x] Add a policy-aware `NetworkGateway` and migrate every app-owned HTTP/Dio call.
- [x] Read Android RAM, storage, ABI, cores, thermal status, and acceleration capability through a native channel.
- [x] Return unknown values on unsupported platforms instead of estimates and test failure behavior.

### Task 5: OCR, audio, and backups

- [x] Replace canned transcription with Cactus Whisper input processing and explicit model-download errors.
- [x] Process actual image input with supported on-device OCR or disable the entry point per platform.
- [x] Implement password KDF plus AES-256-GCM backup envelopes with random salt/nonce and authenticated restore.
- [x] Test that plaintext is absent and wrong passwords/corruption fail.

### Task 6: Models and providers

- [x] Add a dated `ModelManifest` populated only from runtime/trusted primary metadata.
- [x] Audit Cactus, Ollama, Hugging Face GGUF discovery, downloads, checksums, secure tokens, and remote OpenAI-compatible endpoints.
- [x] Remove invented benchmark/capability claims and block impossible load actions.
- [x] Add hardware-profile recommendation tests independent of native probing.

### Task 7: Product UX and tests

- [x] Verify every button/toggle and remove or explain dead controls.
- [x] Use M3AppBar, M3EmptyState, M3SectionHeader, theme colors, 48dp targets, and responsive layouts in modified screens.
- [x] Add `integration_test/` coverage for pipeline, tools, persistence, documents, offline policy, backup, and OpenAI routes where CI-safe.
- [x] Smoke test on the available Android emulator in light/dark mode and representative sizes.

### Task 8: Release and publication

- [x] Update README, CHANGELOG, RELEASE_NOTES, version references, audit, decisions, limitations, competitor analysis, and verification matrix from measured results.
- [x] Run `dart format .`, `flutter analyze`, `flutter test`, supported integration tests, and release build.
- [x] Produce `PocketLLM-Lite-v1.0.36-android.apk` and `SHA256SUMS.txt`; verify package/version/install/launch.
- [ ] Commit logical batches, push the release branch, tag `v1.0.36`, publish the GitHub release, and attach verified artifacts.

## Final execution status

- Tasks 1-7 are complete for the supported v1.0.36 scope. The final system uses one generation pipeline, canonical tools, persistent structured memory, real hybrid retrieval, stable document citations, central network policy, Android ML Kit OCR, selected-file Whisper input, authenticated backups, measured model manifests, and honest unsupported states.
- Final verification passed `flutter analyze`, 136 unit/widget/regression tests, and six Android integration flows on both the connected Android 17 Pixel and API 36 emulator. The obfuscated universal and split release APKs built, and the exact universal artifact passed checksum, package/version, installation, clean-start, responsive UI, and log inspection.
- Physical-device local-model performance, Whisper quality, reminder wake/reboot delivery, iOS OCR, and scanned-PDF OCR remain explicitly unverified or unsupported.
- Task 8 is complete through an engineering release candidate. Production tag/release publication is blocked because `android/key.properties` is absent and `apksigner` identifies the artifact as Android Debug signed. The debug-signed APK must not be published as the production release.
