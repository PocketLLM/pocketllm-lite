# PocketLLM Lite v1.0.37 Workspace and Model Store Design

## Goal

Turn the existing proof-level RAG, audio transcription, model download, and
per-chat prompt features into durable user workflows without weakening the
local-first and Strict Offline guarantees delivered in v1.0.36.

## Release boundary

The release is `1.0.37+37`. GitHub currently has v1.0.35 as the latest
published release; the unreleased v1.0.36 branch is the engineering base for
this work. v1.0.37 therefore includes both the v1.0.36 reliability work and
the workspace improvements in this design.

## Architecture choice

Build incrementally on the verified v1.0.36 architecture:

- keep the existing persistent vector archive and its real BM25, cosine,
  reciprocal-rank fusion, and MMR retrieval;
- add typed retrieval modes and a setup gate instead of replacing retrieval
  with a dense-only SDK abstraction;
- add one Hive-backed task repository shared by document indexing, model
  downloads, and audio transcription;
- wrap the pinned Cactus runtime and catalog behind PocketLLM services so every
  request still passes through the network policy and audit path;
- preserve the single `GenerationPipeline` for every completion;
- migrate chat records in place by adding a prompt identifier while retaining
  the stored prompt content used for inference.

A Cactus-first rewrite was rejected because the pinned Flutter package performs
its own direct network requests, has no resumable download contract, and its
sample RAG path is dense-only. A screen-local patch was rejected because it
would lose downloads and jobs on navigation or restart.

## Durable task model

`BackgroundTask` records have a stable ID, type, title, state, progress,
phase, timestamps, retry metadata, optional local/remote paths, byte counters,
and a structured error. Records are persisted before work starts. On app
startup, an in-flight process that cannot be resumed is changed to
`interrupted`, never falsely left as running.

Task progress is evidence-based:

- HTTP downloads use received and total bytes when a total is known;
- document indexing reports pages and chunks processed;
- transcription uses indeterminate processing when the backend exposes no
  timing progress.

Pause and resume are enabled only when the remote server proves byte-range
support and a validator is available. A `.part` file is committed atomically
after size and optional checksum validation. Cancelled work retains only data
that can safely resume; otherwise temporary data is removed.

## Knowledge workspace

The Knowledge Base opens into a resource/setup state rather than a file picker.
Users choose:

- Keyword: real BM25 retrieval, no embedding model required;
- Semantic: cosine retrieval, embedding model required;
- Hybrid: BM25 plus cosine rank fusion, embedding model required.

Only catalog entries explicitly marked as embedding-compatible are offered.
For the pinned Cactus catalog the proven entries are
`qwen3-0.6-embed` and `nomic2-embed-300m`; catalog metadata remains the source
of truth for size and download URL. Setup and download state survive restart.

Document ingestion runs as a staged task: validate and copy source, extract
pages, chunk text, create required embeddings, then atomically publish the
document and chunks. Failure or cancellation never exposes a half-indexed
document. Document details show source, page/chunk counts, retrieval mode,
timestamps, status, and actionable failure information. Retrieval debug output
shows the actual keyword, semantic, and fused scores used to select citations.

## Audio workspace

Audio has Record and Upload entry points. Recording is foreground-only and
uses mono 16 kHz PCM WAV for deterministic compatibility. The UI exposes
start, pause, resume, stop, cancel, elapsed time, measured amplitude, playback,
rename, save, and transcribe. Microphone denial is an actionable state.

Transcription requires an installed speech model and therefore has an explicit
setup state. Jobs are durable tasks and results are saved with source path,
language choice, model, timestamps, and full text. The pinned Cactus 1.3 API
returns whole-text transcription without segment timing, so the app must not
invent segment timestamps. Language choices are passed through the backend
prompt adapter; Auto Detect is shown only when the installed backend can omit
the forced language token truthfully.

## Model Store

The Model Store is the central discovery and download surface. It separates:

- On-device catalog models managed by PocketLLM;
- Hugging Face GGUF results imported through verified metadata;
- local GGUF files selected with Browse Files;
- Ollama models supplied by the configured Ollama host.

Search, runtime/capability filters, details, license/source metadata, local
state, and durable download actions use the same task repository. Managed GGUF
always means on-device files; it never labels Ollama models. Hugging Face
results come from its live API and keep source/revision/file metadata needed
for reproducible downloads.

Ollama starts in an explicit disconnected/unchecked state. The app checks the
configured endpoint before requesting or displaying its model list and offers
a targeted retry or endpoint action on failure.

## Conversation prompt identity

`ChatSession` gains `systemPromptId` as an additive Hive field. Existing chats
are backfilled by exact content match where possible and retain their prompt
content regardless. Applying settings persists both ID and content. Reopening,
restarting, and switching conversations restores that session's selection;
the stored content continues to feed the central generation pipeline.

## Privacy and navigation

Privacy & Network is reduced to controls and audit truth: Strict Offline,
optional online capabilities, discovery, endpoint policy, network activity,
and clear-data actions. The redundant inference endpoint status panel moves to
Models/System. Local badges use flexible layout at 360 dp and large text.
Activity history and network audit remain distinct and are labeled accordingly.

Settings navigation uses one entry for each destination: Models, Knowledge,
Audio, Providers, Privacy & Network, and System. Legacy routes remain as
redirects where needed so bookmarks and tests do not break.

## Failure and offline rules

Every operational failure contains what failed and an available next action.
Strict Offline blocks catalog search, downloads, remote Ollama, and remote
providers before any request; local files, keyword retrieval, installed model
inference, loopback Ollama, recording, and saved transcription remain usable.
No placeholder success, synthetic progress, fabricated citations, or invented
audio timing is permitted.

## Verification

Unit and widget fixtures cover task migration/restart, all three retrieval
modes, atomic document commit, prompt identity persistence, disconnected
Ollama, download validation, and audio job persistence. Static analysis and the
full Flutter test suite must pass. Android stories cover first-run RAG setup,
document retrieval/citations, record and upload transcription, model download
recovery, chat prompt restoration, disconnected Ollama, Strict Offline, and
360 dp/large-text layouts. Device-only audio evidence is called out separately
from emulator evidence.
