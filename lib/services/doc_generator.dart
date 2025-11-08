import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/note.dart';
import '../models/project.dart';
import 'groq_service.dart';

/// Persists processed notes into Markdown documents under the project tree.
class DocGenerator {
  DocGenerator() : _groqService = GroqService();

  final GroqService _groqService;

  /// Saves a Markdown document for the given [notes] and returns the file path.
  Future<String> saveMarkdown({
    required Project project,
    required String title,
    required List<Note> notes,
  }) async {
    if (notes.isEmpty) {
      throw ArgumentError.value(notes, 'notes', 'At least one note required.');
    }

    final markdown = await _composeMarkdown(
      project: project,
      title: title,
      notes: notes,
    );
    final supportDir = await getApplicationSupportDirectory();
    final docsDir = Directory(
      p.join(supportDir.path, 'projects', project.id, 'docs'),
    );
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}-${_slugify(title)}.md';
    final file = File(p.join(docsDir.path, fileName));
    await file.writeAsString(markdown);
    return file.path;
  }

  Future<String> _composeMarkdown({
    required Project project,
    required String title,
    required List<Note> notes,
  }) async {
    final now = DateTime.now();
    final buffer = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln(
        '_Generated ${_formatDateTime(now)} for project **${project.name}**._',
      )
      ..writeln()
      ..writeln('---')
      ..writeln();

    try {
      // Call Groq AI to process the notes
      final result = await _groqService.processNotes(
        project: project,
        notes: notes,
        documentTitle: title,
      );

      // Add AI-generated summary
      buffer.writeln(result.content);
      buffer.writeln();
    } catch (e) {
      // Fallback to basic formatting if Groq fails
      buffer.writeln('## Highlights');
      buffer.writeln();
      buffer.writeln('_Note: AI processing unavailable. Showing raw notes._');
      buffer.writeln();
      buffer.writeln('Error: $e');
      buffer.writeln();

      for (final note in notes) {
        _appendNote(buffer, note);
        buffer.writeln();
      }
    }

    // Add raw notes section for reference
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('## Raw Notes (Original Captures)');
    buffer.writeln();

    for (final note in notes) {
      _appendNote(buffer, note);
      buffer.writeln();
    }

    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln(
      '_Porta-Thoughty draft — keep iterating or share this Markdown wherever you work._',
    );
    return buffer.toString();
  }

  void _appendNote(StringBuffer buffer, Note note) {
    final label = switch (note.type) {
      NoteType.voice => 'Voice',
      NoteType.text => 'Text',
      NoteType.image => 'Image',
    };

    // For image notes with embedded images, show the image first
    if (note.type == NoteType.image && note.includeImage && note.imagePath != null) {
      final imageFile = File(note.imagePath!);
      if (imageFile.existsSync()) {
        // Use absolute path for the image
        buffer.writeln('- [$label]');
        buffer.writeln();
        buffer.writeln('  ![${note.imageLabel ?? 'Captured image'}](${note.imagePath})');
        buffer.writeln();
      }
    }

    final lines = _normalizeLines(note.text);
    if (lines.isEmpty) {
      if (note.type != NoteType.image || !note.includeImage) {
        buffer.writeln('- [$label] (No transcription captured)');
      }
    } else {
      if (note.type == NoteType.image && note.includeImage && note.imagePath != null) {
        // Text after image
        buffer.writeln('  **Extracted Text:**');
        buffer.writeln();
        for (final line in lines) {
          buffer.writeln('  $line');
        }
      } else {
        // Normal text display
        buffer.writeln('- [$label] ${lines.first}');
        for (final line in lines.skip(1)) {
          buffer.writeln('  $line');
        }
      }
    }

    final metadata = <String>[];
    metadata.add('Captured at ${_formatTime(note.createdAt)}');

    switch (note.type) {
      case NoteType.voice:
        if (note.flaggedLowConfidence) {
          metadata.add('Flagged for re-check: low confidence transcript');
        }
        break;
      case NoteType.image:
        if (note.includeImage) {
          metadata.add(
            'Image included${note.imageLabel != null ? ' (${note.imageLabel})' : ''}',
          );
        } else {
          metadata.add('Image discarded after OCR');
        }
        break;
      case NoteType.text:
        // No extra metadata for plain text captures (yet).
        break;
    }

    if (metadata.isNotEmpty) {
      for (final meta in metadata) {
        buffer.writeln('  - $meta');
      }
    }
  }

  List<String> _normalizeLines(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    if (minutes == 0) {
      return '${seconds}s';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String _formatDateTime(DateTime dateTime) {
    final date =
        '${_monthName(dateTime.month)} ${dateTime.day}, ${dateTime.year}';
    final time = _formatTime(dateTime);
    return '$date at $time';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[(month - 1).clamp(0, names.length - 1)];
  }

  String _slugify(String input) {
    final sanitized = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .trim();
    return sanitized.isEmpty ? 'notes' : sanitized;
  }
}
