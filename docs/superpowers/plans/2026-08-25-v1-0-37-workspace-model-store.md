# PocketLLM Lite v1.0.37 Implementation Plan

**Goal:** Ship durable Knowledge, Audio, Model Store, Ollama, privacy, and
per-conversation prompt workflows on the verified v1.0.36 base.

**Architecture:** Use additive Hive domain records and shared coordinators.
Keep retrieval and generation business logic in services; screens render typed
state and dispatch commands. Every network operation passes the existing
policy-aware gateway.

**Tech stack:** Flutter, Riverpod, Hive CE, Cactus 1.3, Dio, record,
just_audio, file_picker.

---

## Task 1: Version and durable task domain

**Files:**
- Create: `lib/core/domain/background_task.dart`
- Create: `lib/services/background_task_service.dart`
- Modify: `lib/core/constants/app_constants.dart`
- Modify: `lib/services/storage_service.dart`
- Modify: `lib/main.dart`
- Test: `test/services/background_task_service_test.dart`

Implement additive Hive serialization, task lifecycle rules, structured errors,
startup interruption recovery, retry/cancel commands, and observable task
lists. Register/open the box during normal storage initialization.

## Task 2: Retrieval modes and embedding setup

**Files:**
- Create: `lib/features/rag/domain/rag_models.dart`
- Modify: `lib/services/embedding_service.dart`
- Modify: `lib/services/vector_store_service.dart`
- Modify: `lib/services/rag_service.dart`
- Modify: `lib/features/rag/providers/rag_provider.dart`
- Modify: `lib/features/rag/presentation/document_manager_screen.dart`
- Test: `test/services/rag_retrieval_modes_test.dart`
- Test: `test/services/rag_service_test.dart`

Add persisted Keyword/Semantic/Hybrid selection, compatible-model manifest,
resource gate, truthful model setup, retrieval score diagnostics, and a setup
screen that precedes import when resources are missing.

## Task 3: Durable document indexing

**Files:**
- Modify: `lib/services/document_ingestion_service.dart`
- Modify: `lib/services/vector_store_service.dart`
- Create: `lib/services/document_task_service.dart`
- Modify: `lib/features/rag/providers/rag_provider.dart`
- Modify: `lib/features/rag/presentation/document_manager_screen.dart`
- Test: `test/services/document_task_service_test.dart`

Stage extraction, chunking, optional embedding, and atomic commit behind a
durable task. Add document details, retry/delete, exact page/chunk progress,
and actionable errors.

## Task 4: Model Store and durable downloads

**Files:**
- Create: `lib/features/model_browser/domain/model_store_models.dart`
- Create: `lib/features/model_browser/providers/model_store_provider.dart`
- Create: `lib/services/model_store_service.dart`
- Modify: `lib/services/huggingface_service.dart`
- Modify: `lib/services/model_download_service.dart`
- Modify: `lib/features/model_browser/presentation/model_catalog_screen.dart`
- Modify: `lib/features/model_browser/presentation/model_browser_screen.dart`
- Test: `test/services/model_download_resume_test.dart`
- Test: `test/services/model_store_service_test.dart`

Unify catalog, Hugging Face, installed/imported, and Ollama sources without
mixing their runtime identity. Persist byte progress and partial files. Validate
size/checksum when supplied and expose only supported recovery actions.

## Task 5: Ollama disconnected state

**Files:**
- Modify: `lib/features/chat/presentation/providers/models_provider.dart`
- Modify: `lib/features/settings/presentation/screens/settings_category_screens.dart`
- Test: `test/features/chat/presentation/providers/models_provider_test.dart`

Model unchecked/checking/connected/disconnected explicitly. Check reachability
before list calls and render endpoint-aware retry guidance.

## Task 6: Conversation prompt identity migration

**Files:**
- Modify: `lib/features/chat/domain/models/chat_session.dart`
- Modify: `lib/features/chat/domain/models/chat_session.g.dart`
- Modify: `lib/features/chat/presentation/providers/chat_provider.dart`
- Modify: `lib/features/chat/presentation/dialogs/chat_settings_dialog.dart`
- Modify: `lib/services/storage_service.dart`
- Test: `test/features/chat/system_prompt_persistence_test.dart`

Add `systemPromptId`, backfill by exact content match, persist ID and content on
Apply, and restore the correct selection for each reopened conversation.

## Task 7: Audio recording and transcription workspace

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/media/domain/audio_workspace_models.dart`
- Create: `lib/features/media/providers/audio_workspace_provider.dart`
- Modify: `lib/services/audio_transcription_service.dart`
- Create: `lib/services/audio_recording_service.dart`
- Modify: `lib/features/media/presentation/screens/audio_transcription_screen.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Test: `test/services/audio_transcription_service_test.dart`
- Test: `test/features/media/audio_workspace_test.dart`

Add Record/Upload, permission states, 16 kHz mono WAV recording, pause/resume,
amplitude, playback, rename/save, model setup, persisted language choice,
durable jobs, and truthful whole-text results.

## Task 8: Privacy and navigation cleanup

**Files:**
- Modify: `lib/features/settings/presentation/screens/privacy_network_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/features/settings/presentation/screens/settings_category_screens.dart`
- Modify: `lib/core/router.dart`
- Test: `test/regressions/release_truth_test.dart`
- Test: `test/widget_test.dart`

Remove the duplicate endpoint status card, fix flexible badges, distinguish
network audit from activity, and expose one clear entry for each workspace.

## Task 9: Release documentation and verification

**Files:**
- Modify: `pubspec.yaml`
- Modify: `CHANGELOG.md`
- Modify: `RELEASE_NOTES.md`
- Create: `docs/V1_0_37_VERIFICATION.md`
- Create: `release/GITHUB_RELEASE_NOTES_v1.0.37.md`

Set `1.0.37+37`, format, analyze, run the full tests, execute Android stories,
build release APKs, record signer/hash/size truth, commit, push, and publish the
GitHub release with the produced APK assets only after validation.
