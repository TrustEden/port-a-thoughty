import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Simple summary of a processed Markdown document generated from a batch.
class ProcessedDoc {
  ProcessedDoc({
    String? id,
    required this.projectId,
    required this.title,
    required this.createdAt,
    required this.summary,
    required this.sourceNoteIds,
    this.markdownPath,
    this.promptHash,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String projectId;
  final String title;
  final DateTime createdAt;
  final List<String> sourceNoteIds;
  final List<String> summary;
  final String? markdownPath;
  final String? promptHash;

  ProcessedDoc copyWith({
    String? id,
    String? projectId,
    String? title,
    DateTime? createdAt,
    List<String>? summary,
    List<String>? sourceNoteIds,
    String? markdownPath,
    String? promptHash,
  }) {
    return ProcessedDoc(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      summary: summary ?? this.summary,
      sourceNoteIds: sourceNoteIds ?? this.sourceNoteIds,
      markdownPath: markdownPath ?? this.markdownPath,
      promptHash: promptHash ?? this.promptHash,
    );
  }

  factory ProcessedDoc.fromMap(Map<String, Object?> map) {
    return ProcessedDoc(
      id: map['id'] as String?,
      projectId: map['project_id'] as String,
      title: map['title'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      summary: _decodeList(map['summary'] as String?),
      sourceNoteIds: _decodeList(map['source_note_ids'] as String?),
      markdownPath: map['markdown_path'] as String?,
      promptHash: map['prompt_hash'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
      'summary': jsonEncode(summary),
      'source_note_ids': jsonEncode(sourceNoteIds),
      'markdown_path': markdownPath,
      'prompt_hash': promptHash,
    };
  }

  static List<String> _decodeList(String? json) {
    if (json == null || json.isEmpty) return const [];
    final parsed = jsonDecode(json);
    if (parsed is List) {
      return parsed.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
