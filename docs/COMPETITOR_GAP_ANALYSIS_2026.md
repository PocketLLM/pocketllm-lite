# PocketLLM Lite Competitor Gap Analysis

Research snapshot: 2026-08-25. This uses project-owned repositories and official documentation and is not a benchmark or ranking.

| Product | Source-backed strength | PocketLLM Lite v1.0.36 position | Next evidence-driven gap |
|---|---|---|---|
| [PocketPal AI](https://pocketpal.dev/about) | Cross-platform mobile, on-device models, active releases, and a privacy-first product focus | Adds local-first chat plus document RAG, persistent memory, confirmed tools, optional remote providers, and an app-level network audit | Physical-device GGUF compatibility and performance coverage must become reproducible rather than inferred |
| [ChatterUI](https://github.com/Vali-98/ChatterUI) | Mobile llama.cpp frontend, on-device GGUF, remote APIs, character cards, instruct-format and sampler control | Offers personas/prompts/skills and manifest-gated capabilities, but fewer advanced template controls | Add model-template adapters only from embedded GGUF/backend metadata |
| [MLC LLM](https://github.com/mlc-ai/mlc-llm/blob/main/docs/get_started/quick_start.rst) | Documented Android/iOS deployment and compiled-model workflow tested on named devices | Uses Cactus to reduce Flutter integration complexity and supports GGUF import/Ollama | Establish a maintained mobile backend contingency and named-device matrix |
| [Jan](https://jan.ai/docs/api-server) | User-visible OpenAI-compatible server with API key, host/port, logs, trusted hosts, and CORS controls | Has in-app host/port/start/key controls plus authenticated models/chat/SSE/embeddings | Add trusted-host and CORS allowlists before broad LAN exposure |

## Upstream/model research decisions

- The [Cactus Flutter repository](https://github.com/cactus-compute/cactus-flutter) was archived on 2026-07-24 and documents telemetry enabled by default. PocketLLM disables telemetry, blocks its unmanaged download paths, and treats replacement planning as a release risk.
- [Qwen3's official tool-calling format](https://github.com/QwenLM/Qwen3/blob/main/docs/source/getting_started/concepts.md) uses a Hermes-like template with JSON objects inside tool-call tags and supports parallel/multi-step calls. PocketLLM's canonical representation can express these calls, but it does not claim a Qwen-native adapter until model templates are trustworthy.
- [Qwen's official llama.cpp guide](https://github.com/QwenLM/Qwen3/blob/main/docs/source/run_locally/llama.cpp.md) recommends using the chat template embedded in GGUF and notes tool/thinking parsing support. This supports the decision to prefer source metadata over filename heuristics.
- [llama.cpp server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) labels multimodal support experimental. PocketLLM therefore gates images on explicit capability and makes no blanket GGUF vision claim.
- [Microsoft's Phi-4-mini-instruct model card](https://huggingface.co/microsoft/Phi-4-mini-instruct) identifies a 3.8B text model, 128K training context, MIT license, and function-calling post-training. PocketLLM does not add it to a built-in catalog because Cactus compatibility and phone-level context/memory have not been verified.

## Priorities

1. Maintain a signed, dated compatibility manifest generated from actual load tests.
2. Add physical Android/iOS device matrices for model load, throughput, memory pressure, OCR, ASR, and reminders.
3. Add trusted-host/CORS controls to the embedded server.
4. Replace or supplement archived Cactus with a maintained backend without breaking existing user models.
5. Add native model-template adapters only when the runtime exposes authoritative metadata.
