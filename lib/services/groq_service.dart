import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/note.dart';
import '../models/project.dart';

class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  static const String _model = 'llama-3.3-70b-versatile';

  final String? _apiKey;

  GroqService({String? apiKey}) : _apiKey = apiKey;

  /// Processes notes using Groq AI to generate a summarized document
  Future<({String content, List<String> bulletPoints})> processNotes({
    required Project project,
    required List<Note> notes,
    required String documentTitle,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception(
        'Groq API key not configured. Please add your API key in Settings.',
      );
    }

    final systemPrompt = _buildSystemPrompt(project);
    final userPrompt = _buildUserPrompt(notes, documentTitle);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.7,
          'max_tokens': 2048,
        }),
      );

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(
          'Groq API error (${response.statusCode}): ${errorBody['error']?['message'] ?? 'Unknown error'}',
        );
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'] as String?;

      if (content == null || content.isEmpty) {
        throw Exception('Groq API returned empty response');
      }

      final bulletPoints = _extractBulletPoints(content);

      return (content: content, bulletPoints: bulletPoints);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to process notes with Groq: $e');
    }
  }

  String _buildSystemPrompt(Project project) {
    final basePrompt = '''<role>You are an expert Technical Project Manager and Senior Developer, acting as a "second brain" for a solo developer. Your primary function is to process a raw, dictated "brain dump" of notes and convert them into an actionable, prioritized developer to-do list. The developer is preparing for the v1.0 launch of their app, "Porta-Thoughty," so all notes must be evaluated with that context.</role>

<instructions>
You will be given a list of raw notes. Your job is to process this list and generate a single Markdown file as a response.

Follow these steps meticulously:

Analyze and Refine: Read through the entire list of notes to understand the scope. Then, process each note one by one.

Refine Intent: For each note, identify the core task, bug, or feature request.

Expand Clearly: Rewrite the note as a single, clear, and actionable sentence. This sentence should slightly expand on the original idea to make it a concrete task, but MUST NOT lose the original intent. For example, "share button" becomes "Implement a 'Share' button to send the Markdown note to other apps."

Preserve Original: Keep the original note's text to provide context.

Assign Priority: After refining the task, assign a priority level. Use the context of a "v1.0 launch" to make your decision.

[P1 - Critical]: App-breaking bugs, crashes, security flaws, or core functionality that is broken. The app cannot launch without this.
[P2 - High]: Essential v1.0 features that are missing, major UI/UX flaws, or anything that would make the app feel "incomplete" to a new user.
[P3 - Medium]: Important, but not a deal-breaker. Minor UI polish, small feature enhancements, or ideas for v1.1.
[P4 - Low]: Future ideas, minor refactoring, or trivial tweaks (e.g., "change a color").

Create Summary: After processing all notes, write a 1-2 sentence "Task Batch Summary." This summary should describe the main themes of the work in this specific batch (e.g., "This batch focuses on fixing core workflow bugs and polishing the UI before launch.").

Format Output: Assemble the entire response into a single Markdown file. Adhere to this format EXACTLY:

# Porta-Thoughty: Action Items

## Task Batch Summary
[Your 1-2 sentence summary here.]

## Developer To-Do List

☐ [Priority] Task: [The refined, expanded 1-sentence task.]
(Original: "The raw text of the user's note...")

☐ [Priority] Task: [The next refined, expanded task...]
(Original: "The next raw note...")

☐ [Priority] Task: [The next refined, expanded task...]
(Original: "The next raw note...")
</instructions>

<rules>
You MUST output only the Markdown content.
Do NOT include any conversational introduction, preamble, or sign-off.
The output MUST be a valid Markdown file, starting with the # Porta-Thoughty: Action Items heading.
Ensure every note from the input list is represented as one line item in the to-do list.
</rules>''';

    if (project.prompt != null && project.prompt!.isNotEmpty) {
      return '$basePrompt\n\nAdditional instructions for this project: ${project.prompt}';
    }

    return basePrompt;
  }

  String _buildUserPrompt(List<Note> notes, String documentTitle) {
    final buffer = StringBuffer();
    buffer.writeln('Document Title: $documentTitle\n');
    buffer.writeln('Please organize and summarize the following notes:\n');

    for (var i = 0; i < notes.length; i++) {
      buffer.writeln('Note ${i + 1} (${_noteTypeLabel(notes[i].type)}):');
      buffer.writeln(notes[i].preview);
      buffer.writeln('');
    }

    return buffer.toString();
  }

  String _noteTypeLabel(NoteType type) {
    switch (type) {
      case NoteType.voice:
        return 'Voice';
      case NoteType.text:
        return 'Text';
      case NoteType.image:
        return 'Image/OCR';
    }
  }

  List<String> _extractBulletPoints(String content) {
    final lines = content.split('\n');
    final bulletPoints = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      // Match markdown bullet points (-, *, +) or numbered lists
      if (trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          trimmed.startsWith('+ ') ||
          RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        // Remove the bullet/number prefix
        var text = trimmed.replaceFirst(RegExp(r'^[-*+]\s+'), '');
        text = text.replaceFirst(RegExp(r'^\d+\.\s+'), '');
        if (text.isNotEmpty) {
          bulletPoints.add(text);
        }
      }
    }

    // If no bullet points found, extract first 3 sentences as summary points
    if (bulletPoints.isEmpty) {
      final sentences = content.split(RegExp(r'[.!?]\s+'));
      for (var i = 0; i < sentences.length && i < 3; i++) {
        final sentence = sentences[i].trim();
        if (sentence.isNotEmpty) {
          bulletPoints.add(sentence);
        }
      }
    }

    return bulletPoints;
  }
}
