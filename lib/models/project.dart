import 'package:flutter/material.dart';

/// Representation of a user project/collection that groups captured notes.
class Project {
  // Map of commonly used Material icon code points to const IconData instances
  // This helps with tree-shaking by using const instances instead of dynamic creation
  static final Map<int, IconData> _materialIconsCache = {
    0xe88a: Icons.inbox,
    0xe3c9: Icons.folder,
    0xe86c: Icons.work,
    0xe7f4: Icons.home,
    0xe8d2: Icons.star,
    0xe7fe: Icons.favorite,
    0xe0b7: Icons.book,
    0xe8f4: Icons.school,
    0xe8f9: Icons.settings,
    0xe7ee: Icons.help,
    0xe3a8: Icons.lightbulb,
    0xe8e8: Icons.code,
    0xe3a7: Icons.build,
    0xe3a9: Icons.shopping_cart,
    0xe558: Icons.attach_money,
    0xe7fd: Icons.person,
    0xe7ef: Icons.group,
    0xe0bf: Icons.business,
    0xe87c: Icons.category,
    0xe2c7: Icons.label,
  };

  // Helper to create IconData in a way that's compatible with tree-shaking
  static IconData? _createIconData(int? codePoint, String? fontFamily) {
    if (codePoint == null) return null;

    // If using MaterialIcons font family (or null/default), try to use cached const instances
    if (fontFamily == null || fontFamily == 'MaterialIcons') {
      // Check if we have a const instance for this code point
      if (_materialIconsCache.containsKey(codePoint)) {
        return _materialIconsCache[codePoint]!;
      }
    }

    // Fallback: create IconData with explicit fontFamily
    // This is still dynamic but better than implicit null fontFamily
    return IconData(codePoint, fontFamily: fontFamily ?? 'MaterialIcons');
  }
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
      icon: _createIconData(iconCodePoint, iconFontFamily),
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
