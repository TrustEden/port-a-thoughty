import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../state/app_state.dart';
import 'bottom_sheets.dart';

class RecentNoteList extends StatelessWidget {
  const RecentNoteList({super.key, required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const _EmptyRecent();
    }
    return Column(
      children: [for (final note in notes) _RecentNoteTile(note: note)],
    );
  }
}

class _RecentNoteTile extends StatelessWidget {
  const _RecentNoteTile({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentColorForType(note.type, theme);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10014F8E),
            blurRadius: 20,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NoteAvatar(note: note, color: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _timestampLabel(note.createdAt),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _labelForType(note.type),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          _NoteOptionsMenu(note: note),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note.preview,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: _metaChips(note, theme, accent),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _metaChips(Note note, ThemeData theme, Color accent) {
    final chips = <Widget>[
      _MetaChip(
        icon: Icons.calendar_today_outlined,
        label: _dateLabel(note.createdAt),
      ),
    ];

    switch (note.type) {
      case NoteType.voice:
        if (note.flaggedLowConfidence) {
          chips.add(
            _MetaChip(
              icon: Icons.warning_amber_rounded,
              label: 'Low confidence - recheck later',
              color: theme.colorScheme.error,
            ),
          );
        }
        break;
      case NoteType.text:
        final wordCount = note.text
            .trim()
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .length;
        chips.add(
          _MetaChip(icon: Icons.short_text_rounded, label: '$wordCount words'),
        );
        break;
      case NoteType.image:
        final imageLabel = note.imageLabel;
        final description = note.includeImage
            ? 'Image kept${imageLabel != null ? ' - $imageLabel' : ''}'
            : 'Text only (image discarded)';
        chips.add(_MetaChip(icon: Icons.image_outlined, label: description));
        break;
    }

    chips.add(
      _MetaChip(
        icon: Icons.auto_awesome_outlined,
        label: 'Ready to process',
        color: accent,
      ),
    );

    return chips;
  }

  Color _accentColorForType(NoteType type, ThemeData theme) {
    switch (type) {
      case NoteType.voice:
        return theme.colorScheme.primary;
      case NoteType.text:
        return const Color(0xFFFB8C00);
      case NoteType.image:
        return const Color(0xFF8E24AA);
    }
  }

  String _timestampLabel(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    if (difference.inDays < 7) return '${difference.inDays} d ago';
    return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }

  String _dateLabel(DateTime createdAt) {
    return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }

  String _labelForType(NoteType type) {
    switch (type) {
      case NoteType.voice:
        return 'Voice';
      case NoteType.text:
        return 'Text';
      case NoteType.image:
        return 'Image + OCR';
    }
  }
}

class _NoteAvatar extends StatelessWidget {
  const _NoteAvatar({required this.note, required this.color});

  final Note note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget icon;
    switch (note.type) {
      case NoteType.voice:
        icon = const Icon(Icons.mic, size: 28, color: Colors.white);
        break;
      case NoteType.text:
        icon = Image.asset(
          'assets/bulb icon.png',
          width: 34,
          height: 34,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
        break;
      case NoteType.image:
        icon = const Icon(Icons.photo, size: 28, color: Colors.white);
        break;
    }

    return Container(
      height: 62,
      width: 62,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(child: icon),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.onSurfaceVariant;
    final background = (color ?? theme.colorScheme.primary).withValues(
      alpha: color != null ? 0.14 : 0.1,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteOptionsMenu extends StatelessWidget {
  const _NoteOptionsMenu({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final state = context.read<PortaThoughtyState>();
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Note options',
      splashRadius: 20,
      onSelected: (value) async {
        if (value == 'delete') {
          final confirmed = await _confirmDelete(context);
          if (confirmed && context.mounted) {
            await state.deleteNote(note);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note deleted')),
              );
            }
          }
        } else if (value == 'move') {
          final newProjectId = await _showProjectPicker(context, state);
          if (newProjectId != null && context.mounted) {
            await state.moveNoteToProject(note.id, newProjectId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note moved to project')),
              );
            }
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'move',
          child: Row(
            children: [
              Icon(Icons.drive_file_move_outlined),
              SizedBox(width: 12),
              Text('Move to project'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Image.asset(
                'assets/trashicon.png',
                width: 24,
                height: 24,
                gaplessPlayback: true,
              ),
              const SizedBox(width: 12),
              const Text('Delete'),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await AppBottomSheet.showConfirmation(
          context: context,
          title: 'Delete note?',
          message: 'This action cannot be undone.',
          confirmLabel: 'Delete',
          icon: Icons.delete_outline,
          isDestructive: true,
        ) ??
        false;
  }

  Future<String?> _showProjectPicker(
    BuildContext context,
    PortaThoughtyState state,
  ) async {
    final projects = state.projects;
    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 40,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.drive_file_move_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Move to project',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...projects.map(
                  (project) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(project.id),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  project.color.withValues(alpha: 0.2),
                              foregroundColor: project.color,
                              child: Icon(project.icon ?? Icons.folder),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                project.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Image.asset('assets/mascot.png', height: 80, fit: BoxFit.contain, gaplessPlayback: true),
          const SizedBox(height: 12),
          Text(
            'Your inbox is empty, but your brain is full of ideas!',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Capture a thought with voice, text, or photos and it will land here instantly.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
