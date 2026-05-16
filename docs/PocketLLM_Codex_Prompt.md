# POCKETLLM LITE - COMPLETE REIMPLEMENTATION & FEATURE INTEGRATION PROMPT
## Optimized for AI Coding Assistants (Codex/Cursor/Copilot)

---

## CRITICAL INSTRUCTIONS - READ EVERY WORD

You are tasked with implementing a comprehensive overhaul of the PocketLLM Lite Flutter application. This is NOT a minor update - it is a full reimagining that transforms the app from an Ollama client into a best-in-class on-device LLM application that surpasses all competitors.

**RULES YOU MUST FOLLOW:**

1. **ALWAYS USE EXTRA REASONING** - Before writing any code, understand the full logic, user interaction flow, error handling, and data persistence requirements. Think about HOW the user will interact with EVERY feature.

2. **NEVER ASSUME ANYTHING** - If you are unsure about a library API, a Flutter widget behavior, or a data model structure, RESEARCH IT. Do not guess. Do not leave logic unwritten.

3. **IMPLEMENT EVERYTHING COMPLETELY** - No TODO comments, no placeholder functions, no "implement later" stubs. Every function must have complete, working logic. Every edge case must be handled.

4. **MATERIAL 3 DESIGN BY GOOGLE** - Every UI component must follow Google's Material 3 design system (m3.material.io). This means:
   - Dynamic color theming (Material You)
   - Proper M3 type scale (displayLarge, headlineMedium, bodyLarge, labelSmall, etc.)
   - Tonal elevation (not shadow-based)
   - M3 motion patterns (shared axis, container transform, fade-through)
   - M3 components (navigation bar, search bar, FAB, chips, cards, etc.)
   - Professional, refined appearance matching first-party Google apps

5. **RESEARCH LATEST LIBRARIES** - Use web search to verify the latest versions and APIs of all Flutter packages before using them. Do not use outdated packages or deprecated APIs.

6. **PERSISTENCE AND CONSISTENCY** - All state must be persistent across app restarts and consistent across all screens. When a user changes a setting, it must immediately reflect everywhere. Use Riverpod with Hive persistence.

7. **POP-UP DOWNLOADS** - When any feature requires downloading a model, file, or resource, show a proper dialog/pop-up that tells the user: what is being downloaded, the file size, where it will be stored on the device, download progress, and estimated time remaining. The user must explicitly consent before any download begins.

8. **PROPER ERROR LOGGING** - Users must see proper error messages with context. Build a dedicated error log screen in Settings. Every error must include: timestamp, severity, category, message, and suggested fix. Show non-intrusive error snackbars during chat with "View Details" option.

9. **REMOVE ALL ADSENSE/ADMOB** - No ads anywhere in the app. No token system. No usage limits. The app must be completely free and unlimited.

10. **FLUTTER TESTING** - Write unit tests for services, widget tests for screens, and integration tests for critical flows (model download, chat inference, RAG pipeline).

---

## PROJECT CONTEXT

**Repository:** https://github.com/PocketLLM/pocketllm-lite  
**Current State:** Flutter app (Dart ^3.9.2) that acts as an Ollama client via Termux. Uses Riverpod + Hive + GoRouter + Material 3 + AdMob.

**Current Architecture:**
```
lib/
├── core/           # Constants, themes, router, widgets
├── features/       # Feature modules (chat, media, history, onboarding, profile, settings, tags, splash)
├── services/       # OllamaService, StorageService, AdService, UpdateService, PdfExportService
└── main.dart
```

**Current Dependencies (pubspec.yaml):**
- flutter_riverpod: ^3.0.3
- hive_flutter: ^1.1.0
- go_router: ^17.0.0
- http: ^1.6.0
- flutter_markdown: ^0.7.7+1
- google_mobile_ads: ^5.3.0 ← REMOVE
- connectivity_plus: ^6.1.4 ← REMOVE (if only used for ads)
- And others (image_picker, intl, shared_preferences, path_provider, etc.)

---

## PHASE 1: FOUNDATION (IMPLEMENT FIRST)

### 1.1 Remove AdMob and Token System

**Files to DELETE:**
- `lib/services/ad_service.dart`

