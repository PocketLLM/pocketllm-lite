# PocketLLM Lite v1.0.37 Verification

Verification date: 2026-08-26

## Result

PocketLLM Lite v1.0.37 was analyzed, tested, and built successfully from commit-ready source on Windows.

## Automated checks

- `flutter analyze`: passed with no issues.
- `flutter test`: 141 tests passed.
- `flutter build apk --release --obfuscate --split-debug-info=build/symbols/v1.0.37`: passed.
- `flutter build apk --split-per-abi --release --obfuscate --split-debug-info=build/symbols/v1.0.37`: passed.

## Artifact inspection

- Package: `com.pocketllm.pocketllm_lite`
- Version name: `1.0.37`
- Version code: `37`
- Minimum Android SDK: 24
- Target Android SDK: 36
- APK Signature Scheme v2 verification: passed
- Signer: `C=US, O=Android, CN=Android Debug`

The APKs are therefore engineering pre-release artifacts, not production upgrade artifacts. No production Android signing key was available in this checkout.

## Release artifacts

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `PocketLLM-Lite-v1.0.37-android.apk` | 123312407 | `0333ee2524eddea66e890831ecd4036a45cb65bac28ca2b26b8dcc2b6bea587b` |
| `PocketLLM-Lite-v1.0.37-arm64-v8a.apk` | 58053076 | `f2fa43211bf1e6fe3502348150c38ca98cf2fec754eb9ff0b47134a283d94f0e` |
| `PocketLLM-Lite-v1.0.37-armeabi-v7a.apk` | 43297165 | `d23a77198551441d8191d5e1add0a0622c3c07f694b77feca5bba7a63af327f9` |
| `PocketLLM-Lite-v1.0.37-x86_64.apk` | 52598104 | `0884c328b3cdf7b1b3526c24b4ab8546219c3810f88f8f8fa87aaf2799b0e8cf` |

## Verified behavior boundaries

Automated coverage includes network policy enforcement, authenticated backup restore and rollback behavior, durable task recovery, per-chat system prompt persistence, real audio input handoff, keyword/semantic/hybrid retrieval, Ollama connection failure handling, model recommendation truthfulness, external navigation policy, update integrity, and responsive 360dp large-text rendering.

Physical-device inference quality, microphone capture quality, long-running process termination, OEM background behavior, and production-key upgrade compatibility were not available for final verification.
