# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Porta-Thoughty is a Flutter application for capturing and organizing thoughts through multiple modalities (voice, text, and image). The app uses a queue-based workflow where captured notes are collected, selected, and then processed into organized Markdown documents.

## Common Commands

### Development
- **Install dependencies**: `flutter pub get`
- **Run the app**: `flutter run`
- **Run on specific device**: `flutter run -d <device-id>`
- **List available devices**: `flutter devices`
- **Hot reload**: Press `r` in the terminal while app is running
- **Hot restart**: Press `R` in the terminal while app is running

### Building
- **Build for Windows**: `flutter build windows`
- **Build for Android**: `flutter build apk`
- **Build for iOS**: `flutter build ios`
- **Build for Linux**: `flutter build linux`
- **Build for macOS**: `flutter build macos`

### Testing & Code Quality
- **Run tests**: `flutter test`
- **Run specific test**: `flutter test test/widget_test.dart`
- **Analyze code**: `flutter analyze`
- **Format code**: `dart format .`

### Maintenance
- **Upgrade packages**: `flutter pub upgrade`
- **Clean build artifacts**: `flutter clean`
- **Rebuild after clean**: `flutter clean && flutter pub get && flutter run`

## Architecture

### State Management
The app uses **Provider** for state management with a single central `PortaThoughtyState` class (lib/state/app_state.dart) that manages:
- Project selection and switching
- Note capture (voice, text, image)
- Queue management with multi-select
- Document generation from selected notes
- User settings (silence timeout, recording duration)

The state class coordinates between services (speech-to-text, database, doc generator) and exposes reactive state to the UI layer.

### Database Layer
**LocalDatabase** (lib/services/local_database.dart) provides SQLite-based persistence using:
- `sqflite` for Android/iOS
- `sqflite_common_ffi` for Windows/Linux/macOS

Schema includes three main tables:
- `projects`: User-defined collections/categories
- `notes`: Individual captured thoughts (soft-deletable, processable)
- `docs`: Generated Markdown documents with metadata
- `settings`: Key-value store for user preferences

Database initialization happens in `LocalDatabase.init()` and ensures schema compatibility across platforms.

### Core Data Flow
1. **Capture**: User creates notes via voice (speech-to-text), text input, or image OCR
2. **Queue**: Notes accumulate in the Queue screen, organized by project
3. **Selection**: User selects multiple notes for batch processing
4. **Processing**: Selected notes are compiled into a Markdown document and saved to disk
5. **Docs**: Processed documents appear in the Docs screen with metadata and can be shared

### Key Models
- **Note** (lib/models/note.dart): Represents a captured thought with type (voice/text/image), project association, and processing state
- **Project** (lib/models/project.dart): Collection/category for organizing notes with name, color, icon, and optional AI prompt
- **ProcessedDoc** (lib/models/processed_doc.dart): Metadata for generated Markdown files with source note tracking
- **UserSettings** (lib/models/user_settings.dart): User preferences stored in database

### Services
- **NativeSpeechToTextService** (lib/services/native_speech_to_text.dart): Wraps the speech_to_text plugin for cross-platform voice capture with callback-based result handling
- **DocGenerator** (lib/services/doc_generator.dart): Generates Markdown files from note batches, organizing them in project subdirectories under app support directory

### Navigation
The app uses a bottom navigation bar (lib/main.dart) with three main screens:
- **CaptureScreen**: Primary input interface with voice recording, quick actions, and recent notes preview
- **QueueScreen**: Full list of unprocessed notes with multi-select and batch processing
- **DocsScreen**: Archive of generated Markdown documents

All screens are mounted in an `IndexedStack` for state preservation during navigation.

### Platform-Specific Notes
- Windows/Linux/macOS require `sqflite_common_ffi` initialization
- Speech recognition requires runtime permissions (handled by speech_to_text plugin)
- Document storage uses platform-specific application support directory via path_provider

### Theming
Custom theme defined in lib/theme/app_theme.dart with gradient backgrounds and consistent Material Design 3 styling.

## Development Patterns

### Adding New Note Types
1. Add enum value to `NoteType` in lib/models/note.dart
2. Update `Note.preview` getter for display text
3. Add capture UI in CaptureScreen
4. Update `_summarizeNote` in app_state.dart for document generation
5. Update `_appendNote` in doc_generator.dart for Markdown formatting

### Adding New Projects
Projects are created via database inserts. The "Inbox" project is created by default in `LocalDatabase.ensureDefaultProject()`.

### Modifying Database Schema
Schema changes require migration logic in `LocalDatabase.init()`. Current version is 1. For schema updates:
1. Increment version number in `openDatabase()`
2. Add migration logic in `onUpgrade` callback
3. Test migration from previous version

### Working with Settings
Settings are stored as key-value pairs. To add new settings:
1. Add property to `UserSettings` class
2. Add storage key constant
3. Update `toStorage()` and `fromStorage()` methods
4. Add UI controls in settings screen (when implemented)
5. Use `PortaThoughtyState.updateSilenceTimeout()` pattern for persistence
