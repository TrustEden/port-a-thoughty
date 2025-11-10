import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../state/app_state.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_sheets.dart';
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
        RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.lightImpact();
            await state.refreshQueue();
          },
          child: CustomScrollView(
            slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Processing queue',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: notes.isNotEmpty && selectedCount < notes.length
                              ? () {
                                  HapticFeedback.lightImpact();
                                  state.selectAllNotes();
                                }
                              : null,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Select all'),
                        ),
                        if (selectedCount > 0)
                          TextButton(
                            onPressed: () => state.clearSelection(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('Clear selection'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            if (notes.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
                sliver: const SliverToBoxAdapter(
                  child: _EmptyQueuePlaceholder(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 160),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final note = notes[index];
                      return Dismissible(
                        key: Key('note_${note.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          HapticFeedback.mediumImpact();
                          return true;
                        },
                        onDismissed: (direction) {
                          _handleDelete(context, state, note);
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        child: _QueueNoteCard(
                          note: note,
                          selected: state.selectedNoteIds.contains(note.id),
                          onToggle: () {
                            HapticFeedback.lightImpact();
                            state.toggleNoteSelection(note.id);
                          },
                          onDelete: () => _handleDelete(context, state, note),
                          onNoteTap: () => _showNoteEditor(context, state, note),
                        ),
                      );
                    },
                    childCount: notes.length,
                  ),
                ),
              ),
          ],
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SafeArea(
                top: false,
                child: Semantics(
                  label: selectedCount == 0
                      ? 'Select notes to process'
                      : 'Process $selectedCount note${selectedCount == 1 ? '' : 's'} into a document',
                  hint: selectedCount == 0
                      ? 'Select at least one note first'
                      : 'Tap to compile selected notes into a markdown document',
                  button: true,
                  enabled: selectedCount > 0,
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
        ),
      ],
    );
  }

  Future<void> _handleDelete(
    BuildContext context,
    PortaThoughtyState state,
    Note note,
  ) async {
    HapticFeedback.mediumImpact();
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
            HapticFeedback.lightImpact();
            state.undoNoteDeletion();
          },
        ),
      ),
    );
  }

  Future<void> _beginProcessing(BuildContext context) async {
    HapticFeedback.mediumImpact();
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
      HapticFeedback.lightImpact();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Draft doc created. Undo available for 7 days.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              HapticFeedback.lightImpact();
              state.undoLastProcess();
            },
          ),
        ),
      );
    } else if (result.error != null && result.error!.isNotEmpty) {
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    } else {
      HapticFeedback.mediumImpact();
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

    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
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
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 32,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.auto_mode,
                          size: 28,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Process ${selectedNotes.length} note${selectedNotes.length == 1 ? '' : 's'}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Document title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Preview',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.3,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: selectedNotes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final note = selectedNotes[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _noteIcon(note.type),
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  note.preview,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Processing will call the configured model and save a Markdown summary while keeping the raw notes available for undo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(null),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(controller.text.trim()),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Process now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Delay disposal to ensure the bottom sheet animation is fully complete
    // Bottom sheet animations typically take 200-300ms, so we wait longer to be safe
    Future.delayed(const Duration(milliseconds: 500), () {
      controller.dispose();
    });
    return result;
  }

  Future<void> _showNoteEditor(
    BuildContext context,
    PortaThoughtyState state,
    Note note,
  ) async {
    final theme = Theme.of(context);
    final textController = TextEditingController(text: note.text);
    bool includeImage = note.includeImage;

    // Determine editor configuration based on note type
    final String title;
    final IconData icon;
    final Color accentColor;

    switch (note.type) {
      case NoteType.voice:
        title = 'Edit voice note';
        icon = Icons.mic;
        accentColor = theme.colorScheme.primary;
        break;
      case NoteType.text:
        title = 'Edit text note';
        icon = Icons.edit_note;
        accentColor = const Color(0xFFFB8C00);
        break;
      case NoteType.image:
        title = 'Edit image note';
        icon = Icons.image_outlined;
        accentColor = const Color(0xFF8E24AA);
        break;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 32,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                icon,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Low confidence warning for voice notes
                        if (note.type == NoteType.voice && note.flaggedLowConfidence)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: theme.colorScheme.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Low confidence transcription - please review carefully',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Image preview for image notes
                        if (note.type == NoteType.image && note.imagePath != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.3,
                              ),
                              child: Image.file(
                                File(note.imagePath!),
                                fit: BoxFit.contain,
                                width: double.infinity,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Include image checkbox
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setModalState(() {
                                includeImage = !includeImage;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: includeImage,
                                    onChanged: (value) {
                                      HapticFeedback.lightImpact();
                                      setModalState(() {
                                        includeImage = value ?? true;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Include image in processed document',
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Editable text
                        Text(
                          note.type == NoteType.image
                              ? 'OCR Text'
                              : note.type == NoteType.voice
                                  ? 'Transcription'
                                  : 'Note Text',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: textController,
                          maxLines: note.type == NoteType.image ? 8 : 12,
                          autofocus: note.type == NoteType.text,
                          decoration: InputDecoration(
                            hintText: note.type == NoteType.image
                                ? 'Edit the extracted text...'
                                : note.type == NoteType.voice
                                    ? 'Edit the transcription...'
                                    : 'Edit your note...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),

                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).pop(false);
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: BorderSide(
                                    color: theme.colorScheme.outline
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
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.of(context).pop(true);
                                },
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Save changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
          },
        );
      },
    );

    // Save changes if user confirmed
    if (result == true && context.mounted) {
      final updatedNote = note.copyWith(
        text: textController.text,
        includeImage: note.type == NoteType.image ? includeImage : note.includeImage,
      );
      await state.updateNote(updatedNote);

      // Show feedback about image inclusion change (for image notes only)
      if (note.type == NoteType.image &&
          note.includeImage != includeImage &&
          context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        if (!includeImage) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Image will not be included in document'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final revertedNote = updatedNote.copyWith(includeImage: true);
                  state.updateNote(revertedNote);
                },
              ),
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Image will be included in document'),
            ),
          );
        }
      } else if (context.mounted) {
        // Show generic save confirmation for text/voice notes
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note updated'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    // Delay disposal to ensure the bottom sheet animation is fully complete
    // Bottom sheet animations typically take 200-300ms, so we wait longer to be safe
    Future.delayed(const Duration(milliseconds: 500), () {
      textController.dispose();
    });
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
    this.onNoteTap,
  });

  final Note note;
  final bool selected;
  final VoidCallback onToggle;
  final Future<void> Function()? onDelete;
  final VoidCallback? onNoteTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentForType(note.type, theme);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
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
        onTap: () {
          // If we have a note tap handler, show the editor
          // Otherwise toggle selection
          if (onNoteTap != null) {
            HapticFeedback.mediumImpact();
            onNoteTap!();
          } else {
            onToggle();
          }
        },
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
                      gaplessPlayback: true,
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
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),  // Clamp to valid range for elasticOut curve
              child: child,
            ),
          );
        },
        child: Column(
          children: [
            Image.asset('assets/bulb icon.png', height: 72, fit: BoxFit.contain, gaplessPlayback: true),
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