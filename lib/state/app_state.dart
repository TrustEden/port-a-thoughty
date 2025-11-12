import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/note.dart';
import '../models/processed_doc.dart';
import '../models/project.dart';
import '../models/user_settings.dart';
import '../services/doc_generator.dart';
import '../services/local_database.dart';
import '../services/native_speech_to_text.dart';

class PortaThoughtyState extends ChangeNotifier {
  static const platform = MethodChannel('com.example.porta_thoughty/widget');

  PortaThoughtyState() {
    _speechService = NativeSpeechToTextService(
      onResult: _handleSpeechResult,
      onListeningChanged: (isListening) {
        _isRecording = isListening;
        notifyListeners();
        _sendWidgetUpdate(isListening);
      },
    );
    _docGenerator = DocGenerator();
    _initialization = _bootstrap();
  }

  Future<void> _sendWidgetUpdate(bool isRecording) async {
    try {
      await platform.invokeMethod('updateWidget', {'isRecording': isRecording});
    } on PlatformException catch (e) {
      print("Failed to update widget: '${e.message}'.");
    }
  }

  final LocalDatabase _database = LocalDatabase();
  Future<void>? _initialization;
  bool _ready = false;

  List<Project> _projects = [];
  String _activeProjectId = '';
  List<Note> _notes = [];
  List<ProcessedDoc> _docs = [];
  final Set<String> _selectedNoteIds = <String>{};
  UserSettings _settings = const UserSettings();
  late final NativeSpeechToTextService _speechService;
  late final DocGenerator _docGenerator;
  bool _isRecording = false;
  String? _lastRecordingError;
  String? _pendingRecordingMessage;
  Note? _lastDeletedNote;
  ProcessedDoc? _lastProcessedDoc;

  List<Project> get projects => List.unmodifiable(_projects);

  Project get activeProject {
    if (_projects.isEmpty) {
      return const Project(
        id: 'inbox',
        name: 'Inbox',
        color: Color(0xFF4A53FF),
        icon: Icons.inbox_outlined,
      );
    }
    return _projects.firstWhere(
      (project) => project.id == _activeProjectId,
      orElse: () => _projects.first,
    );
  }