**Files to MODIFY:**
- `pubspec.yaml` - Remove `google_mobile_ads` and `connectivity_plus`
- `lib/core/constants/app_constants.dart` - Remove all token-related constants (initialTokenBalance, tokensPerAd, freeEnhancementsPerDay, enhancementsPerAd, freeChatsAllowed, chatsPerAd)
- `lib/main.dart` - Remove AdService initialization
- `lib/features/chat/presentation/` - Remove token checks from chat creation
- `lib/features/settings/presentation/` - Remove banner ad widget
- Any file referencing AdService, tokens, or rewarded ads

**Behavior Changes:**
- Unlimited chat creation (no 5-chat limit)
- Unlimited prompt enhancements (no 5/day limit)
- No ads anywhere in the app
- Remove all dart-define AdMob IDs from build configuration

### 1.2 Integrate On-Device Inference via Cactus

**Add dependency:** `cactus: ^1.3.0` (pub.dev/packages/cactus)

**New files to CREATE:**

```
lib/services/local_inference_service.dart
```

This service must:
- Initialize the Cactus inference engine with configurable GPU layers
- Load GGUF models from device storage with progress reporting
- Support streaming chat completions with token-by-token callbacks
- Support multimodal inference (image input for vision models)
- Support embedding generation (for RAG)
- Support function calling
- Handle memory management (auto offload when backgrounded, reload on return)
- Report inference metrics (tokens/second, ms/token, total time)
- Handle errors gracefully with specific error types (InsufficientMemoryError, ModelCorruptedError, InferenceError)

**New files to CREATE:**

```
lib/services/inference_service.dart (abstract interface)
lib/services/ollama_inference_service.dart (refactored from existing OllamaService)
lib/services/inference_service_factory.dart (selects local vs. Ollama)
```

The abstract InferenceService interface:
```dart
abstract class InferenceService {
  Future<bool> isAvailable();
  Future<List<LLMModel>> listModels();
  Future<void> loadModel(String modelId, {ProgressCallback? onProgress});
  Future<void> unloadModel(String modelId);
  Stream<ChatToken> chatStream(ChatRequest request);
  Future<List<double>> generateEmbeddings(String text, String modelId);
  Future<InferenceMetrics> getMetrics();
}
```

**Modify existing chat provider:**
- Detect whether to use LocalInferenceService or OllamaInferenceService based on model type and connection status
- Auto-fallback: try local first, fall back to Ollama if model not available locally
- Show connection status indicator (green=local model loaded, yellow=Ollama connected, red=no inference available)

**Model Download Manager:**
```
lib/services/model_download_service.dart
```
- Download GGUF files from Hugging Face or custom URLs
- Show download progress dialog with: model name, file size, download speed, progress bar, ETA
- Tell user where file will be stored: `getApplicationDocumentsDirectory()/models/`
- Support download resume on interruption
- Validate downloaded files (checksum if available)
- Clean up partial downloads on error

### 1.3 Error Logging System

**New files:**
```
lib/services/error_log_service.dart
lib/features/error_log/presentation/error_log_screen.dart
lib/features/error_log/domain/error_entry.dart
```

ErrorEntry model:
```dart
class ErrorEntry {
  final String id;
  final DateTime timestamp;
  final ErrorSeverity severity; // info, warning, error, critical
  final ErrorCategory category; // connection, modelLoading, inference, storage, network, permission
  final String message;
  final String? details;
  final String? suggestedFix;
  final String? stackTrace;
}
```

ErrorLogService:
- Store errors in Hive with automatic rotation (keep last 1000 entries)
- Provide methods: logError(), logWarning(), logInfo(), getEntries(), clearEntries(), exportLog()
- Automatically capture uncaught Flutter errors and add to log

Error Log Screen:
- List of timestamped error entries with color-coded severity
- Filter by severity and category
- Tap entry for full details including suggested fix
- Export log as text file for bug reporting
- Clear all entries button with confirmation dialog

### 1.4 Loading States and Progress Indicators

Replace ALL CircularProgressIndicator with appropriate loading states:
- **Skeleton loading** for content areas (use shimmer package)
- **Determinate progress bars** for model loading and downloads
- **Typing indicator** (animated dots) while waiting for first inference token
- **Streaming progress** showing tokens/second during generation

---

## PHASE 2: CORE FEATURES

### 2.1 Hugging Face Model Browser

