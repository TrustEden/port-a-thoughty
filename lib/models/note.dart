import 'package:uuid/uuid.dart';

/// Enum describing the note capture modality.
enum NoteType { voice, text, image }

/// Simple UUID generator shared across models.
const _uuid = Uuid();

/// Domain model for a captured note in the local queue.
class Note {
  Note({
    String? id,
    required this.projectId,
    required this.type,
    required this.text,
    required this.createdAt,
    this.includeImage = false,
    this.imageLabel,
    this.imagePath,
    this.isProcessed = false,
    this.flaggedLowConfidence = false,
    this.deletedAt,
  }) : id = id ?? _uuid.v4();

  final String id;
  final String projectId;
  final NoteType type;
  final String text;
  final DateTime createdAt;
  final bool includeImage;
  final String? imageLabel;
  final String? imagePath;
  final bool isProcessed;
  final bool flaggedLowConfidence;
  final DateTime? deletedAt;

  String get preview {
    if (text.trim().isEmpty) {
      return type == NoteType.image
          ? 'OCR pending'
          : type == NoteType.voice
          ? 'Voice note'
          : 'Empty note';
    }
    final trimmed = text.trim();
    return trimmed.length <= 120 ? trimmed : '${trimmed.substring(0, 117)}...';
  }

  Note copyWith({
    String? id,
    String? projectId,
    NoteType? type,
    String? text,
    DateTime? createdAt,
    bool? includeImage,
    String? imageLabel,
    String? imagePath,
    bool? isProcessed,
    bool? flaggedLowConfidence,
    DateTime? deletedAt,
  }) {
    return Note(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      type: type ?? this.type,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      includeImage: includeImage ?? this.includeImage,
      imageLabel: imageLabel ?? this.imageLabel,
      imagePath: imagePath ?? this.imagePath,
      isProcessed: isProcessed ?? this.isProcessed,
      flaggedLowConfidence: flaggedLowConfidence ?? this.flaggedLowConfidence,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  factory Note.fromMap(Map<String, Object?> map) {
    final typeString = map['type'] as String? ?? NoteType.text.name;
    return Note(
      id: map['id'] as String?,
      projectId: map['project_id'] as String,
      type: NoteType.values.firstWhere(
        (value) => value.name == typeString,
        orElse: () => NoteType.text,
      ),
      text: map['text'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      includeImage: (map['include_image'] as int? ?? 0) == 1,
      imageLabel: map['image_label'] as String?,
      imagePath: map['image_path'] as String?,
      isProcessed: (map['is_processed'] as int? ?? 0) == 1,
      flaggedLowConfidence: (map['flagged_low_confidence'] as int? ?? 0) == 1,
      deletedAt: _dateFromMillis(map['deleted_at'] as int?),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'type': type.name,
      'text': text,
      'created_at': createdAt.millisecondsSinceEpoch,
      'include_image': includeImage ? 1 : 0,
      'image_label': imageLabel,
      'image_path': imagePath,
      'is_processed': isProcessed ? 1 : 0,
      'flagged_low_confidence': flaggedLowConfidence ? 1 : 0,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
    };
  }

  static DateTime? _dateFromMillis(int? millis) {
    if (millis == null || millis == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
