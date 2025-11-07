import 'package:flutter/material.dart';

/// Representation of a user project/collection that groups captured notes.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.color,
    this.icon,
    this.prompt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final Color color;
  final IconData? icon;
  final String? prompt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Project copyWith({
    String? id,
    String? name,
    Color? color,
    IconData? icon,
    String? prompt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      prompt: prompt ?? this.prompt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Project.fromMap(Map<String, Object?> map) {
    final colorValue = map['color'] as int? ?? 0xFF4A53FF;
    final iconCodePoint = map['icon_code_point'] as int?;
    final iconFontFamily = map['icon_font_family'] as String?;
    return Project(
      id: map['id'] as String,
      name: map['name'] as String,
      color: Color(colorValue),
      icon: iconCodePoint != null
          ? IconData(iconCodePoint, fontFamily: iconFontFamily)
          : null,
      prompt: map['prompt'] as String?,
      createdAt: _dateFromMillis(map['created_at'] as int?),
      updatedAt: _dateFromMillis(map['updated_at'] as int?),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'color': _encodeColor(color),
      'icon_code_point': icon?.codePoint,
      'icon_font_family': icon?.fontFamily,
      'prompt': prompt,
      'created_at':
          createdAt?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      'updated_at':
          updatedAt?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
    };
  }

  static DateTime? _dateFromMillis(int? millis) {
    if (millis == null || millis == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}

int _encodeColor(Color color) {
  int component(double value) => (value.clamp(0.0, 1.0) * 255).round() & 0xff;
  final a = component(color.a);
  final r = component(color.r);
  final g = component(color.g);
  final b = component(color.b);
  return (a << 24) | (r << 16) | (g << 8) | b;
}
