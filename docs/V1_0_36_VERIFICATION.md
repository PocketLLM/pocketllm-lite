# PocketLLM Lite v1.0.36 Verification Matrix

Verification date: 2026-08-25. `PASS` means the named command or behavior completed in this checkout. `BLOCKED` and `NOT RUN` are not treated as passes.

| Gate | Status | Evidence |
|---|---|---|
| Untouched baseline | PASS | Flutter 3.41.9 / Dart 3.11.5; `flutter analyze` had no issues and 78 tests passed at baseline commit `f6d779a` |
| Formatting | PASS | Final `dart format .` completed without outstanding formatting changes |
| Static analysis | PASS | Final `flutter analyze`: no issues found |
| Unit/widget/regression suite | PASS | Final `flutter test`: 127 tests passed |
| Android integration suite | PASS | Six emulator flows passed: local pipeline/persistence, calculator continuation, memory restart plus Strict Offline, generated two-page PDF retrieval/citation, encrypted backup rejection/restore, and real ML Kit OCR |
| Model-discovery liveness | PASS | A slow-endpoint regression test confirms the discovery deadline; the final release rendered `No Models` after a disconnected Ollama check instead of retaining a spinner |
| Universal release APK | PASS | `flutter build apk --release --obfuscate --split-debug-info=build/symbols/v1.0.36`; 120,450,645 bytes |
| Split release APKs | PASS | `flutter build apk --split-per-abi --release --obfuscate --split-debug-info=build/symbols/v1.0.36`; armeabi-v7a 41,221,831 bytes, arm64-v8a 56,010,514 bytes, x86_64 50,555,542 bytes |
| APK checksum | PASS | SHA-256 file and recomputed artifact both equal `f580d64397934c68b13aee4b49c35247c4486f28d41311849a64546371e61820` |
| APK identity | PASS | `aapt2`: `com.pocketllm.pocketllm_lite`, versionCode 36, versionName 1.0.36, minSdk 24, targetSdk 36 |
| Final APK install/upgrade | PASS | `adb install -r release/PocketLLM-Lite-v1.0.36-android.apk` succeeded on Android x86_64 emulator |
| Clean-data cold start | PASS | Exact final APK: TotalTime 1.611 s / WaitTime 1.615 s; onboarding visible; no startup microphone or notification permission dialog |
| Final chat runtime | PASS | Exact final APK: disconnected screen, `No Models` selector, capability-gated image input, and lazy voice input; crash/ANR/Flutter/MissingPlugin/RenderFlex log scan empty |
| Android OCR | PASS | Generated image bytes were read by the actual bundled ML Kit Android channel and matched the expected text in integration testing |
| Text-PDF RAG and citations | PASS | Generated page-two fact was ingested, indexed, retrieved, and returned with the correct page-two citation |
| Backup authentication/rollback | PASS | Wrong password rejected; correct password restored; unit coverage also verifies ciphertext corruption and application-level rollback |
| Embedded API server | PASS | Authenticated models, chat, SSE streaming, and embeddings passed live localhost socket tests in the full suite |
| Physical Android inference | NOT RUN | No physical phone or representative GGUF fixture was placed in scope; emulator results do not establish model performance |
| Physical reminder delivery | NOT RUN | Scheduling API, permission path, receiver manifest, schema, and denial behavior are verified; wake/reboot delivery still needs a representative device |
| Cactus Whisper transcription quality | NOT RUN | Requires an installed compatible model, representative audio, and a supported device |
| iOS OCR | NOT SUPPORTED | Android-only implementation in v1.0.36 |
| Production signing | BLOCKED | `android/key.properties` is absent; `apksigner` identifies the only signer as `C=US, O=Android, CN=Android Debug` |
| GitHub production release | BLOCKED | A debug-signed fallback artifact must not be tagged or published as a production mobile release |

## Release artifact

- File: `release/PocketLLM-Lite-v1.0.36-android.apk`
- Size: 120,450,645 bytes
- SHA-256: `f580d64397934c68b13aee4b49c35247c4486f28d41311849a64546371e61820`
- Package: `com.pocketllm.pocketllm_lite`
- Version: `1.0.36 (36)`
- Minimum SDK: 24
- Target SDK: 36
- Signature verification: APK Signature Scheme v2 passes
- Signer certificate SHA-256: `f11e976967911c8e585dd88817d6587076a802840699eebf7e3c8304bedbe3b5`
- Signer: `C=US, O=Android, CN=Android Debug`

The artifact is a verified engineering release candidate. It is deliberately not described as a production release because the repository does not contain the separately managed production signing identity.

## Runtime artifacts

- `artifacts/v1.0.36-final-clean-start.xml`: exact final APK clean-start UI hierarchy.
- `artifacts/v1.0.36-final-release-model-selector.png`: exact final APK disconnected chat screen after discovery timeout.
- `artifacts/v1.0.36-final-release-model-selector.xml`: matching UI hierarchy.
- Integration fixtures are generated during the test: PDF, OCR image, encrypted backup, memory, and pipeline responses are not canned shipping data.

## Test coverage added or strengthened

- Shared generation pipeline, multi-round tool continuation, cancellation, and persistent chat output.
- Encrypted backup round trip, plaintext absence, wrong password, ciphertext tampering, prompt preservation, document archive, and rollback.
- Structured memory persistence, duplicate merge, sensitivity rejection, supersession, retrieval, and prompt injection.
- Persistent vector archive, real cosine similarity, Okapi BM25, normalized fusion, MMR diversity, and correct page citations.
- Canonical JSON tool parsing, strict schemas, malformed/unknown/extra arguments, safe arithmetic, timeouts, confirmation denial, and real device-action adapters.
- Strict Offline denial before transport or external URL launch.
- Real-byte Android OCR and explicit empty/unsupported input failure.
- OpenAI-compatible authenticated models, chat, SSE streaming, and embeddings over a live localhost socket.
- Actual selected audio-file propagation without invented timestamps, speakers, summaries, or tasks.
- Model discovery deadline so unreachable endpoints cannot leave the selector indefinitely loading.
