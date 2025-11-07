import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../state/app_state.dart';
import '../widgets/app_header.dart';
import '../widgets/project_selector.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PortaThoughtyState>();
    final notes = state.queue;
    final selectedCount = state.selectedNoteIds.length;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 160),
          children: [
            const AppHeader(),
            const SizedBox(height: 18),
            const ProjectSelector(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Processing queue',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextButton(
                  onPressed: selectedCount > 0
                      ? () => state.clearSelection()
                      : null,
                  child: const Text('Clear selection'),
                ),
              ],
            ),
            if (selectedCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text('$selectedCount selected'),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (notes.isEmpty)
              const _EmptyQueuePlaceholder()
            else
              ...notes.map(
                (note) => _QueueNoteCard(
                  note: note,
                  selected: state.selectedNoteIds.contains(note.id),
                  onToggle: () => state.toggleNoteSelection(note.id),
                  onDelete: () => _handleDelete(context, state, note),
                ),
              ),
            const SizedBox(height: 120),
          ],
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SafeArea(
                top: false,
                child: FilledButton.icon(
                  icon: const Icon(Icons.auto_mode),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: selectedCount == 0
                      ? null
                      : () => _beginProcessing(context),
                  label: Text(
                    selectedCount == 0
                        ? 'Select notes to process'
                        : 'Process ${selectedCount == 1 ? 'selected note' : '$selectedCount notes'}',
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleDelete(
    BuildContext context,
    PortaThoughtyState state,
    Note note,
  ) async {
    final success = await state.deleteNote(note);
    if (!success) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Note removed from queue.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            state.undoNoteDeletion();
          },
        ),
      ),
    );
  }

  Future<void> _beginProcessing(BuildContext context) async {
    final state = context.read<PortaThoughtyState>();
    final customTitle = await _showProcessSheet(context, state);
    if (customTitle == null) return;

    final result = await state.processSelectedNotes(
      customTitle: customTitle.trim(),
    );
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (result.success) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Draft doc created. Undo available for 7 days.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              state.undoLastProcess();
            },
          ),
        ),
      );
    } else if (result.error != null && result.error!.isNotEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Processing failed. Try again in a moment.'),
        ),
      );
    }
  }

  Future<String?> _showProcessSheet(
    BuildContext context,
    PortaThoughtyState state,
  ) async {
    final selectedNotes = state.queue
        .where((note) => state.selectedNoteIds.contains(note.id))
        .toList(growable: false);
    if (selectedNotes.isEmpty) return null;

    final project = state.activeProject;
    final suggestedTitle =
        '${project.name} Notes - ${_formatDate(DateTime.now())}';
    final controller = TextEditingController(text: suggestedTitle);

    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.auto_mode),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Process ${selectedNotes.length} note${selectedNotes.length == 1 ? '' : 's'}',
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Document title',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Preview',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: ((selectedNotes.length * 76).clamp(160, 320)).toDouble(),
                    child: ListView.separated(
                      itemCount: selectedNotes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final note = selectedNotes[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _noteIcon(note.type),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      note.preview,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Processing will call the configured model and save a Markdown summary while keeping the raw notes available for undo.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Process now'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  String _formatDate(DateTime now) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${monthNames[now.month - 1]} ${now.day.toString().padLeft(2, '0')}';
  }
}

class _QueueNoteCard extends StatelessWidget {
  const _QueueNoteCard({
    required this.note,
    required this.selected,
    required this.onToggle,
    this.onDelete,
  });

  final Note note;
  final bool selected;
  final VoidCallback onToggle;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentForType(note.type, theme);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          width: 1.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12014F8E),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(value: selected, onChanged: (_) => onToggle()),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_noteIcon(note.type), color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      note.preview,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove from queue',
                    onPressed: onDelete == null ? null : () => onDelete?.call(),
                    icon: Image.asset(
                      'assets/trashicon.png',
                      height: 20,
                      width: 20,
                      fit: BoxFit.contain,
                      color: theme.colorScheme.onSurfaceVariant,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: _metaChips(note, theme, accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentForType(NoteType type, ThemeData theme) {
    switch (type) {
      case NoteType.voice:
        return theme.colorScheme.primary;
      case NoteType.text:
        return const Color(0xFFFB8C00);
      case NoteType.image:
        return const Color(0xFF8E24AA);
    }
  }

  List<Widget> _metaChips(Note note, ThemeData theme, Color accent) {
    final chips = <Widget>[
      _MetaChip(
        icon: Icons.schedule_outlined,
        label: _timestampLabel(note.createdAt),
      ),
    ];

    switch (note.type) {
      case NoteType.voice:
        if (note.flaggedLowConfidence) {
          chips.add(
            _MetaChip(
              icon: Icons.warning_amber_rounded,
              label: 'Low confidence',
              color: theme.colorScheme.error,
            ),
          );
        }
        break;
      case NoteType.text:
        final wordCount = note.text
            .trim()
            .split(RegExp(r'\s+'))
            .where((segment) => segment.isNotEmpty)
            .length;
        chips.add(
          _MetaChip(icon: Icons.short_text_rounded, label: '$wordCount words'),
        );
        break;
      case NoteType.image:
        chips.add(
          _MetaChip(icon: Icons.image_outlined, label: _imageSummary(note)),
        );
        break;
    }

    chips.add(
      _MetaChip(
        icon: Icons.auto_awesome,
        label: 'Ready for AI processing',
        color: accent,
      ),
    );
    return chips;
  }

  String _timestampLabel(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
  }

  String _imageSummary(Note note) {
    if (!note.includeImage) return 'Text-only OCR';
    final label = note.imageLabel;
    return label == null ? 'Image kept' : 'Image kept - $label';
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
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyQueuePlaceholder extends StatelessWidget {
  const _EmptyQueuePlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 46),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Image.asset('assets/bulb icon.png', height: 72, fit: BoxFit.contain),
          const SizedBox(height: 16),
          Text(
            'Queue is clear',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Capture new thoughts from the mic tab and they will queue up here ready for AI cleanup.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _noteIcon(NoteType type) {
  switch (type) {
    case NoteType.voice:
      return Icons.mic_none_outlined;
    case NoteType.text:
      return Icons.notes_outlined;
    case NoteType.image:
      return Icons.image_outlined;
  }
}