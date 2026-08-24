# PocketLLM Lite v1.0.36 Decision Log

## 2026-08-25

- Keep the Material 3 seed and existing product structure; this release repairs runtime truth rather than replacing the UI.
- Use `GenerationPipeline` as the shared Chat, Prompt Lab, and API inference boundary. Chat retains its existing bounded tool-response loop for this release; moving tool execution fully into the pipeline remains follow-up work.
- Use canonical JSON for model-authored tool calls and retain XML parsing only as a compatibility adapter.
- Remove handlers that cannot perform a real operation. Unsupported mobile actions and canned knowledge lookup must fail as unavailable rather than return success.
- Use PBKDF2-HMAC-SHA256 with 600,000 iterations and AES-256-GCM for portable encrypted backups. Archive authentication is complete before import; Hive record application is not represented as atomic.
- Use bundled Android ML Kit Latin OCR to avoid a network model fetch. iOS OCR remains explicitly unavailable rather than silently changing the deployment target.
- Permit loopback under Strict Offline so same-device Ollama remains usable. All user-configured non-loopback Ollama requests pass through policy and are blocked in Strict Offline mode.
- Report unavailable hardware properties as unknown. Estimated model RAM is labeled as an estimate; accelerator support is not inferred from branding.
- Disable Cactus telemetry before runtime initialization. Record that the upstream Flutter repository was archived in July 2026 as a dependency-maintenance risk.
- Do not publish a production release artifact when only debug fallback signing is available.
