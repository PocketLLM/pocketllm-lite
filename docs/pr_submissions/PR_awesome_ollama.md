# Pull Request: Add PocketLLM Lite to Mobile Apps section

## Description
This PR adds [PocketLLM Lite](https://github.com/PocketLLM/pocketllm-lite) to the **Mobile Apps** section of `awesome-ollama`.

PocketLLM Lite is a source-available, local-first Android client for on-device inference and streaming connections to user-configured Ollama endpoints. The repository currently has no root license grant, so this submission must not call it open source.

## Proposed Entry
```markdown
* [PocketLLM Lite](https://github.com/PocketLLM/pocketllm-lite) - A local-first Android client for configured Ollama endpoints and compatible on-device GGUF models, with document RAG, SKILL.md extensions, and confirmation-gated agent tools.
```

## Features Highlight
- **Ollama Streaming & On-Device GGUF**: Connects to configured Ollama servers or attempts compatible GGUF models through its on-device backend.
- **DeepSeek R1 Thinking Accordion**: Native rendering of `<think>` reasoning blocks.
- **SKILL.md Plugin Architecture**: Standard open format for custom agent skills with `/` autocomplete.
- **Voice Features**: Platform dictation/TTS plus local selected-file Whisper transcription when a compatible model is installed; platform engine network behavior varies.
- **Privacy Controls & Ad-Free**: No ad/analytics SDKs, Cactus telemetry disabled, a network audit, and application-level Strict Offline controls.
