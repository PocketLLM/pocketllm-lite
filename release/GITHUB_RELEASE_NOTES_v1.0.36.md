# PocketLLM Lite v1.0.36 - Truth & Integration (Engineering Release Candidate)

> This APK is an engineering release candidate signed with the Android Debug certificate. It is provided for evaluation and must not be treated as a production-signed upgrade.

## Highlights

- One generation pipeline across chat, prompt tools, model comparison, and the embedded OpenAI-compatible API.
- Canonical schema-validated tool calls with confirmation, timeouts, cancellation, and a five-round limit.
- Persistent structured memory plus real PDF/TXT/Markdown/CSV retrieval using cosine similarity, BM25, rank fusion, MMR, and page citations.
- Android ML Kit OCR, selected-file Cactus Whisper input, and authenticated AES-256-GCM backups.
- Central Strict Offline policy for application HTTP, downloads, remote inference, search, updates, skills, fonts, and external browser links.
- Evidence-based model compatibility labels and current Ollama/Termux guidance without unsupported model claims.
- Responsive Material 3 repairs for compact, dark, and large-text layouts.

## Verification

- `dart format .`: no outstanding changes
- `flutter analyze`: no issues
- `flutter test`: 136/136 passed
- Android integration: 6/6 flows passed on Android 17 Pixel 10 and API 36 emulator
- Universal and split-per-ABI obfuscated release builds completed
- Package: `com.pocketllm.pocketllm_lite`
- Version: `1.0.36 (36)`; minSdk 24; targetSdk 36
- APK Signature Scheme v2 verification passed

## Artifact

- `PocketLLM-Lite-v1.0.36-android.apk`
- Size: 120,483,461 bytes
- SHA-256: `9d97d5a3ea7c50084ad0c22ca4b24c0ac1afd15f7a98bc4c56b2cacc19e2aa12`
- `SHA256SUMS.txt` is attached for independent verification.

## Known boundaries

- The attached APK is Android Debug signed because the production signing identity is not present in the repository.
- Physical-device GGUF performance, Whisper quality, and reminder wake/reboot delivery are not certified by this release.
- OCR is Android-only and Latin-script; scanned-PDF OCR and iOS OCR are not enabled.
- Cactus Flutter 1.3 is archived upstream and remains a maintenance risk.
