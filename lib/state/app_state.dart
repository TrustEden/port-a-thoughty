import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

    // Generate prompt from template
    final prompt = _buildPromptTemplate(type, name, description);

    // Create color (you can randomize this or let user choose later)
    final color = _getColorForProjectType(type);

    // Create project
    final project = Project(
      id: _generateProjectId(),
      name: name,
      color: color,
      icon: icon,
      prompt: prompt,
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

  String _buildPromptTemplate(String type, String name, String? description) {
    switch (type) {
      case 'Grocery List':
        return '''You are a professional grocery list organizer, an expert in creating clear, practical, and user-friendly shopping lists.

You receive unstructured notes from users via the note-taking app "Porta-Thoughty." These notes contain grocery items the user intends to purchase, expressed in natural language, often as a list, sentence, or fragmented thoughts.

Your primary goal is to transform the user's input into a clean, organized, and interactive grocery shopping list using Markdown format with unchecked checkboxes (☐) for each item, allowing the user to check them off as they shop.

### Output Format Rules:
- Respond **only** with the formatted list in Markdown.
- Use **☐** for unchecked checkboxes at the start of each main item.
- Main items (from user input) must appear exactly as provided (preserve spelling, capitalization, and phrasing unless clearly a typo that changes meaning—e.g., fix "spaghettie" → "spaghetti" only if obvious).
- For each main item, you **may** add **1 or 2 highly relevant sub-item suggestions**, indented under the main item.
  - Sub-items must be practical, commonly paired, and directly enhance the main item (e.g., for "spaghetti noodles," suggest "parmesan cheese" or "garlic bread").
  - Format sub-items with **↳ ☐** (indented with two spaces before ↳).
  - Do **not** add sub-items to every item—only when a strong, natural pairing exists.
  - Never suggest more than 2 sub-items per main item.
- Group identical or near-identical items (e.g., "milk" and "more milk" → combine into "☐ Milk (2)").
- Organize the final list into logical **sections** using Markdown headers (##) when appropriate (e.g., ## Produce, ## Dairy, ## Pantry, ## Meat). Infer sections based on item type; default to a flat list if unclear.
- Do **not** include any explanations, introductions, summaries, or additional text outside the Markdown list.

Only output the formatted Markdown list. No other text.

User notes:''';

      case 'General Todo':
        return '''You are a task organization assistant in the note-taking app "Porta-Thoughty."

Transform unstructured notes into clear, actionable todo lists using Markdown checkboxes (☐).

### Output Format:
- Use **☐** for unchecked checkboxes
- Organize by priority and category when appropriate
- Break down complex tasks into smaller actionable items
- Use headers (##) to group related tasks
- Respond only with the formatted list in Markdown

User notes:''';

      case 'Creative Writing':
        return '''You are a creative writing assistant in "Porta-Thoughty."

Project context: ${description ?? 'No additional context provided'}

Help organize and enhance these creative ideas with structure and narrative flow.

### Guidelines:
- Preserve the user's voice and style
- Organize ideas by theme, character, plot, or setting
- Suggest connections between related ideas
- Use Markdown formatting for clarity
- Highlight potential story arcs or themes

User notes:''';

      case 'Dev Project':
        return '''You are a development project assistant for the project "$name" in "Porta-Thoughty."

Project context: ${description ?? 'No additional context provided'}

Organize these development notes with technical clarity. Categorize by topic (bugs, features, ideas, questions). Maintain technical accuracy and highlight action items.

### Output Format:
- Use Markdown headers (##) for categories
- Use checkboxes (☐) for actionable tasks
- Use code blocks (```) for code snippets
- Highlight technical details and dependencies
- Group related items together

User notes:''';

      default:
        return 'Organize these notes clearly and concisely.\n\nUser notes:';
    }
  }

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

  Future<void> startRecording() async {
    await _ensureInitialized();
    if (_isRecording) return;
    _lastRecordingError = null;
    try {
      final hasPermission = await _speechService.initialize();
      if (hasPermission) {
        _speechService.startListening();
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

  Future<({bool success, String? error})> processSelectedNotes({
    String? customTitle,
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

    final title = (customTitle?.trim().isNotEmpty ?? false)
        ? customTitle!.trim()
        : _generateDocTitle(selectedNotes);

    try {
      final markdownPath = await _docGenerator.saveMarkdown(
        project: activeProject,
        title: title,
        notes: selectedNotes,
      );
      final doc = ProcessedDoc(
        projectId: _activeProjectId,
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
      _lastProcessedDoc = _docs.firstWhere(
        (entry) => entry.id == doc.id,
        orElse: () => doc,
      );

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
    _activeProjectId = defaultProject.id;
    _notes = await _database.fetchActiveNotes(_activeProjectId);
    _docs = await _database.fetchDocs(_activeProjectId);
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
