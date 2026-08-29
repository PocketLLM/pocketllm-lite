# PocketLLM Lite v1.0.38 - Guided Model Setup

PocketLLM Lite v1.0.38 removes the missing-model dead end from Knowledge Base
and audio workflows. When a required local model is absent, the app now explains
which model is needed, where it comes from, its approximate size and known
license, then offers **Download now**, **Choose another**, or **Not now**.

## What changed

- Successful prerequisite downloads automatically continue the document import
  or audio transcription the user originally requested.
- Model Store search now includes IDs, source, license, and capabilities.
- On-device and speech catalogs fail independently, so one unavailable source
  no longer hides the other.
- Resumed downloads safely restart if a server ignores the HTTP Range request.
- Managed archives reject unsafe paths and links, validate GGUF headers,
  quarantine conflicting broken folders, and publish only complete installs.
- Model readiness checks ignore staging/quarantine folders and invalid GGUF
  files.
- The guided dialog has compact-screen and large-text regression coverage.
- The project is explicitly MIT licensed and now includes contribution guidance,
  issue forms, a pull-request checklist, a code of conduct, and CI.

## Verification

- App version: `1.0.38+38`
- `flutter analyze`: passed with no issues
- `flutter test`: 144 tests passed
- Universal and per-ABI Android APK builds: passed
- APK Signature Scheme v2: verified for all four APKs
- SHA-256 checksums: included in `SHA256SUMS.txt`

## Important signing notice

These APKs are signed with the Android debug certificate because no production
signing key was available in the release checkout. This GitHub release is an
engineering prerelease. It may not install over an APK signed with a different
key unless that build is uninstalled first.

Choose the universal Android APK if you are unsure which ABI your phone uses.
Most modern Android phones can use the smaller `arm64-v8a` APK.

See `RELEASE_NOTES.md`, `docs/V1_0_38_VERIFICATION.md`, and
`docs/KNOWN_LIMITATIONS.md` for the complete capability, evidence, and
limitation record.
