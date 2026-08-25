# PocketLLM Lite v1.0.37 — Durable Local Workspaces

PocketLLM Lite v1.0.37 turns local AI setup and document work into durable, inspectable workflows while preserving the app's privacy-first network controls.

## Highlights

- New Model Store with live, policy-gated Cactus catalog discovery, Hugging Face browsing, runtime filters, local installation detection, and explicit license disclosure.
- Resumable model downloads with partial-file retention, range and validator checks, safe archive staging, integrity validation, cancellation, and durable task records.
- Rebuilt Knowledge Base with Keyword, Semantic, and Hybrid retrieval modes, real BM25/cosine/MMR scoring, citations, staged indexing, model readiness, and clear failure guidance.
- Real microphone recording and audio-file transcription workflow with pause/resume, playback, rename, language selection, persisted jobs, and Cactus Whisper model readiness.
- Per-chat system prompts now persist by stable identity across switching, restart, import, and export.
- Ollama screens now distinguish unreachable endpoints from valid empty model lists and show the configured destination with a retry path.
- Settings and privacy navigation were reorganized for clearer Model Store, provider, knowledge, audio, network, and system boundaries.
- Responsive small-screen and large-text improvements, including the 360dp regression path.

## Reliability and release work

- App version: `1.0.37+37`
- `flutter analyze`: passed with no issues.
- `flutter test`: 141 tests passed.
- Universal and per-ABI Android APK builds completed successfully.
- SHA-256 checksums are included in `SHA256SUMS.txt`.

## Important signing notice

These APKs are signed with the Android debug certificate because no production signing key was available in the release checkout. This GitHub release is therefore marked as an engineering pre-release. It is not a production-key upgrade artifact and may not install over a differently signed build without uninstalling that build first.

Choose the universal APK if you are unsure which ABI your device uses. The smaller `arm64-v8a` APK is appropriate for most modern Android phones.

See `RELEASE_NOTES.md` and `docs/KNOWN_LIMITATIONS.md` in the source tree for the complete capability and limitation record.
