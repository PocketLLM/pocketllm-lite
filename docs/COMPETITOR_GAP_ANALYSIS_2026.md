# PocketLLM Lite Competitor Gap Analysis

Research snapshot: 2026-08-25. This uses project-owned repositories and official documentation and is not a benchmark or ranking.

| Product | Source-backed strength | PocketLLM Lite v1.0.36 position | Next evidence-driven gap |
|---|---|---|---|
| [PocketPal AI](https://pocketpal.dev/about) | Cross-platform mobile, on-device models, active releases, and a privacy-first product focus | Adds local-first chat plus document RAG, persistent memory, confirmed tools, optional remote providers, and an app-level network audit | Physical-device GGUF compatibility and performance coverage must become reproducible rather than inferred |
| [ChatterUI](https://github.com/Vali-98/ChatterUI) | Mobile llama.cpp frontend, on-device GGUF, remote APIs, character cards, instruct-format and sampler control | Offers personas/prompts/skills and manifest-gated capabilities, but fewer advanced template controls | Add model-template adapters only from embedded GGUF/backend metadata |
| [MLC LLM](https://github.com/mlc-ai/mlc-llm/blob/main/docs/get_started/quick_start.rst) | Documented Android/iOS deployment and compiled-model workflow tested on named devices | Uses Cactus to reduce Flutter integration complexity and supports GGUF import/Ollama | Establish a maintained mobile backend contingency and named-device matrix |
| [Jan](https://jan.ai/docs/api-server) | User-visible OpenAI-compatible server with API key, host/port, logs, trusted hosts, and CORS controls | Has in-app host/port/start/key controls plus authenticated models/chat/SSE/embeddings | Add trusted-host and CORS allowlists before broad LAN exposure |
| [Layla](https://www.layla-network.ai/) | Official site presents one local interface for GGUF/llama.cpp, LiteRT-LM, and ExecuTorch model formats | PocketLLM has a smaller verified Cactus-backed surface plus remote/Ollama providers and refuses format claims it cannot load-test | Add another maintained mobile backend only with reproducible compatibility, resource, and license evidence |

## Upstream/model research decisions

- The [Cactus Flutter repository](https://github.com/cactus-compute/cactus-flutter) was archived on 2026-07-24 and documents telemetry enabled by default. PocketLLM disables telemetry, blocks its unmanaged download paths, and treats replacement planning as a release risk.
- [Qwen3's official tool-calling format](https://github.com/QwenLM/Qwen3/blob/main/docs/source/getting_started/concepts.md) uses a Hermes-like template with JSON objects inside tool-call tags and supports parallel/multi-step calls. PocketLLM's canonical representation can express these calls, but it does not claim a Qwen-native adapter until model templates are trustworthy.
- [Qwen's official llama.cpp guide](https://github.com/QwenLM/Qwen3/blob/main/docs/source/run_locally/llama.cpp.md) recommends using the chat template embedded in GGUF and notes tool/thinking parsing support. This supports the decision to prefer source metadata over filename heuristics.
- [llama.cpp server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) labels multimodal support experimental. PocketLLM therefore gates images on explicit capability and makes no blanket GGUF vision claim.
- [Microsoft's Phi-4-mini-instruct model card](https://huggingface.co/microsoft/Phi-4-mini-instruct) identifies a 3.8B text model, 128K training context, MIT license, and function-calling post-training. PocketLLM does not add it to a built-in catalog because Cactus compatibility and phone-level context/memory have not been verified.

### 2026 candidate review

| Candidate | Current official evidence | v1.0.36 decision |
|---|---|---|
| [Qwen3.5 0.8B](https://huggingface.co/Qwen/Qwen3.5-0.8B) | Apache-2.0; official card describes a compact unified vision-language model, thinking/non-thinking modes, tool use, and a 262K native context in its documented runtimes | Not catalogued. PocketLLM has not verified Cactus conversion, multimodal projection loading, tool-template behavior, phone memory, or usable phone context. A user-managed compatible remote endpoint may expose it. |
| [LFM2.5 1.2B Instruct](https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct) and [Thinking](https://huggingface.co/LiquidAI/LFM2.5-1.2B-Thinking) | Official cards document about 1.17B parameters, 32K context, GGUF/llama.cpp use, and tool-call conventions. The LFM Open License v1.0 has terms that must be reviewed for a distributor's use. | Not catalogued. File format alone is not proof that the archived Cactus integration can load the architecture or render its templates correctly. Upstream benchmark numbers are not PocketLLM device evidence. |
| [Gemma 3n](https://ai.google.dev/gemma/docs/gemma-3n) | Google documents a phone/laptop/tablet-oriented, 32K, multimodal family using PLE and MatFormer technology under Gemma terms | Not catalogued. PocketLLM has no verified Gemma 3n backend, audio/vision pipeline, projection packaging, or terms acceptance flow. |
| [SmolLM3 3B](https://huggingface.co/HuggingFaceTB/SmolLM3-3B) | Apache-2.0; official card documents 3B parameters, reasoning modes, tool-call formats, long-context configuration, and several deployment paths | Not catalogued. PocketLLM has not validated Cactus architecture/template support or phone memory/thermal behavior. |
| [BGE small English v1.5](https://huggingface.co/BAAI/bge-small-en-v1.5) | MIT-licensed, 133 MB weights, English sentence-transformer/ONNX retrieval model | Researched as a RAG candidate, not bundled. Cactus embedding compatibility and query/document preprocessing must be proven first. |
| [EmbeddingGemma 300M](https://huggingface.co/google/embeddinggemma-300m) | Google documents a multilingual on-device embedding model with 768-dimensional output under Gemma terms and Sentence Transformers | Researched as a multilingual candidate, not bundled. The current backend does not provide the required Gemma 3/Sentence Transformers execution path or terms flow. |

No model in this candidate table is newly claimed as supported. The v1.0.36 local model list remains manifest- and runtime-derived; Ollama and remote providers display only models returned by the configured endpoint.

## Priorities

1. Maintain a signed, dated compatibility manifest generated from actual load tests.
2. Add physical Android/iOS device matrices for model load, throughput, memory pressure, OCR, ASR, and reminders.
3. Add trusted-host/CORS controls to the embedded server.
4. Replace or supplement archived Cactus with a maintained backend without breaking existing user models.
5. Add native model-template adapters only when the runtime exposes authoritative metadata.
