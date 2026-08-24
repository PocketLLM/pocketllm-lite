# Known Limitations

Applies to PocketLLM Lite v1.0.36.

- Model compatibility, response quality, memory use, and speed depend on the selected file, quantization, device, and current thermal state.
- Accelerator support is shown as unknown when Android cannot provide reliable cross-vendor evidence.
- Android OCR recognizes Latin-script text through the bundled ML Kit recognizer. iOS OCR and additional Android script recognizers are not enabled.
- Cactus Whisper produces transcription text and runtime metrics through the current Flutter API; verified diarization and segment timestamps are unavailable.
- The Cactus Flutter repository was archived by its owner in July 2026. The app disables its default telemetry and isolates it behind inference services, but maintenance risk remains.
- Strict Offline is an application-level control for app-owned connections, not a device firewall. Loopback is intentionally allowed for same-device Ollama.
- The OpenAI-compatible service defaults to loopback and uses authentication, but v1.0.36 has no in-app server control screen or trusted-host/CORS configuration.
- Encrypted backups are authenticated before restore. Individual record writes to Hive are not a single atomic database transaction, so interruption during application can produce a partial import.
- Legacy plaintext JSON imports are supported for compatibility; new JSON backup export is replaced by encrypted `.pllm` export.
- Existing document ingestion and retrieval can provide local context, but this release does not claim universal semantic retrieval or citation accuracy.
- The repository has no license file, so the README does not claim an open-source license grant.
- Production publication requires a separately managed Android signing key and physical-device release validation.
