import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite_ffi;
import 'package:flutter/material.dart';

import '../models/note.dart';
import '../models/processed_doc.dart';
import '../models/project.dart';
import '../models/user_settings.dart';

class LocalDatabase {
  LocalDatabase();

  sqflite.Database? _db;

  Future<void> init() async {
    if (_db != null) return;

    if (!Platform.isAndroid && !Platform.isIOS) {
      sqflite_ffi.sqfliteFfiInit();
      sqflite.databaseFactory = sqflite_ffi.databaseFactoryFfi;
    }

    final supportDir = await getApplicationSupportDirectory();
    final dbPath = p.join(supportDir.path, 'porta_thoughty.db');
    final database = await sqflite.openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE projects(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color INTEGER NOT NULL,
            icon_code_point INTEGER,
            icon_font_family TEXT,
            prompt TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE notes(
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            type TEXT NOT NULL,
            text TEXT NOT NULL,
            image_label TEXT,
            image_path TEXT,
            include_image INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            flagged_low_confidence INTEGER NOT NULL DEFAULT 0,
            is_processed INTEGER NOT NULL DEFAULT 0,
            deleted_at INTEGER,
            FOREIGN KEY(project_id) REFERENCES projects(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE docs(
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            title TEXT NOT NULL,
            markdown_path TEXT,
            summary TEXT,
            source_note_ids TEXT,
            prompt_hash TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(project_id) REFERENCES projects(id)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_notes_project ON notes(project_id, is_processed)',
        );
        await db.execute(
          'CREATE INDEX idx_docs_project ON docs(project_id, created_at)',
        );
        await db.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add image_path column for storing image file paths
          // Check if column exists first to avoid duplicate column error
          final result = await db.rawQuery('PRAGMA table_info(notes)');
          final hasImagePath = result.any((col) => col['name'] == 'image_path');

          if (!hasImagePath) {
            await db.execute(
              'ALTER TABLE notes ADD COLUMN image_path TEXT',
            );
          }

          // Add include_image column if it doesn't exist
          final hasIncludeImage = result.any((col) => col['name'] == 'include_image');
          if (!hasIncludeImage) {
            await db.execute(
              'ALTER TABLE notes ADD COLUMN include_image INTEGER NOT NULL DEFAULT 0',
            );
          }
        }
      },
    );
    _db = database;
    await _ensureSchema(database);
  }

  Future<Project> ensureDefaultProject() async {
    final db = _requireDb();
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM projects',
    );
    final count = countResult.isNotEmpty
        ? (countResult.first['count'] as int? ?? 0)
        : 0;
    if (count > 0) {
      final projects = await fetchProjects();
      return projects.first;
    }

