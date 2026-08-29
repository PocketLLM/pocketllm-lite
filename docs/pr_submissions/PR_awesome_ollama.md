# Pull Request: Add PocketLLM Lite to Mobile Apps section

## Description
This PR adds [PocketLLM Lite](https://github.com/PocketLLM/pocketllm-lite) to the **Mobile Apps** section of `awesome-ollama`.

PocketLLM Lite is an MIT-licensed, local-first Android client for on-device inference and streaming connections to user-configured Ollama endpoints.

## Proposed Entry
```markdown
* [PocketLLM Lite](https://github.com/PocketLLM/pocketllm-lite) - An MIT-licensed local-first Android client for configured Ollama endpoints and compatible on-device GGUF models, with document RAG, SKILL.md extensions, and confirmation-gated agent tools.
```

## Features Highlight
- **Ollama Streaming & On-Device GGUF**: Connects to configured Ollama servers or attempts compatible GGUF models through its on-device backend.
- **DeepSeek R1 Thinking Accordion**: Native rendering of `<think>` reasoning blocks.
- **SKILL.md Plugin Architecture**: Standard open format for custom agent skills with `/` autocomplete.
- **Voice Features**: Platform dictation/TTS plus local selected-file Whisper transcription when a compatible model is installed; platform engine network behavior varies.
- **Privacy Controls & Ad-Free**: No ad/analytics SDKs, Cactus telemetry disabled, a network audit, and application-level Strict Offline controls.