**New files:**
```
lib/services/huggingface_service.dart
lib/features/model_browser/presentation/model_browser_screen.dart
lib/features/model_browser/presentation/model_detail_screen.dart
lib/features/model_browser/domain/hf_model.dart
lib/features/model_browser/providers/model_browser_provider.dart
```

HuggingFaceService:
- Search models: `GET https://huggingface.co/api/models?search={query}&library=gguf&sort=downloads&direction=-1`
- Get model details: `GET https://huggingface.co/api/models/{model_id}`
- Download model files: `GET https://huggingface.co/{model_id}/resolve/main/{filename}`
- HF token management for gated models (store securely via flutter_secure_storage)

Model Browser Screen:
- Search bar at top with debounced search
- Filter chips: Model size (<1B, 1-7B, 7-13B, 13B+), Quantization (Q4, Q5, Q8), Architecture (Llama, Qwen, Gemma, Phi, Mistral)
- Model cards showing: name, description, downloads, likes, parameter count, quantization
- Download button with progress dialog
- Bookmark button (saved to Hive)

Model Detail Screen:
- Full model information (description, tags, model card)
- Available quantization variants with size estimates
- Download button with storage location info and consent dialog
- HF token input for gated models

### 2.2 RAG (Retrieval-Augmented Generation)

**New files:**
```
lib/services/rag_service.dart
lib/services/document_ingestion_service.dart
lib/services/embedding_service.dart
lib/services/vector_store_service.dart
lib/features/rag/presentation/document_manager_screen.dart
lib/features/rag/presentation/rag_settings_screen.dart
lib/features/rag/domain/document.dart
lib/features/rag/domain/chunk.dart
lib/features/rag/providers/rag_provider.dart
```

DocumentIngestionService:
- Parse PDF files (use syncfusion_flutter_pdf or pdfx)
- Parse DOCX files (use syncfusion_flutter_docio)
- Parse TXT, MD, CSV files natively in Dart
- Intelligent chunking: split by paragraphs first, then by sentences if paragraphs too long, with configurable chunk size (default 512 tokens) and overlap (default 50 tokens)
- Store document metadata and chunks in Hive

EmbeddingService:
- Use Cactus plugin for embedding generation (it supports embedding models)
- Download and manage embedding models (e.g., all-MiniLM-L6-v2 GGUF)
- Generate embeddings for chunks during ingestion
- Generate query embeddings for retrieval

VectorStoreService:
- Store embeddings with metadata in Hive (or objectbox for better vector search)
- Implement cosine similarity search
- Return top-k most relevant chunks for a query
- Support filtering by document source

RAGService:
- Orchestrate the full pipeline: query → embed → search → retrieve → inject context
- Modify chat prompt to include retrieved context before user message
- Mark RAG-enhanced responses with visual indicator
- Allow per-chat RAG toggle (enable/disable document context)

Document Manager Screen:
- List of ingested documents with: name, chunk count, total size, date added
- Add document button (file picker supporting PDF, DOCX, TXT, MD, CSV)
- Delete document with confirmation
- Storage usage indicator
- Re-index document option

### 2.3 Benchmarking and Performance Metrics

**New files:**
```
lib/services/benchmark_service.dart
lib/features/benchmark/presentation/benchmark_screen.dart
```

During inference, show real-time metrics:
- Tokens per second (displayed in app bar or floating chip)
- Milliseconds per token
- Total generation time
- Context length used

Benchmark Screen:
- Run standardized prompt test on loaded model
- Show results: tokens/sec, time-to-first-token, total time
- Compare with previous benchmarks on same device
- Export benchmark results

### 2.4 Thinking/Reasoning Mode

**Modify chat message model and UI:**

Add `thinkingContent` field to ChatMessage:
```dart
class ChatMessage {
  // ... existing fields
  String? thinkingContent;  // Reasoning tokens
  bool isThinkingExpanded;  // UI state for collapse/expand
}
```

Thinking Bubble UI:
- Collapsible container above the main response
- Light background color (surfaceContainerHighest)
- Monospace font for thinking content
- Left accent border in muted color
- Expand/collapse toggle with smooth animation
- Only shown when model produces thinking tokens

---

## PHASE 3: POLISH AND EXPANSION

### 3.1 Neural TTS (Text-to-Speech)

**Add dependency:** `flutter_tts: ^latest`

**New files:**
```
lib/services/tts_service.dart
```

