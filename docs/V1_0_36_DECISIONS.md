# PocketLLM Lite v1.0.36 Decision Log

## 2026-08-25

- Keep the Material 3 seed `#6750A4` and existing product structure. This release repairs runtime truth and integration rather than replacing the visual identity.
- Make `GenerationPipeline` the shared Chat, Prompt Enhancer, Prompt Lab, model comparison, and OpenAI-server orchestration boundary. Context, memory, documents, tools, cancellation, metrics, and bounded continuation now converge there.
- Keep canonical internal JSON tool calls and strict schemas. Retain XML parsing only as a legacy input adapter; model-family-native templates remain future manifest-driven work.
- Require one-shot user confirmation for clipboard writes, notes, reminders, email drafts, and external URL launches. Reject confirmation-requiring tools in headless API requests.
- Use `flutter_local_notifications` 19.5 with runtime notification permission, reboot rescheduling receivers, timezone-aware absolute instants, and inexact scheduling. Avoid exact-alarm permission because these assistant reminders are not an exempt critical-alarm use case.
- Treat URL opening as network-capable behavior: allow only HTTP(S), apply Strict Offline before external launch, and record the decision in the network audit log. Email drafts open a composer and never send.
- Persist local notes in app-private Hive data and include them in authenticated backups. A separate note-management UI is not required to claim tool execution, but its absence is documented.
- Use PBKDF2-HMAC-SHA256 with 600,000 iterations and AES-256-GCM for portable backups. Validate before mutation and roll storage plus document-index changes back on failure.
- Use bundled Android ML Kit Latin OCR to avoid runtime model fetching. iOS/additional scripts and scanned-PDF OCR remain unavailable rather than simulated.
- Pass selected audio into an already-installed Cactus Whisper context. Disable the SDK's implicit download path because it bypasses central network policy; do not invent segments, timestamps, speakers, summaries, or tasks.
- Permit loopback under Strict Offline for same-device Ollama and the developer API. All non-loopback application-owned I/O is evaluated centrally before transport or external URL launch.
- Do not infer vision, tool, reasoning, accelerator, or performance capability from filenames or brand names. Use source/runtime manifests and keep unknown values unknown. Disable image input when capability is not confirmed.
- Bound model discovery to four seconds per endpoint group and probe configured endpoints concurrently. A discovery failure produces an honest empty selector; it must never inherit long generation timeouts or leave the app bar indefinitely loading.
- Remove hardcoded model profiles, automatic task routing, and built-in catalog benchmarks. Reintroduce routing only when installed manifests and measured device results can support an auditable decision.
- Retain Cactus behind inference/audio adapters but record its archived July 2026 upstream repository as a maintenance risk. Do not use its public discovery, telemetry, or unmanaged download paths.
- Do not tag or publish a production release while the configured release signing identity is absent.
