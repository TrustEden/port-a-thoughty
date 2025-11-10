class UserSettings {
  const UserSettings({
    this.silenceTimeout = const Duration(seconds: 8),
    this.maxRecordingDuration = const Duration(minutes: 2),
    this.pressAndHoldToRecord = false,
    this.openaiApiKey,
    this.geminiApiKey,
    this.anthropicApiKey,
    this.groqApiKey,
  });

  final Duration silenceTimeout;
  final Duration maxRecordingDuration;
  final bool pressAndHoldToRecord;
  final String? openaiApiKey;
  final String? geminiApiKey;
  final String? anthropicApiKey;
  final String? groqApiKey;

  static const String _silenceTimeoutKey = 'silence_timeout_ms';
  static const String _maxRecordingKey = 'max_recording_duration_ms';
  static const String _pressAndHoldKey = 'press_and_hold_to_record';
  static const String _openaiApiKeyKey = 'openai_api_key';
  static const String _geminiApiKeyKey = 'gemini_api_key';
  static const String _anthropicApiKeyKey = 'anthropic_api_key';
  static const String _groqApiKeyKey = 'groq_api_key';

  UserSettings copyWith({
    Duration? silenceTimeout,
    Duration? maxRecordingDuration,
    bool? pressAndHoldToRecord,
    String? openaiApiKey,
    String? geminiApiKey,
    String? anthropicApiKey,
    String? groqApiKey,
  }) {
    return UserSettings(
      silenceTimeout: silenceTimeout ?? this.silenceTimeout,
      maxRecordingDuration: maxRecordingDuration ?? this.maxRecordingDuration,
      pressAndHoldToRecord: pressAndHoldToRecord ?? this.pressAndHoldToRecord,
      openaiApiKey: openaiApiKey ?? this.openaiApiKey,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
      groqApiKey: groqApiKey ?? this.groqApiKey,
    );
  }

  Map<String, String> toStorage() {
    final map = {
      _silenceTimeoutKey: silenceTimeout.inMilliseconds.toString(),
      _maxRecordingKey: maxRecordingDuration.inMilliseconds.toString(),
      _pressAndHoldKey: pressAndHoldToRecord ? '1' : '0',
    };

    if (openaiApiKey != null && openaiApiKey!.isNotEmpty) {
      map[_openaiApiKeyKey] = openaiApiKey!;
    }
    if (geminiApiKey != null && geminiApiKey!.isNotEmpty) {
      map[_geminiApiKeyKey] = geminiApiKey!;
    }
    if (anthropicApiKey != null && anthropicApiKey!.isNotEmpty) {
      map[_anthropicApiKeyKey] = anthropicApiKey!;
    }
    if (groqApiKey != null && groqApiKey!.isNotEmpty) {
      map[_groqApiKeyKey] = groqApiKey!;
    }

    return map;
  }

  factory UserSettings.fromStorage(Map<String, String> storage) {
    Duration parseDuration(String? value, Duration fallback) {
      final parsed = int.tryParse(value ?? '');
      if (parsed == null || parsed < 0) {
        return fallback;
      }
      return Duration(milliseconds: parsed);
    }

    return UserSettings(
      silenceTimeout: parseDuration(
        storage[_silenceTimeoutKey],
        const Duration(seconds: 8),
      ),
      maxRecordingDuration: parseDuration(
        storage[_maxRecordingKey],
        const Duration(minutes: 2),
      ),
      pressAndHoldToRecord: storage[_pressAndHoldKey] == '1',
      openaiApiKey: storage[_openaiApiKeyKey],
      geminiApiKey: storage[_geminiApiKeyKey],
      anthropicApiKey: storage[_anthropicApiKeyKey],
      groqApiKey: storage[_groqApiKeyKey],
    );
  }
}