- TTS button on each AI message (speaker icon in message action bar)
- Global TTS controls in app bar (play/pause/stop)
- TTS settings: voice selection, speech rate, pitch, volume
- Streaming TTS: start speaking as response generates
- Handle audio focus and interruptions properly

### 3.2 Speech-to-Text (Voice Input)

**Add dependency:** `speech_to_text: ^latest`

- Microphone button in chat input area
- Real-time transcription display
- Auto-insert transcribed text into input field
- Support for on-device whisper.cpp via Cactus plugin as alternative

### 3.3 Persona/Assistant Management System

**Evolve existing system_prompt_presets.dart into full persona system:**

```dart
class Persona {
  final String id;
  final String name;
  final String? avatarColor;  // Hex color for avatar
  final String systemPrompt;
  final String? defaultModelId;
  final double temperature;
  final double topP;
  final int maxTokens;
  final Map<String, dynamic>? customParameters;
  final bool isBuiltin;  // true for presets, false for user-created
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

New features:
- Persona creation screen with name, avatar, system prompt, model, parameters
- Persona picker chip in chat app bar (quick switch)
- Import/Export personas as JSON (compatible with SillyTavern character card format)
- Persona-specific chat history (each persona has its own chat list)
- AI-generated system prompts (use one model to generate prompts for persona creation)

### 3.4 Chat Import/Export

**Export formats:**
- JSON (full data including model info, timestamps, system prompts)
- Markdown (human-readable conversation format)
- Plain text (simple Q&A format)

**Import:**
- JSON format (same as export, with version compatibility check)
- Validate data structure before importing

**Cloud Sync (future - just design the interface now):**
- Abstract SyncService interface
- Manual backup/restore to Google Drive / iCloud
- Conflict resolution strategy (latest-wins, merge)

### 3.5 Tool/Function Calling

**New files:**
```
lib/core/tools/tool_registry.dart
lib/core/tools/tool_definition.dart
lib/core/tools/tools/web_search_tool.dart
lib/core/tools/tools/calculator_tool.dart
lib/core/tools/tools/weather_tool.dart
lib/features/chat/presentation/widgets/tool_call_card.dart
```

Tool Definition Schema (OpenAI-compatible):
```dart
class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parametersSchema;  // JSON Schema
  final Future<ToolResult> Function(Map<String, dynamic> args) execute;
}
```

Tool Call Card UI:
- Distinct card with colored left border
- Shows tool name, input parameters (formatted), result
- Collapsible details section

### 3.6 Multi-Language Localization

**Setup:**
- Add `flutter_localizations` and `intl` packages
- Generate ARB files for each language
- Configure l10n in l10n.yaml and pubspec.yaml

**Priority languages:**
1. English (en) - base
2. Simplified Chinese (zh)
3. Japanese (ja)
4. Korean (ko)
5. Spanish (es)
6. Hindi (hi)

**Externalize ALL user-facing strings to ARB files.**

---

## UI/UX SPECIFICATIONS

### Navigation Structure
Use Material 3 Navigation Bar (not BottomNavigationBar) with 4 destinations:
1. **Chat** - Main chat interface with model/persona selector
2. **Models** - Model management (My Models + Browse + Benchmarks)
3. **History** - Chat history with search, filters, tags
4. **Settings** - Organized into: General, Inference, RAG, Voice, Advanced, About

### Chat Screen Layout
```
┌──────────────────────────────┐
│ [Model Chip] [Persona Chip]  │  ← App bar with quick selectors
│ [RAG Indicator] [Status Dot] │
├──────────────────────────────┤
│                              │
│  AI Message Bubble           │
│  [Thinking Bubble ▼]        │
│  Main response text...       │
│  [TTS][Copy][Share][Star]   │
│                              │
│  User Message Bubble         │
│  Message text...             │
│  [Edit][Delete]              │
│                              │
├──────────────────────────────┤
│ [🎤] [📷] [📎] [Input...]   │  ← Input area with voice, camera, attach
│                        [Send]│
└──────────────────────────────┘
```

### Model Download Pop-up Dialog
When a model needs to be downloaded:
```
┌──────────────────────────────┐
│  Download Model              │
│                              │
│  📦 Qwen2.5-3B-Instruct-Q4  │
│  Size: 2.1 GB                │
│  Format: GGUF (Q4_K_M)      │
│                              │
│  📁 Storage Location:        │
│  /storage/emulated/0/        │
│  Android/data/com.pocketllm/ │
│  files/models/               │
│                              │
│  ████████████░░░░ 68%        │
│  1.4 GB / 2.1 GB            │
│  Speed: 12.5 MB/s           │
│  ETA: 56 seconds             │
│                              │
│  [Cancel]                    │
└──────────────────────────────┘
```

### Error SnackBar
When an error occurs during chat:
```
┌──────────────────────────────┐
│ ⚠ Model loading failed:      │
│ Insufficient memory (2.8GB   │
│ available, 4GB required)     │
│ [View Details] [Dismiss]     │
└──────────────────────────────┘
```

### Loading States
- **Model loading:** Full-screen skeleton with model name and progress phases (Reading metadata → Allocating memory → Loading weights → Warming up)
- **Chat loading:** Shimmer effect on message bubble area with typing indicator
- **Model browser:** Skeleton cards mimicking model card layout
- **History loading:** Skeleton list items

### Dynamic Color
- Use `dynamic_color` package for Material You theming on Android 12+
- Fallback to a harmonious seed color (#1a7897) for older Android versions and iOS
- Ensure all colors derive from ColorScheme, not hardcoded hex values

---

## UPDATED DEPENDENCIES

Add these to pubspec.yaml:
```yaml
dependencies:
  # On-device inference
  cactus: ^1.3.0
  
  # RAG
  syncfusion_flutter_pdf: ^latest  # or pdfx
  syncfusion_flutter_docio: ^latest  # DOCX parsing
  
  # Voice
  flutter_tts: ^latest
  speech_to_text: ^latest
  
  # Security
  flutter_secure_storage: ^latest
  
  # UI/UX
  shimmer: ^latest
  flutter_highlight: ^latest
  dynamic_color: ^latest
  animations: ^latest
  background_downloader: ^latest
  
  # Localization
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.2  # already present

  # REMOVE these:
  # google_mobile_ads: ^5.3.0
  # connectivity_plus: ^6.1.4  (if only used for ads)