  List<Note> get queue {
    final list = List<Note>.from(_notes);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<ProcessedDoc> get docs => List.unmodifiable(_docs);

  ProcessedDoc? get lastProcessedDoc => _lastProcessedDoc;

  Set<String> get selectedNoteIds => Set.unmodifiable(_selectedNoteIds);
  bool get isRecording => _isRecording;
  String? get lastRecordingError => _lastRecordingError;
  bool get isReady => _ready;
  UserSettings get settings => _settings;

  String? consumeRecordingMessage() {
    final message = _pendingRecordingMessage;
    _pendingRecordingMessage = null;
    return message;
  }

  void clearRecordingError() {
    if (_lastRecordingError == null) return;
    _lastRecordingError = null;
    notifyListeners();
  }

  Future<void> switchProject(String projectId) async {
    if (projectId == _activeProjectId) return;
    await _ensureInitialized();
    final notes = await _database.fetchActiveNotes(projectId);
    final docs = await _database.fetchDocs(projectId);
    _activeProjectId = projectId;
    _selectedNoteIds.clear();
    _notes = notes;
    _docs = docs;
    _lastDeletedNote = null;
    notifyListeners();
  }

  Future<String?> createProject({
    required String name,
    required String type,
    String? description,
    required IconData icon,
  }) async {
    await _ensureInitialized();

    // Create color based on project type
    final color = _getColorForProjectType(type);

    // Create project with description and projectType (no prompt!)
    // The system prompt is generated at runtime from templates
    final project = Project(
      id: _generateProjectId(),
      name: name,
      color: color,
      icon: icon,
      description: description,
      projectType: type,
      prompt: null, // No longer storing prompts in database
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await _database.insertProject(project);
      _projects = await _database.fetchProjects();

      // Switch to the newly created project
      await switchProject(project.id);

      return project.id;
    } catch (error) {
      print('Failed to create project: $error');
      return null;
    }
  }

  // NOTE: Prompt templates are now in lib/services/prompt_templates.dart
  // They are no longer stored in the database, but assembled at runtime

  Color _getColorForProjectType(String type) {
    switch (type) {
      case 'Grocery List':
        return const Color(0xFF4CAF50); // Green
      case 'Dev Project':
        return const Color(0xFF2196F3); // Blue
      case 'Creative Writing':
        return const Color(0xFF9C27B0); // Purple
      case 'General Todo':
        return const Color(0xFFFF9800); // Orange
      default:
        return const Color(0xFF4A53FF); // Default blue
    }
  }

  String _generateProjectId() {
    // Simple UUID-like ID generator
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.toString().substring(7);
    return 'proj_$random';
  }

  void toggleNoteSelection(String noteId) {
    if (_selectedNoteIds.contains(noteId)) {
      _selectedNoteIds.remove(noteId);
    } else {
      _selectedNoteIds.add(noteId);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedNoteIds.isEmpty) return;
    _selectedNoteIds.clear();
    notifyListeners();
  }

  void selectAllNotes() {
    final allNoteIds = _notes.map((note) => note.id).toSet();
    if (allNoteIds.isEmpty) return;
    _selectedNoteIds.clear();
    _selectedNoteIds.addAll(allNoteIds);
    notifyListeners();
  }

  Future<void> startRecording() async {
    await _ensureInitialized();
    if (_isRecording) return;
    _lastRecordingError = null;
    try {
      final hasPermission = await _speechService.initialize();
      if (hasPermission) {
        // For press-and-hold mode, use extended timeouts optimized for continuous speech
        // Note: Android may override pauseFor with its own system timeout
        // For tap mode, use the configured settings
        final listenFor = _settings.pressAndHoldToRecord
            ? const Duration(minutes: 10) // Extended but platform-acceptable duration
            : _settings.maxRecordingDuration;
        final pauseFor = _settings.pressAndHoldToRecord
            ? const Duration(seconds: 60) // Longer pauses OK in press-hold mode
            : _settings.silenceTimeout;

        _speechService.startListening(
          listenFor: listenFor,
          pauseFor: pauseFor,
          listenMode: _settings.pressAndHoldToRecord
              ? ListenMode.dictation // Better for continuous long-form speech
              : ListenMode.confirmation, // Better for quick notes
        );
      } else {
        _lastRecordingError = 'Speech recognition permission not granted.';
        notifyListeners();
      }
    } catch (error) {
      _lastRecordingError = 'Failed to start speech recognition: $error';
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _speechService.stopListening();
  }

  Future<void> addTextNote(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _ensureInitialized();

    final note = Note(
      projectId: _activeProjectId,
      type: NoteType.text,
      text: trimmed,
      createdAt: DateTime.now(),
    );

    await _database.insertNote(note);
    _notes = [note, ..._notes];
    notifyListeners();
  }

  Future<void> addImageNote({
    required String ocrText,
    bool includeImage = true,
    String? imagePath,
    String? label,
  }) async {
    await _ensureInitialized();

    // Copy image to permanent storage if needed
    String? permanentImagePath;
    if (imagePath != null && includeImage) {
      try {
        final supportDir = await getApplicationSupportDirectory();
        final imagesDir = Directory(
          p.join(supportDir.path, 'projects', _activeProjectId, 'images'),
        );
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = p.extension(imagePath);
        final fileName = '$timestamp$extension';
        final destinationPath = p.join(imagesDir.path, fileName);

        // Copy the image file
        final sourceFile = File(imagePath);
        await sourceFile.copy(destinationPath);
        permanentImagePath = destinationPath;

        // Delete the temp file if it's different from destination
        if (imagePath != destinationPath) {
          try {
            await sourceFile.delete();
          } catch (_) {
            // Ignore deletion errors for temp files
          }
        }
      } catch (e) {
        print('Failed to copy image: $e');
        // Continue without image if copy fails
        permanentImagePath = null;
      }
    }

    final note = Note(
      projectId: _activeProjectId,
      type: NoteType.image,
      text: ocrText,
      createdAt: DateTime.now(),
      includeImage: includeImage && permanentImagePath != null,
      imageLabel: label,
      imagePath: permanentImagePath,
    );

    await _database.insertNote(note);
    _notes = [note, ..._notes];
    notifyListeners();
  }

  Future<void> updateNote(Note note) async {
    await _ensureInitialized();
    await _database.updateNote(note);
    final index = _notes.indexWhere((element) => element.id == note.id);
    if (index != -1) {
      _notes[index] = note;
      notifyListeners();
    }
  }

  Future<bool> deleteNote(Note note) async {
    await _ensureInitialized();
    final exists = _notes.any((element) => element.id == note.id);
    if (!exists) return false;

    await _database.softDeleteNote(note.id);
    _notes = _notes.where((element) => element.id != note.id).toList();
    _selectedNoteIds.remove(note.id);
    _lastDeletedNote = note;
    notifyListeners();
    return true;
  }

  Future<void> undoNoteDeletion() async {
    final note = _lastDeletedNote;
    if (note == null) return;
    await _ensureInitialized();
    await _database.restoreNote(note.id);
    _notes = await _database.fetchActiveNotes(_activeProjectId);
    _lastDeletedNote = null;
    notifyListeners();
  }

  Future<bool> moveNoteToProject(String noteId, String newProjectId) async {
    await _ensureInitialized();
    final note = _notes.firstWhere(
      (element) => element.id == noteId,
      orElse: () => throw Exception('Note not found'),
    );

    final updatedNote = note.copyWith(projectId: newProjectId);
    await _database.updateNote(updatedNote);

    // If moving within same project, just update in memory
    if (newProjectId == _activeProjectId) {
      final index = _notes.indexWhere((element) => element.id == noteId);
      if (index != -1) {
        _notes[index] = updatedNote;
        notifyListeners();
      }
    } else {
      // Moving to different project, remove from current view
      _notes = _notes.where((element) => element.id != noteId).toList();
      _selectedNoteIds.remove(noteId);
      notifyListeners();
    }

    return true;
  }

  Future<bool> moveNotesToProject(List<String> noteIds, String newProjectId) async {
    await _ensureInitialized();

    for (final noteId in noteIds) {
      final note = _notes.firstWhere(
        (element) => element.id == noteId,
        orElse: () => throw Exception('Note not found'),
      );

      final updatedNote = note.copyWith(projectId: newProjectId);
      await _database.updateNote(updatedNote);
    }

    // If moving to different project, remove from current view
    if (newProjectId != _activeProjectId) {
      _notes = _notes.where((element) => !noteIds.contains(element.id)).toList();
      for (final noteId in noteIds) {
        _selectedNoteIds.remove(noteId);
      }
    }

    notifyListeners();
    return true;
  }

  Future<({bool success, String? error})> processSelectedNotes({
    String? customTitle,
    String? targetProjectId,
  }) async {
    await _ensureInitialized();
    if (_selectedNoteIds.isEmpty) {
      return (success: false, error: 'Select at least one note to process.');
    }

    final selectedNotes = queue
        .where((note) => _selectedNoteIds.contains(note.id))
        .toList(growable: false);
    if (selectedNotes.isEmpty) {
      return (success: false, error: 'Selected notes are no longer available.');
    }

    // Use target project if specified, otherwise use active project
    final projectId = targetProjectId ?? _activeProjectId;
    final project = _projects.firstWhere(
      (p) => p.id == projectId,
      orElse: () => activeProject,
    );

    final title = (customTitle?.trim().isNotEmpty ?? false)
        ? customTitle!.trim()
        : _generateDocTitle(selectedNotes);

    try {
      // Move notes to target project if different from current
      if (projectId != _activeProjectId) {
        for (final note in selectedNotes) {
          final updatedNote = note.copyWith(projectId: projectId);
          await _database.updateNote(updatedNote);
        }
      }

      final markdownPath = await _docGenerator.saveMarkdown(
        project: project,
        title: title,
        notes: selectedNotes,
        groqApiKey: _settings.groqApiKey,
      );
      final doc = ProcessedDoc(
        projectId: projectId,
        title: title,
        createdAt: DateTime.now(),
        summary: selectedNotes.map(_summarizeNote).toList(growable: false),
        sourceNoteIds: selectedNotes.map((note) => note.id).toList(),
        markdownPath: markdownPath,
      );

      await _database.insertDoc(doc);
      await _database.setNotesProcessed(doc.sourceNoteIds, processed: true);

      _notes = await _database.fetchActiveNotes(_activeProjectId);
      _docs = await _database.fetchDocs(_activeProjectId);
      _selectedNoteIds.clear();

      // Only set lastProcessedDoc if processed to current project
      if (projectId == _activeProjectId) {
        _lastProcessedDoc = _docs.firstWhere(
          (entry) => entry.id == doc.id,
          orElse: () => doc,
        );
      } else {
        _lastProcessedDoc = null;
      }

      // Wait for microtask queue to clear before notifying
      await Future.microtask(() {});
      notifyListeners();

      return (success: true, error: null);
    } catch (error) {
      return (success: false, error: 'Document creation failed: $error');
    }
  }

  Future<void> undoLastProcess() async {
    final doc = _lastProcessedDoc;
    if (doc == null) return;
    await _ensureInitialized();

    await _database.deleteDoc(doc.id);
    await _database.setNotesProcessed(doc.sourceNoteIds, processed: false);
    final path = doc.markdownPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Ignore cleanup errors.
        }
      }
    }

