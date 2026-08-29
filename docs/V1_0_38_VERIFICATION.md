# PocketLLM Lite v1.0.38 Verification

Verification date: 2026-08-29

## Result

PocketLLM Lite v1.0.38 was analyzed, tested, and built successfully from the
release source on Windows.

## Automated checks

- `dart format .`: completed.
- `flutter analyze`: passed with no issues.
- `flutter test`: 144 tests passed.
- `flutter build apk --release --obfuscate --split-debug-info=build/symbols/v1.0.38`: passed.
- `flutter build apk --split-per-abi --release --obfuscate --split-debug-info=build/symbols/v1.0.38`: passed.

The added regression coverage checks safe restart when a server ignores an HTTP
Range request, partial catalog availability, and the guided model prerequisite
dialog at 360 x 640 with 130% text scaling.

## Artifact inspection

- Package: `com.pocketllm.pocketllm_lite`
- Version name: `1.0.38`
- Version code: `38`
- Minimum Android SDK: 24
- Target Android SDK: 36
- APK Signature Scheme v2 verification: passed for all four APKs
- Signer: `C=US, O=Android, CN=Android Debug`
- Signer certificate SHA-256: `f11e976967911c8e585dd88817d6587076a802840699eebf7e3c8304bedbe3b5`

The APKs are engineering prerelease artifacts, not production upgrade
artifacts. No production Android signing key was available in this checkout.

## Release artifacts

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `PocketLLM-Lite-v1.0.38-android.apk` | 123410783 | `45c3c3b9ff205b0adb325a5d9263c815a0152643708291316570d5e66c0536c9` |
| `PocketLLM-Lite-v1.0.38-arm64-v8a.apk` | 58118680 | `3bfb3d9cdc94c6d82426ba8d5b0043d252153d395ccdebcd27e77e54f08092c6` |
| `PocketLLM-Lite-v1.0.38-armeabi-v7a.apk` | 43330001 | `90d34398b1c67f36474a5aefa9c91a54380fc98733775a2602f56b75f13d2fbc` |
| `PocketLLM-Lite-v1.0.38-x86_64.apk` | 52598172 | `9dd42d0a28c9c3e37a46681e743fcacd02fb53c6b7e78c3beccb15c2194c6309` |

## Verified behavior boundaries

Automated coverage includes the network policy, authenticated backup restore,
durable task recovery, per-chat prompt persistence, keyword/semantic/hybrid
retrieval, model catalog behavior, download resumption and integrity, Ollama
connection failures, external navigation, update integrity, and responsive
compact layouts.

Live catalog and HTTP Range checks confirmed that the currently pinned Cactus
Qwen embedding, Nomic embedding, and Whisper Tiny bundle endpoints were
reachable and returned partial content on 2026-08-29. Because third-party hosts
can change, the app still presents retryable source-specific errors and never
claims an unavailable download is installed.

Physical-device inference quality, microphone capture quality, large-model
performance, OEM background behavior, and production-key upgrade compatibility
were not available for final verification.
