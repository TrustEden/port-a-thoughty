import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_sheets.dart';
import '../widgets/project_selector.dart';
import '../widgets/recent_note_list.dart';

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PortaThoughtyState>();
    final pendingMessage = state.consumeRecordingMessage();
    final pendingError = state.lastRecordingError;

    if (pendingMessage != null || pendingError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        if (pendingError != null) {
          messenger.showSnackBar(SnackBar(content: Text(pendingError)));
          state.clearRecordingError();
        } else if (pendingMessage != null) {
          messenger.showSnackBar(SnackBar(content: Text(pendingMessage)));
        }
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHeader(),
          const SizedBox(height: 18),
          const ProjectSelector(),
          const SizedBox(height: 20),
          _SpeechCaptureCard(state: state),
          const SizedBox(height: 16),
          _QuickActionsRow(state: state),
          const SizedBox(height: 28),
          _SectionTitle(
            title: 'Recent captures',
            subtitle:
                'Fresh notes drop in here. Process them later from the Queue tab.',
          ),
          const SizedBox(height: 12),
          RecentNoteList(notes: state.queue.take(5).toList()),
        ],
      ),
    );
  }
}

class _SpeechCaptureCard extends StatelessWidget {
  const _SpeechCaptureCard({required this.state});

  final PortaThoughtyState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecording = state.isRecording;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.92),
            Colors.white.withValues(alpha: 0.74),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A014F8E),
            blurRadius: 34,
            offset: Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Voice capture',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Chip(
                      avatar: const Icon(Icons.mic, size: 16),
                      label: const Text('Native - private'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isRecording
                ? 'Listening... tap the button to stop.'
                : 'Let me write that down! Tap to record.',
            style: GoogleFonts.comicNeue(
              textStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: _RecordingButton(
              isRecording: isRecording,
              onPressed: () async {
                if (isRecording) {
                  await state.stopRecording();
                }
                else {
                  await state.startRecording();
                }
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _RecordingButton extends StatelessWidget {
  const _RecordingButton({required this.isRecording, required this.onPressed});

  final bool isRecording;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ringColor = isRecording
        ? theme.colorScheme.error
        : theme.colorScheme.primary.withValues(alpha: 0.65);
    final innerColor = isRecording
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        height: 140,
        width: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              ringColor.withValues(alpha: 0.1),
              ringColor.withValues(alpha: 0.25),
              ringColor,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: ringColor.withValues(alpha: 0.35),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: isRecording ? 72 : 86,
            width: isRecording ? 72 : 86,
            child: isRecording
                ? Image.asset(
                    'assets/stoprecording.png',
                    width: 34,
                    height: 34,
                  )
                : Image.asset(
                    'assets/mic.png',
                    width: 34,
                    height: 34,
                  ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.state});

  final PortaThoughtyState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                imageAsset: 'assets/written.png',
                label: 'Add text note',
                onTap: () => _openTextNoteComposer(context),
                width: 31,
                height: 31,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                imageAsset: 'assets/camera.png',
                label: 'Take photo',
                onTap: () => _showOcrMock(context),
                width: 36,
                height: 36,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                imageAsset: 'assets/upload.png',
                label: 'Upload files',
                onTap: () => _showMultiImportMock(context),
                width: 36,
                height: 36,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                imageAsset: 'assets/newproject.png',
                label: 'New project',
                onTap: () => _openProjectCreation(context),
                width: 36,
                height: 36,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openProjectCreation(BuildContext context) async {
    await AppBottomSheet.showCustom<void>(
      context: context,
      child: const ProjectCreationSheet(),
    );
  }

  Future<void> _openTextNoteComposer(BuildContext context) async {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    final result = await AppBottomSheet.showCustom<String>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick text note',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            maxLines: 5,
            autofocus: true,
            decoration: InputDecoration(
              hintText:
                  'Type anything. Markdown formatting is supported in the full build.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: AppBottomSheet.outlinedButtonStyle(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(controller.text.trim()),
                  style: AppBottomSheet.filledButtonStyle(context),
                  child: const Text('Save to queue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    if (result != null && result.isNotEmpty) {
      await state.addTextNote(result);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text note captured to your queue.')),
      );
    }
  }

  Future<void> _showOcrMock(BuildContext context) async {
    final theme = Theme.of(context);
    bool includeImage = true;
    final result = await AppBottomSheet.showCustom<bool>(
      context: context,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mock OCR preview',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: const Text(
                  '"Sketch prototype for widgets. Add undo banner after processing. Consider haptic feedback variants."',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: includeImage,
                    onChanged: (value) {
                      setModalState(() {
                        includeImage = value ?? true;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Include image in doc',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: AppBottomSheet.outlinedButtonStyle(context),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(includeImage),
                      style: AppBottomSheet.filledButtonStyle(context),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (!context.mounted) return;

    if (result != null) {
      await state.addImageNote(
        ocrText:
            '"Sketch prototype for widgets. Add undo banner after processing. Consider haptic feedback variants."',
        includeImage: result,
        label: 'Mock photo',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? 'Image + OCR note added to queue.'
                : 'OCR text added without the image.',
          ),
        ),
      );
    }
  }

  Future<void> _showMultiImportMock(BuildContext context) async {
    final theme = Theme.of(context);
    await AppBottomSheet.showCustom<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bulk import (mock)',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'In production you would step through each photo, tweak OCR, and choose whether to keep the image.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: AppBottomSheet.filledButtonStyle(context),
              child: const Text('Simulate import'),
            ),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    await state.addImageNote(
      ocrText:
          'OCR: "Big screen wireframe: capture buttons at bottom, docs tab with recent summaries."',
      includeImage: false,
      label: 'Gallery import',
    );
    await state.addTextNote(
      'Batch import placeholder: prompt for include image when OCR confidence is <70%.',
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mock gallery import added two notes.')),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.imageAsset,
    required this.label,
    required this.onTap,
    this.width = 24,
    this.height = 24,
  });

  final String imageAsset;
  final String label;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14014F8E),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Image.asset(
                  imageAsset,
                  width: width,
                  height: height,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class ProjectCreationSheet extends StatefulWidget {
  const ProjectCreationSheet({super.key});

  @override
  State<ProjectCreationSheet> createState() => _ProjectCreationSheetState();
}

class _ProjectCreationSheetState extends State<ProjectCreationSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedType;
  bool _isCreating = false;

  final List<String> _projectTypes = [
    'Grocery List',
    'Dev Project',
    'Creative Writing',
    'General Todo',
  ];

  final Map<String, IconData> _typeIcons = {
    'Grocery List': Icons.shopping_cart,
    'Dev Project': Icons.code,
    'Creative Writing': Icons.edit,
    'General Todo': Icons.checklist,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _needsDescription {
    return _selectedType == 'Dev Project' || _selectedType == 'Creative Writing';
  }

  bool get _canCreate {
    if (_selectedType == null) return false;
    final name = _nameController.text.trim();
    if (name.length < 4 || name.length > 20) return false;
    if (_needsDescription && _descriptionController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _createProject() async {
    if (!_canCreate) return;

    setState(() => _isCreating = true);

    final state = context.read<PortaThoughtyState>();
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final icon = _typeIcons[_selectedType]!;

    try {
      final projectId = await state.createProject(
        name: name,
        type: _selectedType!,
        description: _needsDescription ? description : null,
        icon: icon,
      );

      if (!mounted) return;

      if (projectId != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Project "$name" created!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create project')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create new project',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // Project Type Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: InputDecoration(
              labelText: 'Project Type',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              prefixIcon: const Icon(Icons.category),
            ),
            items: _projectTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Icon(
                      _typeIcons[type],
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(type),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedType = value;
                if (!_needsDescription) {
                  _descriptionController.clear();
                }
              });
            },
          ),
          const SizedBox(height: 12),

          // Project Name Field
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Project Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              prefixIcon: const Icon(Icons.label),
              hintText: 'Enter project name',
              counterText: '${_nameController.text.length}/20',
            ),
            maxLength: 20,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Description Field (conditional)
          if (_needsDescription) ...[
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                prefixIcon: const Icon(Icons.description),
                hintText: _selectedType == 'Dev Project'
                    ? 'Describe your project context'
                    : 'Describe your creative project',
                helperText: 'Helps AI understand your project',
              ),
              maxLength: 400,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
          ],

          // Action Buttons
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: AppBottomSheet.outlinedButtonStyle(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isCreating || !_canCreate ? null : _createProject,
                  style: AppBottomSheet.filledButtonStyle(context),
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Project'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}