    _notes = await _database.fetchActiveNotes(_activeProjectId);
    _docs = await _database.fetchDocs(_activeProjectId);
    _lastProcessedDoc = null;

    // Wait for microtask queue to clear before notifying
    await Future.microtask(() {});
    notifyListeners();
  }

  Future<bool> deleteDoc(ProcessedDoc doc) async {
    await _ensureInitialized();
    final exists = _docs.any((element) => element.id == doc.id);
    if (!exists) return false;

    await _database.deleteDoc(doc.id);

    // Delete the markdown file if it exists
    final path = doc.markdownPath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Ignore cleanup errors.
        }
      }
    }

    _docs = await _database.fetchDocs(_activeProjectId);
    notifyListeners();
    return true;
  }

  Future<void> disposeAsync() async {
    _speechService.dispose();
  }

  @override
  void dispose() {
    unawaited(disposeAsync());
    super.dispose();
  }

  String _generateDocTitle(List<Note> notes) {
    final today = DateTime.now();
    final formatted =
        '${_monthShort(today.month)} ${today.day.toString().padLeft(2, '0')}';
    final project = activeProject.name;
    return '$project Notes - $formatted';
  }

  String _monthShort(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[(month - 1).clamp(0, names.length - 1)];
  }

  String _summarizeNote(Note note) {
    switch (note.type) {
      case NoteType.voice:
        return 'Voice - ${note.preview}';
      case NoteType.text:
        return 'Text - ${note.preview}';
      case NoteType.image:
        return 'Image - ${note.preview}';
    }
  }

  void _handleSpeechResult(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _lastRecordingError = 'Speech recognition returned empty output.';
      notifyListeners();
      return;
    }

    final note = Note(
      projectId: _activeProjectId,
      type: NoteType.voice,
      text: trimmed,
      createdAt: DateTime.now(),
    );

    _database.insertNote(note);
    _notes = [note, ..._notes];
    _pendingRecordingMessage = 'Transcribed voice note added to your queue.';
    notifyListeners();
  }

  Future<void> _bootstrap() async {
    await _database.init();
    final defaultProject = await _database.ensureDefaultProject();
    final projects = await _database.fetchProjects();
    final settings = await _database.loadSettings();
    _settings = settings;
    _projects = projects;

    // Only load notes and docs if there's at least one project
    if (defaultProject != null) {
      _activeProjectId = defaultProject.id;
      _notes = await _database.fetchActiveNotes(_activeProjectId);
      _docs = await _database.fetchDocs(_activeProjectId);
    } else {
      _activeProjectId = '';
      _notes = [];
      _docs = [];
    }

    _ready = true;
    notifyListeners();
  }

  Future<void> _ensureInitialized() async {
    await (_initialization ?? Future<void>.value());
  }

  Future<void> updateSilenceTimeout(Duration duration) async {
    await _ensureInitialized();
    if (duration.isNegative) {
      duration = Duration.zero;
    }
    if (_settings.silenceTimeout == duration) return;
    _settings = _settings.copyWith(silenceTimeout: duration);
    await _database.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateApiKeys({
    String? openai,
    String? gemini,
    String? anthropic,
    String? groq,
  }) async {
    await _ensureInitialized();
    _settings = _settings.copyWith(
      openaiApiKey: openai,
      geminiApiKey: gemini,
      anthropicApiKey: anthropic,
      groqApiKey: groq,
    );
    await _database.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updatePressAndHoldToRecord(bool enabled) async {
    await _ensureInitialized();
    if (_settings.pressAndHoldToRecord == enabled) return;
    _settings = _settings.copyWith(pressAndHoldToRecord: enabled);
    await _database.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> markIntroAsSeen() async {
    await _ensureInitialized();
    if (_settings.hasSeenIntro) return;
    _settings = _settings.copyWith(hasSeenIntro: true);
    await _database.saveSettings(_settings);
    notifyListeners();
  }

  /// Refreshes the queue by reloading notes from database
  Future<void> refreshQueue() async {
    await _ensureInitialized();
    _notes = await _database.fetchActiveNotes(_activeProjectId);
    notifyListeners();
  }

  /// Refreshes the docs list by reloading from database
  Future<void> refreshDocs() async {
    await _ensureInitialized();
    _docs = await _database.fetchDocs(_activeProjectId);
    notifyListeners();
  }
}
