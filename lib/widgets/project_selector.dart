import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../state/app_state.dart';
import 'bottom_sheets.dart';

class ProjectSelector extends StatelessWidget {
  const ProjectSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<PortaThoughtyState>(
      builder: (context, state, _) {
        final projects = state.projects;
        if (projects.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x15014F8E),
                  blurRadius: 26,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Active project',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.settings,
                        size: 22,
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Image.asset(
                      'assets/projectsicon.png',
                      width: 52,
                      height: 52,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Loading...',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final active = state.activeProject;
        final activeId = projects.any((p) => p.id == active.id)
            ? active.id
            : projects.first.id;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x15014F8E),
                blurRadius: 26,
                offset: Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Active project',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      AppBottomSheet.showCustom<void>(
                        context: context,
                        child: _ProjectManagementSheet(
                          projects: projects,
                          activeProject: active,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.settings,
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Hero(
                    tag: 'project-icon',
                    child: Image.asset(
                      'assets/projectsicon.png',
                      width: 52,
                      height: 52,
                      cacheWidth: (52 * MediaQuery.of(context).devicePixelRatio).round(),
                      cacheHeight: (52 * MediaQuery.of(context).devicePixelRatio).round(),
                      gaplessPlayback: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(activeId),
                      initialValue: activeId,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.expand_more),
                      items: projects
                          .map(
                            (project) => DropdownMenuItem(
                              value: project.id,
                              child: Text(project.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          state.switchProject(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectManagementSheet extends StatefulWidget {
  const _ProjectManagementSheet({
    required this.projects,
    required this.activeProject,
  });

  final List<Project> projects;
  final Project activeProject;

  @override
  State<_ProjectManagementSheet> createState() =>
      _ProjectManagementSheetState();
}

class _ProjectManagementSheetState extends State<_ProjectManagementSheet> {
  late String _selectedProjectId;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  String? _selectedType;

  final List<String> _projectTypes = [
    'Grocery List',
    'Dev Project',
    'Creative Writing',
    'General Todo',
  ];

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.activeProject.id;
    _nameController = TextEditingController(text: widget.activeProject.name);
    _descriptionController = TextEditingController(
      text: widget.activeProject.prompt ?? '',
    );
    // Try to infer project type from the prompt or default to first type
    _selectedType = _inferProjectType(widget.activeProject);
  }

  String _inferProjectType(Project project) {
    final prompt = project.prompt?.toLowerCase() ?? '';
    if (prompt.contains('grocery')) return 'Grocery List';
    if (prompt.contains('dev project') || prompt.contains('development')) {
      return 'Dev Project';
    }
    if (prompt.contains('creative writing')) return 'Creative Writing';
    if (prompt.contains('todo')) return 'General Todo';
    return _projectTypes.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Project get _currentProject {
    return widget.projects.firstWhere((p) => p.id == _selectedProjectId);
  }

  void _onProjectChanged(String? projectId) {
    if (projectId == null || projectId == _selectedProjectId) return;
    setState(() {
      _selectedProjectId = projectId;
      final project = _currentProject;
      _nameController.text = project.name;
      _descriptionController.text = project.prompt ?? '';
      _selectedType = _inferProjectType(project);
    });
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
            'Manage Projects',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // Project Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedProjectId,
            decoration: InputDecoration(
              labelText: 'Select Project',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              prefixIcon: const Icon(Icons.folder),
            ),
            items: widget.projects
                .map(
                  (project) => DropdownMenuItem(
                    value: project.id,
                    child: Text(project.name),
                  ),
                )
                .toList(),
            onChanged: _onProjectChanged,
          ),
          const SizedBox(height: 16),

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
            ),
            maxLength: 20,
          ),
          const SizedBox(height: 12),

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
            items: _projectTypes
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedType = value;
              });
            },
          ),
          const SizedBox(height: 12),

          // Description Field
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
              hintText: 'Project context and details',
              helperText: 'Helps you and AI understand this project',
            ),
            maxLines: 3,
            maxLength: 400,
          ),
          const SizedBox(height: 16),

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
                  onPressed: () {
                    // TODO: Implement save functionality
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Project updates coming soon!'),
                      ),
                    );
                  },
                  style: AppBottomSheet.filledButtonStyle(context),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
