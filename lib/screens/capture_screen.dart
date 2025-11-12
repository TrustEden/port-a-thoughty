import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/groq_file_processor.dart';
import '../services/ocr_service.dart';
import '../state/app_state.dart';
import '../widgets/app_header.dart';
import '../widgets/pressable_widget.dart';
import '../widgets/project_selector.dart';

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProjectSelector(),
          const SizedBox(height: 20),
          _SpeechCaptureCard(state: state),
          const SizedBox(height: 16),
          _QuickActionsRow(state: state),
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
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 20),
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
                      'Voice Capture',
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
            state.settings.pressAndHoldToRecord
                ? (isRecording
                    ? 'Listening... release to stop.'
                    : 'Let me write that down! Hold to record.')
                : (isRecording
                    ? 'Listening... tap the button to stop.'
                    : 'Let me write that down! Tap to record.'),
            style: GoogleFonts.comicNeue(
              textStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: state.settings.pressAndHoldToRecord
                ? _RecordingButton(
                    isRecording: isRecording,
                    onLongPressStart: (_) async {
                      if (!isRecording) {
                        HapticFeedback.heavyImpact();
                        await state.startRecording();
                      }
                    },
                    onLongPressEnd: (_) async {
                      if (isRecording) {
                        HapticFeedback.mediumImpact();
                        await state.stopRecording();
                      }
                    },
                  )
                : _RecordingButton(
                    isRecording: isRecording,
                    onPressed: () async {
                      if (isRecording) {
                        HapticFeedback.mediumImpact();
                        await state.stopRecording();
                      } else {
                        HapticFeedback.heavyImpact();
                        await state.startRecording();
                      }
                    },
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RecordingButton extends StatelessWidget {
  const _RecordingButton({
    required this.isRecording,
    this.onPressed,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  final bool isRecording;
  final VoidCallback? onPressed;
  final Function(LongPressStartDetails)? onLongPressStart;
  final Function(LongPressEndDetails)? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final ringColor = isRecording
        ? theme.colorScheme.error
        : theme.colorScheme.primary.withValues(alpha: 0.65);
    final innerColor = isRecording
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Semantics(
      label: isRecording ? 'Stop recording' : 'Start voice recording',
      hint: isRecording ? 'Tap to stop recording your thoughts' : 'Tap to record your thoughts with voice',
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        onLongPressStart: onLongPressStart,
        onLongPressEnd: onLongPressEnd,
        child: AnimatedContainer(
          duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
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
                blurRadius: isRecording ? 35 : 30,
                spreadRadius: isRecording ? 3 : 2,
              ),
            ],
          ),
          child: Center(
            child: AnimatedContainer(
              duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              height: isRecording ? 72 : 86,
              width: isRecording ? 72 : 86,
              child: AnimatedSwitcher(
                duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: isRecording
                    ? Image.asset(
                        key: const ValueKey('stop'),
                        'assets/stoprecording.png',
                        width: 136,
                        height: 136,
                        gaplessPlayback: true,
                      )
                    : Image.asset(
                        key: const ValueKey('mic'),
                        'assets/mic.png',
                        width: 136,
                        height: 136,
                        gaplessPlayback: true,
                      ),
              ),
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
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            imageAsset: 'assets/written.png',
            label: 'Text Note',
            onTap: () => _openTextNoteComposer(context),
            width: 31,
            height: 31,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            imageAsset: 'assets/camera.png',
            label: 'Take Photo',
            onTap: () => _showOcrMock(context),
            width: 36,
            height: 36,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            imageAsset: 'assets/upload.png',
            label: 'Upload Files',
            onTap: () => _showMultiImportMock(context),
            width: 36,
            height: 36,
          ),
        ),
      ],
    );
  }

  Future<void> _openTextNoteComposer(BuildContext context) async {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<String>(
      isScrollControlled: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                  Text('Quick text note', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 5,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText:
                          'Type anything. Markdown formatting is supported in the full build.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pop(controller.text.trim()),
                        child: const Text('Save to queue'),
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
    final picker = ImagePicker();

    // Pick image from camera
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (photo == null) return;
    if (!context.mounted) return;

    // Show confirmation preview with the captured image
    final result = await _showImagePreviewSheet(context, photo.path);

    if (result == null) {
      // User cancelled - delete the temp image
      try {
        await File(photo.path).delete();
      } catch (_) {}
      return;
    }

    if (!context.mounted) return;

    // Process OCR in background
    final ocrService = OcrService();
    String ocrText = '';

    try {
      final ocrResult = await ocrService.extractTextWithConfidence(photo.path);
      ocrText = ocrResult.text;
    } catch (e) {
      print('OCR failed: $e');
    } finally {
      ocrService.dispose();
    }

    if (!context.mounted) return;

    // Add note to queue with image path
    await state.addImageNote(
      ocrText: ocrText.isEmpty ? '' : ocrText,
      includeImage: result,
      imagePath: photo.path,
      label: 'Camera capture',
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result
              ? 'Image + OCR note added to queue.'
              : 'OCR text added to queue (image not included).',
        ),
      ),
    );
  }

  Future<bool?> _showImagePreviewSheet(
    BuildContext context,
    String imagePath,
  ) async {
    final theme = Theme.of(context);
    bool includeImage = true;

    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Photo captured',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Image preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: Image.file(
                        File(imagePath),
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  StatefulBuilder(
                    builder: (context, setModalState) {
                      return Row(
                        children: [
                          Checkbox(
                            value: includeImage,
                            onChanged: (value) {
                              setModalState(() {
                                includeImage = value ?? true;
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              'Include image in processed document',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
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
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(includeImage),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Submit'),
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
  }

  Future<void> _showMultiImportMock(BuildContext context) async {
    // Pick file using file_picker
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    if (!context.mounted) return;

    final file = result.files.first;
    final filePath = file.path;

    if (filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to access file')),
      );
      return;
    }

    final state = context.read<PortaThoughtyState>();

    // Check if file is an image
    final isImage = _isImageFile(filePath);

    if (isImage) {
      // Handle image upload with local OCR
      await _handleImageUpload(context, state, filePath, file.name);
    } else {
      // Handle non-image files with Groq
      await _handleNonImageUpload(context, state, filePath, file.name);
    }
  }

  bool _isImageFile(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic'].contains(extension);
  }

  Future<void> _handleImageUpload(
    BuildContext context,
    PortaThoughtyState state,
    String filePath,
    String fileName,
  ) async {
    // Show image preview sheet to ask if user wants to include image
    final includeImage = await _showImagePreviewSheet(context, filePath);

    if (includeImage == null) {
      // User cancelled
      return;
    }

    if (!context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Extracting text from image...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Process OCR locally with Google ML Kit
    final ocrService = OcrService();
    String ocrText = '';

    try {
      final ocrResult = await ocrService.extractTextWithConfidence(filePath);
      ocrText = ocrResult.text;
    } catch (e) {
      print('OCR failed: $e');
    } finally {
      ocrService.dispose();
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    // Add image note to queue
    await state.addImageNote(
      ocrText: ocrText.isEmpty ? '' : ocrText,
      includeImage: includeImage,
      imagePath: filePath,
      label: fileName,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          includeImage
              ? 'Image + OCR note added to queue.'
              : 'OCR text added to queue (image not included).',
        ),
      ),
    );
  }

  Future<void> _handleNonImageUpload(
    BuildContext context,
    PortaThoughtyState state,
    String filePath,
    String fileName,
  ) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing file with Groq AI...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Process file with Groq
    final processor = GroqFileProcessor(apiKey: state.settings.groqApiKey);
    String extractedContent = '';

    try {
      extractedContent = await processor.processFile(filePath);
    } catch (e) {
      extractedContent = 'Error processing file: $e';
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    // Add note to queue with extracted content
    await state.addTextNote(extractedContent);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File "$fileName" processed and added to queue.'),
      ),
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
    return Semantics(
      label: label,
      hint: 'Tap to $label',
      button: true,
      child: PressableWidget(
        onPressed: onTap,
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
              width: width > 44 ? width : 44,
              height: height > 44 ? height : 44,
              child: Center(
                child: Image.asset(
                  imageAsset,
                  width: width,
                  height: height,
                  gaplessPlayback: true,
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
    'Inbox',
    'Grocery List',
    'Dev Project',
    'Creative Writing',
    'General Todo',
  ];

  final Map<String, IconData> _typeIcons = {
    'Inbox': Icons.inbox_outlined,
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create new project', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),

          // Project Type Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: InputDecoration(
              labelText: 'Project Type',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                borderRadius: BorderRadius.circular(12),
              ),
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
                  borderRadius: BorderRadius.circular(12),
                ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isCreating || !_canCreate ? null : _createProject,
                child: _isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Project'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}