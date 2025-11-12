import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service for extracting text from images using Google ML Kit OCR
/// Note: OCR is only supported on Android and iOS platforms
class OcrService {
  OcrService() : _textRecognizer = _isOcrSupported() ? TextRecognizer() : null;

  final TextRecognizer? _textRecognizer;

  /// Check if OCR is supported on the current platform
  static bool _isOcrSupported() {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }

  /// Extracts text from an image file using Google ML Kit
  /// Returns the extracted text or an empty string if no text is found
  /// Returns empty string on unsupported platforms
  Future<String> extractTextFromImage(String imagePath) async {
    if (_textRecognizer == null) {
      print('OCR not supported on this platform');
      return '';
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        return '';
      }

      return recognizedText.text;
    } catch (e) {
      print('OCR error: $e');
      return '';
    }
  }

  /// Extracts text from an image file and returns both text and confidence
  /// Returns a record with text and a boolean indicating if confidence is low
  /// Returns empty text on unsupported platforms
  Future<({String text, bool lowConfidence})> extractTextWithConfidence(
    String imagePath,
  ) async {
    if (_textRecognizer == null) {
      print('OCR not supported on this platform');
      return (text: '', lowConfidence: true);
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        return (text: '', lowConfidence: false);
      }

      // For ML Kit, we'll flag as low confidence if:
      // - Very few blocks detected
      // - Text is very short
      final lowConfidence =
          recognizedText.blocks.length < 2 || recognizedText.text.length < 10;

      return (text: recognizedText.text, lowConfidence: lowConfidence);
    } catch (e) {
      print('OCR error: $e');
      return (text: '', lowConfidence: true);
    }
  }

  /// Dispose of resources when done
  void dispose() {
    _textRecognizer?.close();
  }
}
