# Porta-Thoughty Build Plan

## Phase 1 Â- Voice Capture & Transcription
1. **Permissions & service plumbing**
   - Handle `RECORD_AUDIO` runtime permissions (Android 12+ best practices).
   - Introduce a reliable recording pipeline (foreground service + platform channel or audio plugin).
   - Persist temporary audio in cache; ensure cleanup on cancel/finish.
2. **Silence detection & auto-stop**
   - Implement configurable silence timeout (default 8â€¯s) with UI feedback and manual stop.
3. **Transcription engine**
   - Bundle or download Whisper Tiny (~75â€¯MB) and integrate via FFI/plugin.
   - Capture confidence metrics; flag transcripts <60% as low confidence.
   - Delete audio once transcribed unless flagged for recheck.
4. **Queue integration**
   - Replace mock voice logic with real capture/transcription.
   - Feed completed transcripts into the notes queue (temporary in-memory until Phase 2).

## Phase 2 Â- Local Persistence & Data Model
1. **SQLite schema**
   - Implement `projects`, `notes`, `docs`, `settings` tables (`is_processed`, `deleted_at`, etc.).
   - Use `drift`/`sqflite` with migrations tested.
2. **Repository layer**
   - Build repositories/DAOs for projects, notes, docs, settings with reactive streams.
3. **State integration**
   - Swap mock provider state for repository-backed providers; seed Inbox project on first launch.
   - Implement soft delete + 7-day undo and optional archive view.
4. **File storage layout**
   - Mirror `/Android/data/<app_id>/projects/<slug>/` structure; enqueue future encryption hooks.

## Phase 3 Â- Image Capture & OCR
1. **Capture/import flows**
   - Hook up CameraX (`camera` plugin) and Android Photo Picker (14+ compliant, legacy fallback).
   - Support multi-select gallery import with sequential confirmation dialogs.
2. **Image processing**
   - Auto-rotate, strip EXIF, compress to ~85â€¯% JPEG; save in project doc assets when retained.
   - Delete temp images when not included.
3. **OCR integration**
   - Integrate on-device ML Kit text recognition with confidence scores.
   - Follow smart include-image logic and edit-before-save UI.

## Phase 4 Â- Text Notes & UI Polish
1. **Markdown text entry**
   - Finalize editor with preview toggle; respect Markdown shortcuts.
2. **Gestures & feedback**
   - Add swipe actions (Process/Delete/Edit) with haptics and confirmations.
3. **Widgets**
   - Implement global quick capture widget + per-project widgets; long-press default project.
4. **Onboarding & empty states**
   - Build 3-step first-launch flow; refine queue/docs empty-state illustrations/copy.

## Phase 5 Â- LLM Processing Pipeline
1. **Prompt management**
   - Persist project-specific prompts; build request composer with metadata.
2. **Token estimation**
   - Local estimator (~100 tokens/note) with auto-chunking; warn for >40 notes; show cost estimates when API key present.
3. **Provider integration**
   - Default Groq Llama 3 integration; configure optional OpenAI/Anthropic fallbacks with rate-limit handling.
4. **Doc creation workflow**
   - Save Markdown, auto-title docs, copy approved images, mark source notes processed (soft delete/undo).

## Phase 6 Â- Audio & OCR Stub Handling
1. **Low-confidence audio stubs**
   - Encrypt/store audio for flagged transcripts; expire after 7 days; UI for re-transcribe/play/delete.
2. **FTS5 search**
   - Add SQLite FTS index over `notes.text` + `ocr_edited`; global search bar per project.

## Phase 7 Â- Settings & Security
1. **Settings UI**
   - Manage default model, API keys, silence timeout, hold-to-record; persist securely (Android Keystore).
2. **Token limits & usage caps**
   - Track token usage; enforce free-tier monthly cap; warn before limits.
3. **LLM safety**
   - Confirm large batches; show cost dialogs; log processing history.

## Phase 8 Â- QA, Packaging & Release Prep
1. **Testing**
   - Unit tests for repositories, transcription pipeline, token estimator; widget/integration tests for key flows.
2. **Performance & monitoring**
   - Add logging/telemetry (Crashlytics/Sentry optional); monitor image/audio cleanup.
3. **Packaging**
   - Prepare Android app bundle/signing; draft release notes and beta test plan.