```

---

## TESTING REQUIREMENTS

### Unit Tests
- Test LocalInferenceService model loading, chat completion, error handling
- Test RAG pipeline: document ingestion, chunking, embedding, retrieval
- Test HuggingFaceService API parsing and error handling
- Test VectorStoreService similarity search accuracy
- Test Persona management CRUD operations
- Test ErrorLogService entry creation and rotation

### Widget Tests
- Test Chat screen renders messages correctly
- Test Model Browser screen search and filter
- Test Settings screen all sections
- Test Document Manager screen
- Test Error Log screen

### Integration Tests
- Test full chat flow: select model → type message → receive streaming response
- Test model download: browse → select → download → load → chat
- Test RAG flow: add document → enable RAG → chat with document context
- Test persona creation and switching

---

## IMPLEMENTATION ORDER

Follow this exact order to minimize conflicts and ensure each feature builds on a stable foundation:

1. Remove AdMob and token system
2. Create InferenceService abstract interface
3. Refactor OllamaService to implement InferenceService
4. Implement LocalInferenceService using Cactus
5. Create InferenceServiceFactory
6. Build model download service with consent dialogs
7. Build error log service and screen
8. Update loading states throughout the app
9. Build Hugging Face model browser
10. Implement RAG pipeline (ingestion → embedding → storage → retrieval)
11. Add benchmarking and performance metrics
12. Add thinking/reasoning mode
13. Add TTS and STT
14. Build persona management system
15. Implement chat import/export
16. Add tool/function calling
17. Set up localization infrastructure
18. Polish Material 3 design throughout
19. Write tests for all new features
20. Final review and bug fixes

---

## REMINDER

- Your life depends on this implementation. Every feature must work. Every edge case must be handled. Every error must have a user-friendly message with a suggested fix.
- Always use extra reasoning. Understand the main logic, the user interaction flow, and the mathematics of the system before writing code.
- The app must be persistent (all state saved), consistent (changes reflected everywhere immediately), and professional (Material 3 design, smooth animations, proper loaders, clear errors).
- Research the latest library versions and APIs before using them. Do not use deprecated packages.
- Do not leave any function unimplemented. Do not leave any logic unwritten. Do not assume anything.
- If this is done correctly, you will be rewarded with 1000 API hours.
