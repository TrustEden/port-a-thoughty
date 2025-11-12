import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  String? _selectedType;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
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

  final Map<String, String> _typeDescriptions = {
    'Inbox': 'A general-purpose project for all your thoughts and ideas',
    'Grocery List': 'Track shopping items and meal planning',
    'Dev Project': 'Capture code ideas, bugs, and development notes',
    'Creative Writing': 'Story ideas, character notes, and writing inspiration',
    'General Todo': 'Tasks, reminders, and daily planning',
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

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _selectedType != null;
      case 1:
        final name = _nameController.text.trim();
        if (name.length < 4 || name.length > 20) return false;
        if (_needsDescription && _descriptionController.text.trim().isEmpty) {
          return false;
        }
        return true;
      default:
        return false;
    }
  }

  Future<void> _createProject() async {
    if (!_canProceed) return;

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
        // Navigate back to main screen
        // createProject already handles switching to the new project
        if (!mounted) return;
        Navigator.of(context).pop();
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

  void _nextStep() {
    if (!_canProceed) return;

    if (_currentStep == 0) {
      // Moving from step 0 to step 1
      setState(() {
        _currentStep = 1;
        // Pre-fill name with project type if empty
        if (_nameController.text.isEmpty) {
          _nameController.text = _selectedType!;
        }
      });
    } else if (_currentStep == 1) {
      // Final step - create project
      _createProject();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Header
                Text(
                  'Welcome to Porta-Thoughty',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Let\'s set up your first project',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Progress indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildProgressDot(0),
                    const SizedBox(width: 8),
                    _buildProgressDot(1),
                  ],
                ),
                const SizedBox(height: 32),
                // Content
                Expanded(
                  child: _currentStep == 0
                      ? _buildTypeSelectionStep()
                      : _buildDetailsStep(),
                ),
                // Navigation buttons
                Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _canProceed ? _nextStep : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isCreating
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_currentStep == 0 ? 'Next' : 'Create Project'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDot(int step) {
    final theme = Theme.of(context);
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 32 : 12,
      height: 12,
      decoration: BoxDecoration(
        color: isActive || isCompleted
            ? theme.colorScheme.primary
            : theme.colorScheme.primary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _buildTypeSelectionStep() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What kind of notes will you capture?',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the type that best matches your use case',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ..._projectTypes.map((type) {
            final isSelected = _selectedType == type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => setState(() => _selectedType = type),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _typeIcons[type],
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _typeDescriptions[type] ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Name your project',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Give it a meaningful name to help organize your thoughts',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          // Selected type display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _typeIcons[_selectedType],
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedType ?? '',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Project Name Field
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Project Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              prefixIcon: const Icon(Icons.label),
              hintText: 'e.g., My First Project',
              counterText: '${_nameController.text.length}/20',
            ),
            maxLength: 20,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
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
                fillColor: theme.colorScheme.surface,
                prefixIcon: const Icon(Icons.description),
                hintText: _selectedType == 'Dev Project'
                    ? 'What are you building or working on?'
                    : 'What will you write about?',
                helperText: 'This helps AI understand your project context',
              ),
              maxLength: 400,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
          ] else ...[
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                prefixIcon: const Icon(Icons.description),
                hintText: 'Add more context about this project',
              ),
              maxLength: 400,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }
}
