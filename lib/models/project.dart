import 'package:flutter/material.dart';

/// Representation of a user project/collection that groups captured notes.
class Project {
  // Map of Material icon code points to const IconData instances
  // IMPORTANT: Only const IconData instances are used to support tree-shaking
  // Any icons not in this map will fall back to Icons.folder
  static final Map<int, IconData> _materialIconsCache = {
    // Common project icons
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
    // Additional common icons
    0xe3a3: Icons.event,
    0xe3c7: Icons.schedule,
    0xe3ab: Icons.description,
    0xe3af: Icons.note,
    0xe3c6: Icons.assignment,
    0xe3d0: Icons.create,
    0xe3d3: Icons.edit,
    0xe3d4: Icons.save,
    0xe3b8: Icons.cloud,
    0xe3a2: Icons.cloud_upload,
    0xe3a4: Icons.cloud_download,
    0xe3e4: Icons.attach_file,
    0xe3e5: Icons.attachment,
    0xe3e8: Icons.insert_drive_file,
    0xe3e9: Icons.folder_open,
    0xe3eb: Icons.image,
    0xe3ee: Icons.photo,
    0xe3f0: Icons.camera,
    0xe3f1: Icons.camera_alt,
    0xe3f4: Icons.video_camera_back,
    0xe3f5: Icons.videocam,
    0xe402: Icons.music_note,
    0xe40e: Icons.mic,
    0xe412: Icons.volume_up,
    0xe8b8: Icons.notifications,
    0xe7f5: Icons.alarm,
    0xe855: Icons.today,
    0xe8df: Icons.calendar_today,
    0xe916: Icons.add,
    0xe15b: Icons.remove,
    0xe14c: Icons.close,
    0xe5cd: Icons.check,
    0xe5c5: Icons.done,
    0xe5ca: Icons.check_circle,
    0xe000: Icons.error,
    0xe001: Icons.warning,
    0xe88e: Icons.info,
  };

  // Helper to get IconData in a way that's compatible with tree-shaking
  // Only returns const IconData instances from the cache or a default
  static IconData? _createIconData(int? codePoint, String? fontFamily) {
    if (codePoint == null) return null;

    // Only support MaterialIcons font family for tree-shaking compatibility
    if (fontFamily == null || fontFamily == 'MaterialIcons') {
      // Return cached const instance or default to folder icon
      return _materialIconsCache[codePoint] ?? Icons.folder;
    }

    // For non-MaterialIcons fonts, return null (unsupported for tree-shaking)
    return null;
  }
  const Project({
    required this.id,
    required this.name,
    required this.color,
    this.icon,
    this.description,
    this.projectType,
    this.prompt, // Deprecated: kept for migration only
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final Color color;
  final IconData? icon;
  /// User-visible context about this project (e.g., "Weekly grocery shopping")
  final String? description;
  /// Project type determines which prompt template to use (e.g., "Dev Project", "Grocery List")
  final String? projectType;
  /// @deprecated Kept for backwards compatibility during migration. Use description + projectType instead.
  final String? prompt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Project copyWith({
    String? id,
    String? name,
    Color? color,
    IconData? icon,
    String? description,
    String? projectType,
    String? prompt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      projectType: projectType ?? this.projectType,
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
      description: map['description'] as String?,
      projectType: map['project_type'] as String?,
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
      'description': description,
      'project_type': projectType,
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
