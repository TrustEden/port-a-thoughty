import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class NativeSpeechToTextService {
  NativeSpeechToTextService({
    required this.onResult,
    this.onListeningChanged,
    this.onWidgetUpdateNeeded,
  });

  final Function(String) onResult;
  final Function(bool)? onListeningChanged;
  final Function(bool)? onWidgetUpdateNeeded;

  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<bool> initialize() async {
    final hasPermission = await _speechToText.initialize(
      onError: (error) => print('Speech recognition error: $error'),
      onStatus: (status) => _handleStatusChange(status),
    );
    return hasPermission;
  }

  void startListening() {
    if (!_isListening) {
      _speechToText.listen(
        onResult: _handleResult,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 8),
      );
      _setListening(true);
    }
  }

  void stopListening() {
    if (_isListening) {
      _speechToText.stop();
      _setListening(false);
    }
  }

  void cancelListening() {
    if (_isListening) {
      _speechToText.cancel();
      _setListening(false);
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    if (result.finalResult) {
      onResult(result.recognizedWords);
    }
  }

  void _handleStatusChange(String status) {
    if (status == 'done' || status == 'notListening') {
      _setListening(false);
    }
  }

  void _setListening(bool listening) {
    if (_isListening != listening) {
      _isListening = listening;
      onListeningChanged?.call(_isListening);
      onWidgetUpdateNeeded?.call(_isListening);
    }
  }

  void dispose() {
    // No-op, as the plugin handles its own lifecycle.
  }
}
