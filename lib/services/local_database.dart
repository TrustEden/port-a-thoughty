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
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE projects(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color INTEGER NOT NULL,
            icon_code_point INTEGER,
            icon_font_family TEXT,
            description TEXT,
            project_type TEXT,
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

        if (oldVersion < 3) {
          // Add description and project_type columns to projects table
          final result = await db.rawQuery('PRAGMA table_info(projects)');
          final hasDescription = result.any((col) => col['name'] == 'description');
          final hasProjectType = result.any((col) => col['name'] == 'project_type');

          if (!hasDescription) {
            await db.execute(
              'ALTER TABLE projects ADD COLUMN description TEXT',
            );
          }

          if (!hasProjectType) {
            await db.execute(
              'ALTER TABLE projects ADD COLUMN project_type TEXT',
            );
          }

          // Note: Existing projects will have null description and project_type.
          // The prompt field contains the old full prompt for backwards compatibility.
          // The app will handle migrating these on-the-fly when needed.
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
      description: null,
      projectType: 'Inbox',
      prompt: null, // System prompts are now stored in code, not in database
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