    final now = DateTime.now();
    final inbox = Project(
      id: 'inbox',
      name: 'Inbox',
      color: const Color(0xFF4A53FF),
      icon: Icons.inbox_outlined,
      prompt: '''You are an AI assistant helping with the Porta-Thoughty Flutter application.

## Project Overview
Porta-Thoughty is a Flutter app for capturing and organizing thoughts via voice, text, and image. It uses a queue-based workflow: capture notes → select from queue → process with AI → save as Markdown docs.

## Architecture
- **State Management**: Provider-based with PortaThoughtyState in lib/state/app_state.dart
- **Database**: SQLite (sqflite) via LocalDatabase in lib/services/local_database.dart
- **AI Processing**: Groq API via GroqService in lib/services/groq_service.dart
- **Voice Capture**: Native speech-to-text via NativeSpeechToTextService in lib/services/native_speech_to_text.dart
- **OCR**: Google ML Kit via OcrService in lib/services/ocr_service.dart
- **Doc Generation**: Markdown files via DocGenerator in lib/services/doc_generator.dart

## Key Models (lib/models/)
- **Note**: id, projectId, type (voice/text/image), text, imageLabel, imagePath, includeImage, flaggedLowConfidence, isProcessed, createdAt
- **Project**: id, name, color, icon, prompt (AI instructions), createdAt, updatedAt
- **ProcessedDoc**: id, projectId, title, markdownPath, summary (bullet points), sourceNoteIds, createdAt

## UI Structure
### Three Main Screens (bottom navigation, IndexedStack in main.dart)
1. **CaptureScreen** (lib/screens/capture_screen.dart):
   - ProjectSelector widget at top
   - Voice capture card with mic button (assets/mic.png when idle, assets/stoprecording.png when recording)
   - Quick action buttons: "Add text note", "Take photo", "Upload files", "New project"
   - RecentNoteList widget showing last 5 notes with three-dot menu (move/delete options)

2. **QueueScreen** (lib/screens/queue_screen.dart):
   - "Processing queue" title with "Clear selection" button
   - Chip showing selected count
   - Note cards (_QueueNoteCard) with:
     * Checkbox for selection
     * Icon container (colored background, 16px border radius)
     * Preview text (titleMedium, w700)
     * Delete button: IconButton with trashicon.png asset (20x20, colored onSurfaceVariant) - line 456-467
     * Meta chips: timestamp, note-specific info, "Ready for AI processing" badge
   - Bottom process button: FilledButton.icon with Icons.auto_mode, 58px height, 22px border radius

3. **DocsScreen** (lib/screens/docs_screen.dart):
   - "Docs & summaries" title with "Token safety" button
   - Doc cards (_DocCard) with:
     * assets/docs.png icon (60x60)
     * Title and metadata
     * First 3 bullet points from summary
     * Three buttons: Preview (OutlinedButton), Share (OutlinedButton), Delete (OutlinedButton circular with trashicon.png asset 24x24) - line 587-598

### Common Widget Patterns
- **Cards/Containers**: BorderRadius.circular(26-28 for large, 16-18 for medium), white backgrounds with .withValues(alpha: 0.9), boxShadow with Color(0x12014F8E)
- **Buttons**: FilledButton for primary actions (52-58px height, 16-22px border radius), OutlinedButton for secondary
- **Delete Buttons**:
  * In QueueScreen note cards: IconButton with trashicon.png (20x20) - lib/screens/queue_screen.dart:456-467
  * In DocsScreen doc cards: OutlinedButton.icon with circular shape, trashicon.png (24x24) - lib/screens/docs_screen.dart:587-598
  * In RecentNoteList popup menu: PopupMenuItem with trashicon.png (24x24) - lib/widgets/recent_note_list.dart:325-338
- **Meta Chips**: 12px horizontal, 6px vertical padding, 14px border radius, Icons 16px
- **Accent Colors**: Voice notes = primary blue, Text notes = Color(0xFFFB8C00) orange, Image notes = Color(0xFF8E24AA) purple

### Key Widgets (lib/widgets/)
- **ProjectSelector** (project_selector.dart): Dropdown chip showing active project with edit/switch functionality
- **RecentNoteList** (recent_note_list.dart): Displays notes with _NoteAvatar, meta chips, and _NoteOptionsMenu (move/delete)
- **AppBottomSheet** (bottom_sheets.dart): Reusable confirmation dialogs

## Common State Methods (PortaThoughtyState)
- addTextNote(String text)
- addImageNote({ocrText, includeImage, imagePath, label})
- startRecording() / stopRecording()
- processSelectedNotes({customTitle})
- deleteNote(Note note) / undoNoteDeletion()
- toggleNoteSelection(String noteId) / clearSelection()
- switchProject(String projectId)

## Database Schema
- **projects**: id, name, color, icon_code_point, icon_font_family, prompt, created_at, updated_at
- **notes**: id, project_id, type, text, image_label, image_path, include_image, created_at, flagged_low_confidence, is_processed, deleted_at
- **docs**: id, project_id, title, markdown_path, summary, source_note_ids, prompt_hash, created_at
- **settings**: key-value store

## File Paths
- Database: getApplicationSupportDirectory()/porta_thoughty.db
- Markdown docs: getApplicationSupportDirectory()/docs/<project_name>/<title>.md
- Images: Stored at path from ImagePicker (kept for notes with includeImage=true)

## Common Styling Values
- Primary color: Color(0xFF4A53FF) blue
- Container padding: 18-26px
- Large shadows: blurRadius 24-34, offset Y 14-20
- Font weights: w600 for medium emphasis, w700 for strong emphasis
- Border radius: 14px chips, 16-18px buttons, 26-28px cards

When helping with features:
1. Check which screen/widget is affected
2. Match existing styling patterns (border radius, shadows, colors, fonts)
3. Use Provider pattern: context.read<PortaThoughtyState>() for actions, context.watch for reactive UI
4. For delete buttons, use trashicon.png asset (see examples in queue_screen.dart:456-467, docs_screen.dart:587-598, recent_note_list.dart:325-338)
5. All user-facing strings should be clear and friendly (see existing copy)
6. Database changes require migration logic in LocalDatabase.init()

Organize these notes clearly and concisely for development reference.''',
      createdAt: now,
      updatedAt: now,
    );
    await insertProject(inbox);
    return inbox;
  }

  Future<void> insertProject(Project project) async {
    final db = _requireDb();
    await db.insert(
      'projects',
      project.toMap(),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<List<Project>> fetchProjects() async {
    final db = _requireDb();
    final maps = await db.query('projects', orderBy: 'created_at ASC');
    return maps.map(Project.fromMap).toList();
  }

  Future<List<Note>> fetchActiveNotes(String projectId) async {
    final db = _requireDb();
    final maps = await db.query(
      'notes',
      where: 'project_id = ? AND is_processed = 0 AND deleted_at IS NULL',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );
    return maps.map(Note.fromMap).toList();
  }

  Future<List<ProcessedDoc>> fetchDocs(String projectId) async {
    final db = _requireDb();
    final maps = await db.query(
      'docs',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at DESC',
    );
    return maps.map(ProcessedDoc.fromMap).toList();
  }

  Future<void> insertNote(Note note) async {
    final db = _requireDb();
    await db.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<void> insertNotes(List<Note> notes) async {
    final db = _requireDb();
    final batch = db.batch();
    for (final note in notes) {
      batch.insert(
        'notes',
        note.toMap(),
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> setNotesProcessed(
    List<String> ids, {
    required bool processed,
  }) async {
    if (ids.isEmpty) return;
    final db = _requireDb();
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        'notes',
        {
          'is_processed': processed ? 1 : 0,
          'deleted_at': processed
              ? DateTime.now().millisecondsSinceEpoch
              : null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertDoc(ProcessedDoc doc) async {
    final db = _requireDb();
    await db.insert(
      'docs',
      doc.toMap(),
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteDoc(String id) async {
    final db = _requireDb();
    await db.delete('docs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> fetchNotesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final db = _requireDb();
    final placeholders = List.filled(ids.length, '?').join(',');
    final maps = await db.rawQuery(
      'SELECT * FROM notes WHERE id IN ($placeholders)',
      ids,
    );
    return maps.map(Note.fromMap).toList();
  }

  Future<void> updateNote(Note note) async {
    final db = _requireDb();
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> softDeleteNote(String id) async {
    final db = _requireDb();
    await db.update(
      'notes',
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restoreNote(String id) async {
    final db = _requireDb();
    await db.update(
      'notes',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<UserSettings> loadSettings() async {
    final db = _requireDb();
    final rows = await db.query('settings');
    if (rows.isEmpty) {
      const defaults = UserSettings();
      await saveSettings(defaults);
      return defaults;
    }
    final map = <String, String>{};
    for (final row in rows) {
      final key = row['key'] as String?;
      final value = row['value'] as String?;
      if (key != null && value != null) {
        map[key] = value;
      }
    }
    return UserSettings.fromStorage(map);
  }

  Future<void> saveSettings(UserSettings settings) async {
    final db = _requireDb();
    final batch = db.batch();
    final map = settings.toStorage();
    map.forEach((key, value) {
      batch.insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
    });
    await batch.commit(noResult: true);
  }

  sqflite.Database _requireDb() {
    final db = _db;
    if (db == null) {
      throw StateError('Database has not been initialized.');
    }
    return db;
  }

  Future<void> _ensureSchema(sqflite.Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
