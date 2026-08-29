# Contributing to PocketLLM Lite

Thanks for helping make local AI on Android more useful and trustworthy. Code,
documentation, design, accessibility, translations, device reports, and model
compatibility evidence are all valuable contributions.

## Good first contributions

- Reproduce a bug on a real Android device and add exact device/runtime details.
- Improve one of the English, Spanish, Chinese, Japanese, Korean, or Hindi
  localization resources.
- Add a focused regression test for a real failure.
- Improve accessibility, compact-screen behavior, or documentation.
- Investigate a Cactus model bundle and report measured load behavior without
  guessing capabilities.

Look for [`good first issue`](https://github.com/PocketLLM/pocketllm-lite/labels/good%20first%20issue)
and [`help wanted`](https://github.com/PocketLLM/pocketllm-lite/labels/help%20wanted)
labels. If no matching issue exists, open one before a large change so effort is
not duplicated.

## Development setup

Requirements:

- Flutter stable with an Android SDK (minimum supported Android API is 24)
- Git
- An Android emulator or device for UI work
- Ollama only when changing the optional Ollama integration

```bash
git clone https://github.com/YOUR-USER/pocketllm-lite.git
cd pocketllm-lite
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```

## Pull request checklist

- Keep the change focused and explain the user-visible result.
- Preserve local-first and Strict Offline boundaries; do not add hidden network
  calls, telemetry, ads, or simulated production behavior.
- Use Material 3 theme tokens and the shared M3 widgets in `lib/core/widgets/`.
- Add or update tests for behavior changes.
- Run `dart format .`, `flutter analyze`, and `flutter test`.
- Update `CHANGELOG.md` and user documentation when behavior changes.
- Include screenshots for UI changes and device/runtime evidence for native
  inference, OCR, audio, notifications, or upgrade claims.
- Never commit API keys, model weights, signing files, personal data, or secrets.

## Model and AI claims

A GGUF header or catalog listing does not prove that a model loads on every
device. Capability, performance, and compatibility claims need a source or a
measured result. Do not add fake downloads, canned transcripts, simulated
embeddings, placeholder model results, or success messages for unfinished work.

## Reporting bugs and security issues

Use the issue forms for ordinary bugs and feature ideas. Follow
[`SECURITY.md`](SECURITY.md) for vulnerabilities; do not publish an unpatched
security issue.

## Community and license

Participation is governed by the [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
By contributing, you agree that your contribution is licensed under the
project's [MIT License](LICENSE).
