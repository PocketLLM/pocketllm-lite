# PocketLLM Lite v1.0.36 Verification Matrix

Verification date: 2026-08-25. `PASS` means the named command or behavior completed in this checkout. `BLOCKED` and `NOT RUN` are not treated as passes.

| Gate | Status | Evidence |
|---|---|---|
| Untouched baseline analysis | PASS | Flutter 3.41.9 / Dart 3.11.5; `flutter analyze` completed with no issues |
| Untouched baseline unit/widget tests | PASS | 78 tests passed |
| Repaired service test suite | PASS | `flutter test`: 96 tests passed |
| Static analysis after repairs | PASS | Final `flutter analyze`: no issues found |
| Debug Android build | PASS | Native Kotlin device and ML Kit channels compiled into `app-debug.apk` |
| Release APK build | PASS | Obfuscated universal APK: 113.6 MB; split APKs: armeabi-v7a 38.8 MB, arm64-v8a 52.9 MB, x86_64 47.7 MB |
| APK checksum | PASS | `98eb343f899f9bb4f65192cb7c551795dbec2618a2a114db6c7a0ffcf096e3fc` |
| Emulator install/launch | PASS | Android x86_64 emulator: install/upgrade succeeded; `1.0.36 (36)`; cold start 2.720 s; process resumed; crash/ANR/Flutter error scan empty |
| Physical Android inference | NOT RUN | No physical phone was placed in scope; emulator is not representative of model performance |
| Android OCR quality | NOT RUN | Requires representative camera/document fixtures on a supported device |
| Cactus Whisper model transcription | NOT RUN | Requires the upstream model download and representative audio on a supported device |
| iOS OCR | NOT SUPPORTED | Android-only implementation in v1.0.36 |
| Production signing | BLOCKED | `android/key.properties` is absent; Gradle falls back to debug signing for release builds |
| GitHub production release | BLOCKED | A debug-signed fallback artifact must not be published as a production mobile release |

## Release artifact

- File: `release/PocketLLM-Lite-v1.0.36-android.apk`
- Size: 119,078,246 bytes
- Package: `com.pocketllm.pocketllm_lite`
- Minimum SDK: 24
- Target SDK: 36
- Signature verification: APK Signature Scheme v2 passes
- Signer: `C=US, O=Android, CN=Android Debug`

The first emulator pass exposed missing Inter font assets while runtime fetching was disabled. The Google Fonts runtime dependency was removed, the Material text theme now uses platform-bundled typography, and the release was rebuilt. The final cold-start log scan contains no Flutter exception, Android fatal exception, ANR, missing-plugin error, or RenderFlex overflow.

## Test coverage added or strengthened

- Encrypted backup round trip, plaintext absence, prompt preservation, wrong password, and ciphertext tampering.
- Memory persistence, duplicate merge, sensitivity rejection, and retrieval injection.
- BM25/cosine/MMR behavior without simulated embeddings.
- Canonical JSON tool parsing, malformed/unknown arguments, safe arithmetic, timeouts, and real-handler enforcement.
- Network denial before HTTP client invocation.
- Real-byte OCR channel transfer and explicit empty-input failure.
- OpenAI models, authenticated chat completion, SSE streaming, and embeddings over a live localhost socket.
- Real audio backend input propagation without invented transcript metadata.
