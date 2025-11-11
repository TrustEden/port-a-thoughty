import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Service for processing various file types using Groq API
class GroqFileProcessor {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  static const String _visionModel =
      'llama-3.2-90b-vision-preview'; // Groq's vision model

  final String? _apiKey;

  GroqFileProcessor({String? apiKey}) : _apiKey = apiKey;

  /// Processes an uploaded file and returns extracted content as markdown
  /// Supports images (jpg, png, etc.) and will attempt to extract text/content
  Future<String> processFile(String filePath) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception(
        'Groq API key not configured. Please add your API key in Settings.',
      );
    }

    final extension = p.extension(filePath).toLowerCase();

    // Handle image files with vision model
    if (_isImageFile(extension)) {
      return await _processImageWithVision(filePath);
    }

    // For text-based files, read directly
    if (_isTextFile(extension)) {
      return await _processTextFile(filePath);
    }

    // For other file types, return a note about the file
    return 'Uploaded file: ${p.basename(filePath)}\n\nFile type: $extension\n\nNote: This file type requires manual processing.';
  }

  bool _isImageFile(String extension) {
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp']
        .contains(extension);
  }

  bool _isTextFile(String extension) {
    return ['.txt', '.md', '.markdown'].contains(extension);
  }

  Future<String> _processTextFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      return content;
    } catch (e) {
      return 'Error reading file: $e';
    }
  }

  Future<String> _processImageWithVision(String filePath) async {
    try {
      // Read image file and convert to base64
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final extension = p.extension(filePath).toLowerCase().replaceAll('.', '');

      // Determine MIME type
      String mimeType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/jpeg';
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _visionModel,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text':
                      'Extract all text and information from this image. If there is text, transcribe it exactly. If there are diagrams, charts, or visual elements, describe them in detail. Format your response in clean Markdown.',
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mimeType;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'temperature': 0.3,
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

      return content;
    } catch (e) {
      return 'Error processing image with Groq: $e\n\nPlease try again or process manually.';
    }
  }
}
