import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class ProjectCreationScreen extends StatefulWidget {
  const ProjectCreationScreen({super.key});

  @override
  State<ProjectCreationScreen> createState() => _ProjectCreationScreenState();
}

class _ProjectCreationScreenState extends State<ProjectCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedType;
  bool _isCreating = false;

  final List<String> _projectTypes = [
    'Grocery List',
    'Dev Project',
    'Creative Writing',
    'General Todo',
    'Custom (Coming soon)',
  ];

  final Map<String, IconData> _typeIcons = {
    'Grocery List': Icons.shopping_cart,
    'Dev Project': Icons.code,
    'Creative Writing': Icons.edit,
    'General Todo': Icons.checklist,
    'Custom (Coming soon)': Icons.settings,
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
    if (_selectedType == null || _selectedType == 'Custom (Coming soon)') {
      return false;
    }
    final name = _nameController.text.trim();
    if (name.length < 4 || name.length > 20) {
      return false;
    }
    if (_needsDescription && _descriptionController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate()) return;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Project'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              const Color(0xFFE3F2FD),
              theme.colorScheme.primary.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                // Project Type Dropdown
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14014F8E),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Project Type',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: _projectTypes.map((type) {
                      final isDisabled = type == 'Custom (Coming soon)';
                      return DropdownMenuItem(
                        value: type,
                        enabled: !isDisabled,
                        child: Row(
                          children: [
                            Icon(
                              _typeIcons[type],
                              size: 20,
                              color: isDisabled
                                  ? theme.disabledColor
                                  : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              type,
                              style: isDisabled
                                  ? TextStyle(color: theme.disabledColor)
                                  : null,
                            ),
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
                    validator: (value) {
                      if (value == null || value == 'Custom (Coming soon)') {
                        return 'Please select a project type';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Project Name Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14014F8E),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Project Name',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.label),
                      hintText: 'Enter project name',
                    ),
                    maxLength: 20,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.length < 4) {
                        return 'Name must be at least 4 characters';
                      }
                      if (trimmed.length > 20) {
                        return 'Name must be 20 characters or less';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Description Field (conditional)
                if (_needsDescription) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14014F8E),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.description),
                        hintText: _selectedType == 'Dev Project'
                            ? 'Describe your project context'
                            : 'Describe your creative project',
                        helperText: 'Helps AI understand your project context',
                      ),
                      maxLength: 400,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (_needsDescription && (value?.trim().isEmpty ?? true)) {
                          return 'Description is required for this project type';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Info Card
                if (_selectedType != null && _selectedType != 'Custom (Coming soon)') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getInfoText(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Create Button
                FilledButton(
                  onPressed: _isCreating || !_canCreate ? null : _createProject,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Create Project',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInfoText() {
    switch (_selectedType) {
      case 'Grocery List':
        return 'Perfect for shopping lists with smart item organization and suggestions';
      case 'Dev Project':
        return 'Organize development notes with technical clarity and categorization';
      case 'Creative Writing':
        return 'Enhance creative ideas with structure and narrative flow';
      case 'General Todo':
        return 'Transform notes into clear, actionable todo lists';
      default:
        return '';
    }
  }
}
