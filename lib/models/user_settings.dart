class UserSettings {
  const UserSettings({
    this.silenceTimeout = const Duration(seconds: 8),
    this.maxRecordingDuration = const Duration(minutes: 2),
  });

  final Duration silenceTimeout;
  final Duration maxRecordingDuration;

  static const String _silenceTimeoutKey = 'silence_timeout_ms';
  static const String _maxRecordingKey = 'max_recording_duration_ms';

  UserSettings copyWith({
    Duration? silenceTimeout,
    Duration? maxRecordingDuration,
  }) {
    return UserSettings(
      silenceTimeout: silenceTimeout ?? this.silenceTimeout,
      maxRecordingDuration: maxRecordingDuration ?? this.maxRecordingDuration,
    );
  }

  Map<String, String> toStorage() {
    return {
      _silenceTimeoutKey: silenceTimeout.inMilliseconds.toString(),
      _maxRecordingKey: maxRecordingDuration.inMilliseconds.toString(),
    };
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
    );
  }
}
