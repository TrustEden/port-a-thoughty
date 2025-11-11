import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/note.dart';
import '../models/project.dart';
import 'prompt_templates.dart';

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
    // Use the PromptTemplates service to build the prompt from the project type and description
    // This assembles: template + project context (description) at runtime
    final projectType = project.projectType ?? 'Inbox';
    return PromptTemplates.buildPrompt(
      projectType: projectType,
      projectName: project.name,
      description: project.description,
    );
  }

  String _buildUserPrompt(List<Note> notes, String documentTitle) {
    final buffer = StringBuffer();
    buffer.writeln('Document Title: $documentTitle\n');
    buffer.writeln('Please organize and summarize the following notes:\n');

    for (var i = 0; i < notes.length; i++) {
      buffer.writeln('Note ${i + 1} (${_noteTypeLabel(notes[i].type)}):');
      buffer.writeln(notes[i].text); // Send full text, not truncated preview
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
